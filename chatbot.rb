SCRIPT_NAME="chatbot"
SCRIPT_AUTHOR="fffxc2"
SCRIPT_VERSION="0.0.2"
SCRIPT_DESCRIPTION="Sets up a response to ! based commands. Primarily for use with live configured twitch channels to return a multitwitch link"

require 'rubygems'
require 'twitch-api'

def weechat_init
  Weechat.register(SCRIPT_NAME,SCRIPT_AUTHOR,SCRIPT_VERSION,"",SCRIPT_DESCRIPTION,"","")
  
  Weechat.print("", "Registering channel hooks")
  channels_to_watch.each do |c|
    Weechat.print("", "Trying to hook channel #{c}") 
    buffer = Weechat.buffer_search("==",c)

    unless buffer.empty?
      Weechat.hook_print(buffer,"","",1,"check_for_command","")
      Weechat.print("", "Successfully hooked channel #{c}")
    else
      Weechat.print("", "Unable to find channel #{c} -- Are you connected?")
    end
  end

  Weechat::WEECHAT_RC_OK
end

def commands
  self.methods(false).select { |m| m =~ /^_/ }
end

def check_for_command(_, buffer, _, _, _, _, _, message)
  commands.each do |command|
    Weechat.print("", " -- Checking for !#{command} -- #{message}")
    if message =~ /^\!#{command[1..-1]}$/ #Command methods start with _, so skip that char and take the rest of the name
      unless rate_limiting?("@buffer_rate_limit", buffer, 5) # Currently max of 1 command per 5 sec
	Weechat.command(buffer,"/say #{send(command)}") # This expects the method named as the command to return a string
      end
    end
  end  

  Weechat::WEECHAT_RC_OK
end

def _multi
  live_channels = twitch_channels.select { |c| is_channel_live?(c) }
  if live_channels.empty?
    "No streams are currently live"
  else
    #"/say Tune in at http://multitwitch.tv/#{live_channels.join('/')}"
    #"/say Tune in at https://multistre.am/#{live_channels.join('/')}/layout7" 
    "Under development, check back later"
  end
end

def giveaway
  "Testing other commands!"
end

def is_channel_live?(channel)
  @channel_live_status ||= {}

  if rate_limiting?("@channel_rate_limit", channel)
    live_state = @channel_live_status[channel]
    Weechat.print("","Rate limited for channel: #{channel}")
  else
    live_state = !twitch_client.get_streams({user_login: channel, first: 1}).data.empty?
    Weechat.print("","Live state for channel #{channel} -- #{live_state}")
    @channel_live_status[channel] = live_state
  end

  return live_state
end

def twitch_channels
  Weechat.config_get_plugin('twitch_channels').split(',')
end

def channels_to_watch
  Weechat.config_get_plugin('listening_channels').split(',')	
end

def oauth_token
  Weechat.config_get_plugin('oauth_token')
end

def client_id
  Weechat.config_get_plugin('client_id')
end

def twitch_client
  @client ||= Twitch::Client.new client_id: client_id
end

# Default to a rate limit of 90 seconds
def rate_limiting?(timing_hash_name,key,rate_limit = 90)
  timing_hash = instance_variable_get(timing_hash_name)	
  timing_hash ||= {}

  prior_time = timing_hash[key]
  current_time = Time.now.to_i

  if prior_time.nil? || (current_time - prior_time) > rate_limit
    timing_hash[key]=current_time
    instance_variable_set(timing_hash_name,timing_hash)
    false
  else
    true
  end
end



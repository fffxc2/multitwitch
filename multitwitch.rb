SCRIPT_NAME="multitwitch"
SCRIPT_AUTHOR="fffxc2"
SCRIPT_VERSION="0.0.1"
SCRIPT_DESCRIPTION="Sets up a response to !multi based on live configured twitch channels to return a multitwitch link"

require 'rubygems'
require 'twitch-api'

def multitwitch_response(data, buffer, date, tags, displayed, highlight, prefix, message)
  return Weechat::WEECHAT_RC_OK unless message =~ /^\!multi/ 

  unless rate_limiting?("@buffer_rate_limit", buffer, 15)
    Weechat.command(buffer,response_message)
  end
 
  Weechat::WEECHAT_RC_OK
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

def twitch_client
  @client ||= Twitch::Client.new access_token: oauth_token
end

def response_message
  live_channels = twitch_channels.select { |c| is_channel_live?(c) }
  if live_channels.empty?
    "/say No streams are currently live"
  else
    "/say Tune in at http://multitwitch.tv/#{live_channels.join('/')}"
  end
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

def weechat_init
  Weechat.register(SCRIPT_NAME,SCRIPT_AUTHOR,SCRIPT_VERSION,"",SCRIPT_DESCRIPTION,"","")
  
  Weechat.print("", "Registering channel hooks")
  channels_to_watch.each do |c|
    Weechat.print("", "Trying to hook channel #{c}") 
    buffer = Weechat.buffer_search("==",c)

    unless buffer.empty?
      Weechat.hook_print(buffer,"","",1,"multitwitch_response","")
    else
      Weechat.print("", "Unable to find channel #{c} -- Are you connected?")
    end
  end
  
  Weechat::WEECHAT_RC_OK
end

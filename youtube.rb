require 'net/http'
require 'uri'
require 'json'

require_relative 'extractors'
require_relative 'health'

# Optional command: without its config file the bot runs without it
if(File.exist?('./conf/youtube.conf'))
  load './conf/youtube.conf' # $YOUTUBECONF const
end

def isYoutubeEnabled
  !$YOUTUBECONF.nil?
end

def youtubeSearch(message)
  runSearch(message) do
    sendYoutubeRequest(createYoutubeUri(message))
  end
  showStatus(message.bot) # the daily count is shared with !google, the red status stays Tavily's
end

def createYoutubeUri(message)
  params = {
    'key' => $YOUTUBECONF['APIKey'],
    'part' => 'snippet',
    'type' => 'video',
    'maxResults' => 1,
    'q' => extractQuery(message),
    'safeSearch' => isSafeSearch(message) ? 'strict' : 'none'
  }

  if($YOUTUBECONF['embeddableOnly'])
    params['videoEmbeddable'] = 'true' # only videos Discord can play in the channel
  end
  if(!$YOUTUBECONF['regionCode'].to_s.empty?)
    params['regionCode'] = $YOUTUBECONF['regionCode']
  end
  if(!$YOUTUBECONF['relevanceLanguage'].to_s.empty?)
    params['relevanceLanguage'] = $YOUTUBECONF['relevanceLanguage']
  end

  URI($YOUTUBECONF['url'] + '?' + URI.encode_www_form(params))
end

# A bot's embed can't hold a video player: the answer is the plain link, Discord turns it into a player itself
def sendYoutubeRequest(uri)
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'

  respJSON = requestJSON(uri, request)
  if(respJSON["code"] == "200")
    if(respJSON['items'].to_a.empty?)
      respJSON["code"] = "0"
    else
      respJSON['videoUrl'] = $YOUTUBECONF['urlVideo'] + respJSON['items'][0]['id']['videoId']
    end
  end
  respJSON
end

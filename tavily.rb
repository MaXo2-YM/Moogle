require 'net/http'
require 'uri'
require 'json'

require_relative 'extractors'
require_relative 'health'

load './conf/tavily.conf' # $TAVILYCONF const

def tavilySearch(message)
  response = runSearch(message) do
    tavilyResponse = sendRequestToJSON(URI($TAVILYCONF['url']), createAPIBody(message))
    if(tavilyResponse['code'] == "200" && isImageSearch(message) && tavilyResponse['images'].to_a.empty?)
      tavilyResponse['code'] = "0"
    end
    tavilyResponse
  end
  updateSearchHealth(message.bot, response)
end

# Adult results only where Discord allows them: channels marked NSFW and their threads. Everywhere else, direct messages included, Tavily filters them out.
def isSafeSearch(message)
  if($TAVILYCONF['safeSearch'] == 'always')
    return true
  end

  channel = message.channel
  if(channel.thread?) # threads follow their parent channel's setting
    channel = channel.parent
  end
  !(channel && channel.nsfw?)
end

def createAPIBody(message)
  body = {
    'query' => extractQuery(message),
    'max_results' => $TAVILYCONF['numberOfResults'],
    'exclude_domains' => $TAVILYCONF['excludeDomains'],
    'safe_search' => isSafeSearch(message)
  }

  if(!$TAVILYCONF['country'].to_s.empty?)
    body['country'] = $TAVILYCONF['country']
  end

  if(isImageSearch(message))
    body['include_images'] = true
  end

  body
end

def sendRequestToJSON(uri, body)
  request = Net::HTTP::Post.new(uri)
  request['Accept'] = 'application/json'
  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{$TAVILYCONF['APIKey']}"
  request.body = body.to_json

  respJSON = requestJSON(uri, request)
  if(respJSON["code"] == "200" && respJSON['results'].to_a.empty?)
    respJSON["code"] = "0"
  end
  respJSON

end

# Tavily returns page extracts in raw markdown, this makes them fit an embed description
def cleanSnippet(content)
  snippet = content.to_s
    .gsub(/!?\[([^\]]*)\]\([^)]*\)/, '\1') # links and images: keep the text only
    .gsub(/[#*_`|>]+/, ' ')
    .gsub(/\s+/, ' ')
    .strip

  snippet.length > 300 ? snippet[0, 297] + '...' : snippet
end

require 'net/http'
require 'uri'
require 'json'

require_relative 'extractors'

load './conf/tavily.conf' # $TAVILYCONF const

def tavilySearch(message)
  goSearch = true

  if($LimitSearch != 0)
    goSearch = checkCountRequestLimit(message)
  end

  if(goSearch)
    if (isThereAQuery(message))
      body = createAPIBody message
      response = sendRequestToJSON(URI($TAVILYCONF['url']), body)
      if(response['code'] == "200" && isImageSearch(message) && response['images'].to_a.empty?)
        response['code'] = "0"
      end
    else
      response = Hash["code" => "-1"]
    end

    if($LogToConsole || $LogToFile)
      log(message,response)
    end

  else
    response = Hash["code" => "999"]
  end
  sendResponseToChannel(message, response)
end

def createAPIBody(message)
  body = {
    'query' => extractQuery(message),
    'max_results' => $TAVILYCONF['numberOfResults'],
    'exclude_domains' => $TAVILYCONF['excludeDomains']
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

  req_options = {
    use_ssl: uri.scheme == 'https',
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  begin
    respJSON = JSON.parse(response.body)
  rescue JSON::ParserError
    respJSON = Hash.new
  end
  respJSON["code"] = response.code
  respJSON["message"] = response.message

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

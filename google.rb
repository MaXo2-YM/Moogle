require 'net/http'
require 'uri'
require 'json'

load './conf/APIGoogle.conf' # $GOOGLECONF const

def googleSearch(message)
  goSearch = true

  if($LimitSearch != 0)
    goSearch = checkCountRequestLimit(message)
  end

  if(goSearch)
    query = extract_params message
    if (query != '-1')
      queryAPI = createAPIQuery query
      response = sendRequestToJSON queryAPI
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

def createAPIQuery(query)
    params = {
      'key' => $GOOGLECONF['APIKey'],
      'cx' =>  $GOOGLECONF['customSearchID'],
      'gl' => $GOOGLECONF['geoloc'],
      'hl' => $GOOGLECONF['UIlang'],
      'nums' => $GOOGLECONF['numberOfResults'],
      'q' => query
    }

    uri = createUri($GOOGLECONF['url'], params)
end

def createUri(url, params)
  URI(url + '?' + URI.encode_www_form(params))
end

def sendRequestToJSON(uri)
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'

  req_options = {
    use_ssl: uri.scheme == 'https',
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  respJSON = JSON.parse(response.body)
  respJSON["code"] = response.code
  respJSON["message"] = response.message
  
  if(respJSON["code"] == "200" && respJSON['searchInformation']['totalResults'] == '0')
    respJSON["code"] = "0"
  end
  respJSON

end
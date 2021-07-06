require 'net/http'
require 'uri'
require 'json'

load './conf/APIGoogle.conf' # $GOOGLECONF const

def googleSearch(message)
  request = extract_params(message)

  if request != '-1'
    params = {
      'key' => $GOOGLECONF['APIKey'],
      'cx' =>  $GOOGLECONF['customSearchID'],
      'gl' => $GOOGLECONF['geoloc'],
      'hl' => $GOOGLECONF['UIlang'],
      'nums' => $GOOGLECONF['numberOfResults'],
      'q' => extract_params(message)
    }

    uri = createUri($GOOGLECONF['url'], params)
    respJSON = sendRequestToJSON(uri)
  else
    respJSON = Hash["code" => "-1"]
  end

  if($LogToConsole || $LogToFile)
    log(message,respJSON)
  end

  sendResponseToChannel(message,respJSON)
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
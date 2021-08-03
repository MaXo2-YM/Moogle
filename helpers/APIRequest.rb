require 'net/http'
require 'uri'
require 'json'

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
  respJSON['code'] = response.code
  respJSON['message'] = response.message

  if (respJSON['kind'].match(/youtube.*/))
    if(respJSON['code'] == '200' && respJSON['pageInfo']['totalResults'] == 0)
      respJSON['code'] = '0'
    end
  else
    if(respJSON['code'] == '200' && respJSON['searchInformation']['totalResults'] == '0')
      respJSON['code'] = '0'
    end
  end
  respJSON
end
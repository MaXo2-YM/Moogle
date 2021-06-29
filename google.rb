require 'net/http'
require 'uri'
require 'json'

load './conf/APIGoogle.conf' # $GOOGLECONF const

def googleSearch(message)
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

  log(message,respJSON)
  
  if (respJSON['code'] == "200")
    message.channel.send_embed do |embed|
      embed.title = respJSON['items'][0]['title']
      embed.url = respJSON['items'][0]['link']
      if(respJSON['items'][0]['pagemap']['cse_thumbnail'])
        embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: respJSON['items'][0]['pagemap']['cse_thumbnail'][0]['src'])
      end
      embed.description = respJSON['items'][0]['snippet']
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: respJSON['items'][0]['displayLink'])
    end
  elsif (respJSON['code'] == "0")
    message.respond 'Désolé, frère, j\'trouve rien.'
  else
    message.respond 'y\'a un Bug API la putain de ta grand mère.'
    message.respond "Code retour : `#{respJSON['code']}`"
    message.respond "Message : `#{respJSON['message']}`"
  end
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
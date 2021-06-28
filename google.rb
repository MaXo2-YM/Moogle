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

  if (respJSON == 0)
    message.respond 'Désolé, frère, j\'trouve rien.'
  elsif (respJSON['code'])
    message.respond "y'a un Bug API la putain de ta grand mère."
    message.respond "Code retour : `#{respJSON['code']}`"
    message.respond "Message : `#{respJSON['message']}`"
  else
  message.channel.send_embed do |embed|
    embed.title = respJSON['items'][0]['title']
    embed.url = respJSON['items'][0]['link']
    embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: respJSON['items'][0]['pagemap']['cse_thumbnail'][0]['src'])
    embed.description = respJSON['items'][0]['snippet']
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: respJSON['items'][0]['displayLink'])
  end
end
end

def createUri(url, params)
  URI(url + '?' + URI.encode_www_form(params))
end

def sendRequestToJSON(uri)
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/json"

  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  if(response.code == '200')
    respJSON = JSON.parse(response.body)
    if(respJSON['searchInformation']['totalResults'] != '0')
      respJSON
    else
      0
    end
  else
    {
      'code' => response.code,
      'message' => response.message
    }
  end
end
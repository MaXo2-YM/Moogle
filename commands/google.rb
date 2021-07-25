require_relative '../helpers/extractors'
require_relative '../helpers/APIRequest'
require_relative '../helpers/count'
require_relative '../helpers/logs'
require_relative '../helpers/misc'

load './conf/APIGoogle.conf' # $GOOGLECONF const

def googleSearch(message)
  goSearch = true

  if($LimitSearch != 0)
    goSearch = checkCountRequestLimit(message)
  end

  if(goSearch)
    if (isThereAQuery(message))
      queryAPI = createAPIQuery message
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

def createAPIQuery(message)
    params = {
      'key' => $GOOGLECONF['APIKey'],
      'cx' =>  $GOOGLECONF['customSearchID'],
      'gl' => $GOOGLECONF['geoloc'],
      'hl' => $GOOGLECONF['UIlang'],
      'nums' => $GOOGLECONF['numberOfResults'],
      'q' => extractQuery(message)
    }

    if(extractArgs(message))
      if(extractArgs(message).match(/-[a-z]*i[a-z]*/))
        params['searchType'] = 'image'
      end
    end

    uri = createUri($GOOGLECONF['url'], params)
end
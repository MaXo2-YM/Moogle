load './conf/APIYoutube.conf' # $YOUTUBECONF const
require_relative '../helpers/misc'
require_relative '../helpers/APIRequest'
 
def youtubeSearch(message)
  if (isThereAQuery(message))
    queryAPI = createYoutubeAPIQuery message
    response = sendRequestToJSON queryAPI
  else
    response = Hash["code" => "-1"]
  end

  if($LogToConsole || $LogToFile)
    log(message,response)
  end

  sendResponseToChannel(message, response)
end

def createYoutubeAPIQuery(message)
    params = {
      'key' => $YOUTUBECONF['APIKey'],
      'maxResults' => $YOUTUBECONF['numberOfResults'],
      'part' => $YOUTUBECONF['typeOfResults'],
      'channelType' => $YOUTUBECONF['channelType'],
      'safeSearch' => $YOUTUBECONF['safeSearch'],
      'type' => $YOUTUBECONF['type'],
      'q' => extractQuery(message)
    }

    uri = createUri($YOUTUBECONF['url'], params)
end
def isThereAQuery(message)
  !extractQuery(message).empty?
end

def isImageSearch(message)
  extractArgs(message) && extractArgs(message).match(/-[a-z]*i[a-z]*/)
end

def displayLink(url)
  URI(url).host || url
rescue URI::InvalidURIError
  url
end

# Daily count, missing query, log and answer, around the API request the block makes
def runSearch(message)
  goSearch = true

  if($LimitSearch != 0 && isThereAQuery(message)) # a command without query doesn't cost a search
    goSearch = checkCountRequestLimit(message)
  end

  if(goSearch)
    if (isThereAQuery(message))
      response = yield
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
  response
end

# Sends a request to a search API, its JSON answer gets the HTTP "code" and "message"
def requestJSON(uri, request)
  req_options = {
    use_ssl: uri.scheme == 'https',
    open_timeout: 5,
    read_timeout: 15
  }

  begin
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
  rescue StandardError => e # timeout, DNS, TLS...: answer like an API error instead of failing silently
    return Hash["code" => e.class.name, "message" => e.message]
  end

  begin
    respJSON = JSON.parse(response.body)
  rescue JSON::ParserError
    respJSON = Hash.new
  end
  respJSON["code"] = response.code
  respJSON["message"] = response.message
  respJSON
end

def sendResponseToChannel(message, response)
  case response['code']
  when "200"
    message.channel.send_embed do |embed|
      if(isImageSearch(message))
        embed.image = Discordrb::Webhooks::EmbedImage.new(url: response['images'][0])
        embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: displayLink(response['images'][0]))
      else
        embed.title = response['results'][0]['title']
        embed.url = response['results'][0]['url']
        embed.description = cleanSnippet(response['results'][0]['content'])
        embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: displayLink(response['results'][0]['url']))
      end
    end
  when "0"
    message.respond $__error_no_results_found
  when "-1"
    message.respond $__error_no_query.gsub(/%[0-9]/, '%1' => extractPrefix(message) + extractCmd(message))
  when "999"
    message.respond $__error_cap_limit_exceeded.gsub(/%[0-9]/, "%1" => getNextRequestTime(countRecentRequest))
  else
    message.respond $__error_api.gsub(/%[0-9]/, '%1' => response['code'], '%2' => response['message'])
  end
end

LOG_HEADER = "[   Date    -   Time  ]\tUser\tCommand\tOptions\tRequest\t\t\t\tStatus\tlink"

# One file a day: reconnections to Discord no longer create a new file each
def logFileName
  "./log/moogle_#{Time.new.strftime('%Y-%m-%d')}.log"
end

def log(message, response)
  respTime = Time.new.strftime("[%d/%m/%Y - %H:%M:%S]")

  link = "null"
  if (response["code"] == "200")
    link = isImageSearch(message) ? response['images'][0] : response['results'][0]['url']
  end

  query = isThereAQuery(message) ? extractQuery(message) : ''
  options = isThereAQuery(message) ? extractArgs(message) ? extractArgs(message) : '' : ''

  line = "#{respTime}\t#{message.author.username}\t#{extractCmd(message)}\t#{options}\t#{query}\t#{response['code']}\t#{link}"

  if($LogToConsole)
    puts line
  end

  if($LogToFile)
    if(!File.exist?(logFileName))
      File.write(logFileName, LOG_HEADER + "\n")
    end
    File.write(logFileName, line + "\n", mode: 'a')
  end

end
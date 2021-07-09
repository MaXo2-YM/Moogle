def extract_prefix(message)
  message.content.chr
end

def extract_cmd(message)
  message.content[1..][/(\w+)/, 0] # first word without prefix
end

def extract_params(message)
  if(message.content.index(" "))
    args = message.content[message.content.index(" ")+1..] # all after first space
  else
    args = '-1'
  end
end

def sendResponseToChannel(message, response)
  if (response['code'] == "200")
    message.channel.send_embed do |embed|
      embed.title = response['items'][0]['title']
      embed.url = response['items'][0]['link']
      if(response['items'][0]['pagemap']['cse_thumbnail'])
        embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: response['items'][0]['pagemap']['cse_thumbnail'][0]['src'])
      end
      embed.description = response['items'][0]['snippet']
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: response['items'][0]['displayLink'])
    end
  elsif (response['code'] == "0")
    message.respond $__error_no_results_found
  elsif (response['code'] == "-1")
    message.respond $__error_no_query.gsub(/%[0-9]/, '%1' => extract_cmd(message))
  else
    message.respond $__error_api_google.gsub(/%[0-9]/, '%1' => response['code'], '%2' => response['message'])
  end
end

def log(message, response)
  respTime = Time.new.strftime("[%d/%m/%Y - %H:%M:%S]")

  link = "null"
  if (response["code"] == "200")
    link = response['items'][0]['link']
  end

  query = extract_params(message) != '-1' ? extract_params(message) : ''

  line = "#{respTime}\t#{message.author.username}\t#{extract_cmd(message)}\t#{query}\t#{response['code']}\t#{link}"

  if($LogToConsole)
    puts line
  end

  if($LogToFile)
    File.write($logfile, line + "\n", mode: 'a')
  end

end
def isThereAQuery(message)
  if(message.content.index(" "))
    return true
  else
    '-1'
  end
end

def sendResponseToChannel(message, response)
  case response['code']
  when "200"
    message.channel.send_embed do |embed|
      if(extractArgs(message) && extractArgs(message).match(/-[a-z]*i[a-z]*/))
        embed.image = Discordrb::Webhooks::EmbedImage.new(url: response['items'][0]['link'])
      else
        embed.title = response['items'][0]['title']
        embed.url = response['items'][0]['link']
        if(response['items'][0]['pagemap']['cse_thumbnail'])
          embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: response['items'][0]['pagemap']['cse_thumbnail'][0]['src'])
        end
        embed.description = response['items'][0]['snippet']
      end
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: response['items'][0]['displayLink'])
    end
  when "0"
    message.respond $__error_no_results_found
  when "-1"
    message.respond $__error_no_query.gsub(/%[0-9]/, '%1' => extractPrefix(message) + extractCmd(message))
  when "999"
    message.respond $__error_cap_limit_exceeded.gsub(/%[0-9]/, "%1" => getNextRequestTime(countRecentRequest))
  else
    message.respond $__error_api_google.gsub(/%[0-9]/, '%1' => response['code'], '%2' => response['message'])
  end
end

def log(message, response)
  respTime = Time.new.strftime("[%d/%m/%Y - %H:%M:%S]")

  link = "null"
  if (response["code"] == "200")
    if(extractCmd(message).match($commands['youtube']))
      link = $YOUTUBECONF['urlVideo'] + response['items'][0]['id']['videoId']
    else
      link = response['items'][0]['link']
    end
  end

  query = isThereAQuery(message) != '-1' ? extractQuery(message) : ''
  options = isThereAQuery(message) != '-1' ? extractArgs(message) ? extractArgs(message) : '' : ''

  line = "#{respTime}\t#{message.author.username}\t#{extractCmd(message)}\t#{options}\t#{query}\t#{response['code']}\t#{link}"

  if($LogToConsole)
    puts line
  end

  if($LogToFile)
    File.write($logfile, line + "\n", mode: 'a')
  end

end
def log(message, response)
  respTime = Time.new.strftime("[%d/%m/%Y - %H:%M:%S]")

  link = "null"
  if (response["code"] == "200")
    link = response['items'][0]['link']
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
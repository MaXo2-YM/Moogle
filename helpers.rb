def extract_prefix(message)
  message.content.chr
end

def extract_cmd(message)
  message.content[1..][/(\w+)/, 0] # first word without prefix
end

def extract_params(message)
  args = message.content[message.content.index(" ")+1..] # all after first space
end

def log(message, response)
  respTime = Time.new.strftime("[%d/%m/%Y - %H:%M:%S]")

  link = "null"
  if (response["code"] == "200")
    link = response['items'][0]['link']
  end

  line = "#{respTime}\t#{message.author.username}\t#{extract_cmd(message)}\t#{extract_params(message)}\t#{response['code']}\t#{link}"

  puts line
end
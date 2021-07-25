def extractPrefix(message)
  if(message.content.chr == $discord['prefix'])
    message.content.chr
  else
    "@"
  end
end
  
def extractCmd(message)
  if(extractPrefix(message) == $discord['prefix'])
    message.content[1..][/(\w+)/, 0] # first word without prefix
  else
    "Mention"
  end
end
  
def extractArgs(message)
  message.content.split(" ").each do |arg|
    if(arg.match(/^-[a-z]*/))
      return arg
    end
  end
  return false
end
  
def extractQuery(message)
  if(extractPrefix(message) == $discord['prefix'])
    fullQuery = message.content[message.content.index(" ")+1..] # all after first space

    justQuery = Array.new
    fullQuery.split(' ') do |word|
      if(!word.match(/^-[a-z]*/))
        justQuery.push(word)
      end
    end
    justQuery.join(' ')

  else
    words = message.content.split # get array of words from the message
    mention =  words.find_index{|x| x.match /<@![0-9]{18}>/ } # get the index of the mention
    words[mention+1..].join(' ') # extract the phrase after the mention
  end
end
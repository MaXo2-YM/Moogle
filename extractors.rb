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
  
# Options are letters only, so "-10" or "-5°C" stay in the query
def isOption(word)
  word.match?(/^-[a-z]+$/)
end

def extractArgs(message)
  message.content.split(" ").each do |arg|
    if(isOption(arg))
      return arg
    end
  end
  return false
end
  
def extractQuery(message)
  if(extractPrefix(message) == $discord['prefix'])
    fullQuery = message.content.split(' ', 2)[1].to_s # all after first space

    justQuery = Array.new
    fullQuery.split(' ') do |word|
      if(!isOption(word))
        justQuery.push(word)
      end
    end
    justQuery.join(' ')

  else
    words = message.content.split # get array of words from the message
    # Discord dropped the "!" of nickname mentions, both forms still exist in old clients
    mention = words.find_index{|x| x.match /<@!?#{message.bot.profile.id}>/ } # get the index of the bot mention
    if(mention.nil?)
      return ''
    end
    words[mention+1..].join(' ') # extract the phrase after the mention
  end
end
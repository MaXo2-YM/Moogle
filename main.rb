require 'discordrb'
require_relative 'google'
require_relative 'helpers'
require_relative 'count'
load './conf/app.conf'
load './conf/discord.conf' # $discord const
load './conf/cmd.conf' # $commands const

for arg in ARGV
  if(arg.match(/-(-verbose|[a-z]*v[a-z]*)/))
    $LogToConsole = true
  end
  if(arg.match(/-(-log|[a-z]*l[a-z]*)/))
    $LogToFile = true
  end
end

bot = Discordrb::Commands::CommandBot.new token: $discord['token'], prefix: $discord['prefix']
bot.ready do |event|
  if($LogToConsole)
    puts "[   Date    -   Time  ]\tUser\tCommand\tRequest\t\t\t\tStatus\tlink"
  end

  if($LogToFile)
    now = Time.new.strftime("%Y-%m-%d_%H-%M-%S")
    $logfile = File.open("./log/moogle_#{now}.log", "w")
    File.write($logfile, "[   Date    -   Time  ]\tUser\tCommand\tRequest\t\t\t\tStatus\tlink\n", mode: "a")
  end
end


bot.message do |message|
  if(bot.prefix == extract_prefix(message))
    if(extract_cmd(message).match($commands['google'])) 
      if($LimitSearch != 0)
        countRequests = countRecentRequest
        if(countRequests.length < $LimitSearch)
          addRequestToCount
          googleSearch(message)
        else
          message.respond "Désolé bro, je ne pourrais plus faire de recherche avant le #{getNextRequestTime(countRequests)} :("
        end
      else
      googleSearch(message)
    end
  end
end
end

bot.run
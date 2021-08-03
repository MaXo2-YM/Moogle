require 'discordrb'
require_relative './commands/google'
require_relative './commands/youtube'
load './conf/app.conf'
load './conf/discord.conf' # $discord const
load './conf/cmd.conf' # $commands const
load "./lang/#{$Language}"

for arg in ARGV
  if(arg.match(/-(-verbose|[a-z]*v[a-z]*)/))
    $LogToConsole = true
  end
  if(arg.match(/-(-log|[a-z]*l[a-z]*)/))
    $LogToFile = true
  end
  if(arg.match(/-(-uncap|[a-z]*uc[a-z]*)/))
    $LimitSearch = 0
  end
end

bot = Discordrb::Commands::CommandBot.new token: $discord['token'], prefix: $discord['prefix']
bot.ready do |event|
  bot.watching= "!google <search>"

  if($LogToConsole)
    puts "[   Date    -   Time  ]\tUser\tCommand\tOptions\tRequest\t\t\t\tStatus\tlink"
  end

  if($LogToFile)
    now = Time.new.strftime("%Y-%m-%d_%H-%M-%S")
    $logfile = File.open("./log/moogle_#{now}.log", "w")
    File.write($logfile, "[   Date    -   Time  ]\tUser\tCommand\tOptions\tRequest\t\t\t\tStatus\tlink\n", mode: "a")
  end
end


bot.message do |message|
  if(bot.prefix == extractPrefix(message))
    if(extractCmd(message).match($commands['google']))
      googleSearch message
    elsif(extractCmd(message).match($commands['youtube']))
      youtubeSearch message
    end
  end
end

bot.mention do |message|
  googleSearch message
end

bot.run
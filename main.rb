require 'discordrb'
require_relative 'tavily'
require_relative 'helpers'
require_relative 'count'
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

if($LogToConsole)
  puts LOG_HEADER
end

bot = Discordrb::Commands::CommandBot.new token: $discord['token'], prefix: $discord['prefix']
bot.ready do |event| # on every (re)connection to Discord
  bot.watching= "!google <search>"
end


bot.message do |message|
  if(bot.prefix == extractPrefix(message))
    if(extractCmd(message).match($commands['google']))
      tavilySearch message
    end
  end
end

bot.mention do |message|
  tavilySearch message
end

bot.run
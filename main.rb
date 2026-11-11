require 'discordrb'
require_relative 'tavily'
require_relative 'youtube'
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
    $Uncapped = true # lifts the daily limit of every command
  end
end

if($LogToConsole)
  puts LOG_HEADER
end

# Gateway v9 only sends what the bot asks for. The default (:all) asks for privileged intents the bot doesn't need and Discord refuses the connection, and discordrb doesn't know MESSAGE_CONTENT (1 << 15), without which server messages arrive empty and `!google` never matches. It must also be enabled in the Developer Portal.
MESSAGE_CONTENT_INTENT = 1 << 15
intents = Discordrb::INTENTS.values_at(:servers, :server_messages, :direct_messages).reduce(:|) | MESSAGE_CONTENT_INTENT

bot = Discordrb::Commands::CommandBot.new token: $discord['token'], prefix: $discord['prefix'], intents: intents
bot.ready do |event| # on every (re)connection to Discord
  showStatus(bot, force: true)
end
startHealthCheck(bot)


bot.message do |message|
  if(bot.prefix == extractPrefix(message))
    if(extractCmd(message).match($commands['google']))
      tavilySearch message
    elsif(extractCmd(message).match($commands['youtube']))
      youtubeSearch message
    end
  end
end

bot.mention do |message|
  tavilySearch message
end

bot.run
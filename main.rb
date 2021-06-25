require 'discordrb'
require_relative 'google'
require_relative 'helpers'
load './conf/discord.conf' # $discord const
load './conf/cmd.conf' # $commands const

bot = Discordrb::Commands::CommandBot.new token: $discord['token'], prefix: $discord['prefix']

bot.message do |message|
  if(bot.prefix == extract_prefix(message))
    if(extract_cmd(message).match($commands['google'])) 
      googleSearch(message)
    end
  end
end

bot.run

#  @TODO :
#  Refactor (configs in separate files, commands list in separate file, beautify and clean code)
#  add error management
#  add daily count and stop
#  add mention
#  add google image
#  add YouTube
#  add help

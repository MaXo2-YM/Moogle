require 'discordrb'
require_relative 'google'
require_relative 'helpers'
load './conf/discord.conf' # $discord const
load './conf/cmd.conf' # $commands const

bot = Discordrb::Commands::CommandBot.new token: $discord['token'], prefix: $discord['prefix']
bot.ready do |event|
  puts "[   Date    -   Time  ]\tUser\tCommand\tRequest\t\t\t\tStatus\tlink"

  now = Time.new.strftime("%Y-%m-%d_%H-%M-%S")
  $logfile = File.open("./log/moogle_#{now}.log", "w")
  File.write($logfile, "[   Date    -   Time  ]\tUser\tCommand\tRequest\t\t\t\tStatus\tlink\n", mode: "a")
end


bot.message do |message|
  if(bot.prefix == extract_prefix(message))
    if(extract_cmd(message).match($commands['google'])) 
      googleSearch(message)
    end
  end
end

bot.run
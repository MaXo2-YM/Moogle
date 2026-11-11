require_relative 'count'
require_relative 'tavily'
require_relative 'youtube'
require_relative 'wikipedia'
require_relative 'wiktionary'
require_relative 'steam'

# The commands !help lists, in this order: a command shows when its service is set up and its daily limit isn't reached
HELP_COMMANDS = [
  { key: 'google', count: GOOGLE_COUNT, limit: -> { googleDailyLimit }, enabled: -> { isConfigured($TAVILYCONF) } },
  { key: 'youtube', count: YOUTUBE_COUNT, limit: -> { youtubeDailyLimit }, enabled: -> { isConfigured($YOUTUBECONF) } },
  { key: 'wiki', count: WIKI_COUNT, limit: -> { wikiDailyLimit }, enabled: -> { true } },
  { key: 'wiktionary', count: WIKT_COUNT, limit: -> { wiktDailyLimit }, enabled: -> { true } },
  { key: 'steam', count: STEAM_COUNT, limit: -> { steamDailyLimit }, enabled: -> { true } }
]

def availableCommands
  HELP_COMMANDS.select { |command| command[:enabled].call && !isLimitReached(command[:count], command[:limit].call) }.map { |command| command[:key] }
end

def helpText
  commands = availableCommands
  if(commands.empty?)
    return $__help_nothing_available
  end
  ([$__help_header] + commands.map { |key| $__help_commands[key] }).join("\n\n").gsub('%p', $discord['prefix']) # %p: the command prefix
end

# In private, so the list doesn't flood the channel: a 📬 reaction there tells where to look
def helpCommand(message)
  begin
    message.author.pm(helpText)
  rescue StandardError # private messages closed (Discord error 50007), or Discord unreachable
    return message.respond($__help_private_closed)
  end

  if(!message.channel.pm?)
    begin
      message.message.react('📬')
    rescue StandardError # no permission to add reactions: the private message is what matters
    end
  end
end

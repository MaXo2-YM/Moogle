require_relative 'count'
require_relative 'tavily'
require_relative 'youtube'
require_relative 'wikipedia'
require_relative 'wiktionary'
require_relative 'steam'

# The commands !help lists, in this order, when their service is set up
HELP_COMMANDS = [
  { key: 'google', count: GOOGLE_COUNT, limit: -> { googleDailyLimit }, enabled: -> { isConfigured($TAVILYCONF) } },
  { key: 'youtube', count: YOUTUBE_COUNT, limit: -> { youtubeDailyLimit }, enabled: -> { isConfigured($YOUTUBECONF) } },
  { key: 'wiki', count: WIKI_COUNT, limit: -> { wikiDailyLimit }, enabled: -> { true } },
  { key: 'wiktionary', count: WIKT_COUNT, limit: -> { wiktDailyLimit }, enabled: -> { true } },
  { key: 'steam', count: STEAM_COUNT, limit: -> { steamDailyLimit }, enabled: -> { true } }
]

# Commands whose service is set up: the others are left out, they won't come back by themselves. !wiki, !wikt and !steam need no key, so the list is never empty.
def enabledCommands
  HELP_COMMANDS.select { |command| command[:enabled].call }
end

# When a command reached its daily limit, the time its oldest search of the day leaves the 24 h window; nil when it's available
def commandAvailableAt(command)
  if(!isLimitReached(command[:count], command[:limit].call))
    return nil
  end
  Time.new(*countRecentRequest(command[:count])[0].split('.')) + 86400
end

def availableCommands
  enabledCommands.reject { |command| commandAvailableAt(command) }.map { |command| command[:key] }
end

# A command waiting for its daily limit is struck through with "(dispo dans 3 heures)": a Discord timestamp, shown in the reader's language and kept up to date by Discord
def helpText
  texts = enabledCommands.map do |command|
    text = $__help_commands[command[:key]]
    availableAt = commandAvailableAt(command)
    if(availableAt)
      title, description = text.split("\n", 2)
      text = "~~#{title}~~ " + $__help_available_at.gsub('%1', "<t:#{availableAt.to_i}:R>") + "\n" + description
    end
    text
  end
  ([$__help_header] + texts).join("\n\n").gsub('%p', $discord['prefix']) # %p: the command prefix
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

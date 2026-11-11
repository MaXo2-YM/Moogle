require 'net/http'
require 'uri'
require 'json'
require 'time'

require_relative 'extractors'
require_relative 'health'

# Optional command: without its config file the bot still starts, and tells how to set it up
if(File.exist?('./conf/youtube.conf'))
  load './conf/youtube.conf' # $YOUTUBECONF const
end

def youtubeSearch(message)
  if(!isConfigured($YOUTUBECONF))
    return answerNotConfigured(message, 'youtube-search')
  end

  runSearch(message, YOUTUBE_COUNT, youtubeDailyLimit) do
    sendYoutubeRequest(createYoutubeUri(message))
  end
  # The status tells about !google only: YouTube's own limit is told in the answer
end

def createYoutubeUri(message)
  params = {
    'key' => $YOUTUBECONF['APIKey'],
    'part' => 'snippet',
    'type' => 'video',
    'maxResults' => 1,
    'q' => extractQuery(message),
    'safeSearch' => isSafeSearch(message) ? 'strict' : 'none'
  }

  if($YOUTUBECONF['embeddableOnly'])
    params['videoEmbeddable'] = 'true' # only videos Discord can play in the channel
  end
  if(!$YOUTUBECONF['regionCode'].to_s.empty?)
    params['regionCode'] = $YOUTUBECONF['regionCode']
  end
  if(!$YOUTUBECONF['relevanceLanguage'].to_s.empty?)
    params['relevanceLanguage'] = $YOUTUBECONF['relevanceLanguage']
  end

  URI($YOUTUBECONF['url'] + '?' + URI.encode_www_form(params))
end

# A bot's embed can't hold a video player: the answer is the plain link, Discord turns it into a player itself
def sendYoutubeRequest(uri)
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'

  respJSON = requestJSON(uri, request)
  if(respJSON["code"] == "200")
    if(respJSON['items'].to_a.empty?)
      respJSON["code"] = "0"
    else
      videoId = respJSON['items'][0]['id']['videoId']
      respJSON['videoUrl'] = $YOUTUBECONF['urlVideo'] + videoId
      respJSON['videoDetails'] = getVideoDetails(videoId)
    end
  end
  respJSON
end

# Date, views, duration and description, which Discord's preview doesn't show (1 quota unit). nil if it fails: the link alone is still worth sending.
def getVideoDetails(videoId)
  params = {
    'key' => $YOUTUBECONF['APIKey'],
    'part' => 'snippet,statistics,contentDetails',
    'id' => videoId
  }
  uri = URI($YOUTUBECONF['url'].sub(%r{/search\z}, '/videos') + '?' + URI.encode_www_form(params))
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'

  respJSON = requestJSON(uri, request)
  if(respJSON["code"] != "200" || respJSON['items'].to_a.empty?)
    return nil
  end
  respJSON['items'][0]
end

# The message above the link: Discord still turns the link into its player, which a bot's own embed would prevent
def formatVideoMessage(response)
  details = response['videoDetails']
  if(details.nil?)
    return response['videoUrl']
  end

  infos = []
  if(details.dig('snippet', 'publishedAt'))
    infos << "📅 " + Time.iso8601(details['snippet']['publishedAt']).strftime($__date_format_video)
  end
  if(details.dig('statistics', 'viewCount')) # hidden by some channels
    infos << "👁 " + $__views.gsub('%1', formatCount(details['statistics']['viewCount'].to_i))
  end
  if(details.dig('snippet', 'liveBroadcastContent') == 'live')
    infos << "🔴 " + $__live
  elsif(formatDuration(details.dig('contentDetails', 'duration')))
    infos << "⏱ " + formatDuration(details['contentDetails']['duration'])
  end

  lines = []
  lines << infos.join(' · ') if !infos.empty?
  description = cleanDescription(details.dig('snippet', 'description'))
  lines << "> " + description if !description.empty?
  lines << response['videoUrl']
  lines.join("\n")
end

# 1234 -> "1,2 k", 1700000000 -> "1,7 Md" (separator and units from the language file)
def formatCount(count)
  unit = 0
  value = count.to_f
  while(value >= 1000 && unit < $__number_units.length - 1)
    value /= 1000
    unit += 1
  end

  if(unit == 0)
    return count.to_s
  end
  number = value < 10 ? value.round(1).to_s.sub(/\.0\z/, '') : value.round.to_s
  number.sub('.', $__decimal_separator) + $__number_units[unit]
end

# ISO 8601 "PT1H2M3S" -> "1:02:03", "PT3M33S" -> "3:33". nil for "P0D" (upcoming or live) or an unknown format.
def formatDuration(duration)
  match = duration.to_s.match(/\AP(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?\z/)
  if(match.nil?)
    return nil
  end

  hours = match[1].to_i * 24 + match[2].to_i
  minutes = match[3].to_i
  seconds = match[4].to_i
  if(hours + minutes + seconds == 0)
    return nil
  end
  hours > 0 ? format('%d:%02d:%02d', hours, minutes, seconds) : format('%d:%02d', minutes, seconds)
end

# First words of the description, without its links and hashtags, and with its markdown escaped so it can't break the message
def cleanDescription(description)
  text = description.to_s
    .gsub(%r{https?://\S+}, '')
    .gsub(/(^|\s)#\S+/, ' ')
    .gsub(/\s+/, ' ')
    .strip
  if(text.length > 200)
    text = text[0, 200].sub(/\s+\S*\z/, '') + '…'
  end
  text.gsub(/([\\*_~`|>\[\]])/, '\\\\\1')
end

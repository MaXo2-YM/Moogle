# Each search service has its own daily count: their free quotas have nothing in common (Tavily: 1,000 credits a month, YouTube: 10,000 units a day)
GOOGLE_COUNT = 'count'
YOUTUBE_COUNT = 'count_youtube'

# 0 means no limit. --uncap lifts every limit.
def googleDailyLimit
  if($Uncapped)
    return 0
  end
  if(!$TAVILYCONF.nil? && !$TAVILYCONF['dailyLimit'].nil?)
    return $TAVILYCONF['dailyLimit']
  end
  $LimitSearch.nil? ? 30 : $LimitSearch # $LimitSearch: the shared limit of app.conf before 2026-11
end

def youtubeDailyLimit
  if($Uncapped)
    return 0
  end
  $YOUTUBECONF.nil? || $YOUTUBECONF['dailyLimit'].nil? ? 90 : $YOUTUBECONF['dailyLimit']
end

def isLimitReached(countFile, limit)
  limit != 0 && countRecentRequest(countFile).length >= limit
end

def checkCountRequestLimit(countFile, limit)
  countRequests = countRecentRequest(countFile)
  if(countRequests.length < limit)
    addRequestToCount(countFile)
    true
  else
    false
  end
end

def countRecentRequest(countFile = GOOGLE_COUNT)
  if(!File.exist?(countFile)) # created by the first request
    return []
  end

  file = File.open(countFile, "r")
    now = Time.new
    countRequests = file.readlines.map(&:chomp)
    countRequests.reject! do |line|
      line.empty? || (now - Time.new(*line.split('.'))) / 60 / 60 > 24
    end
    file.close

    updateCountFile(countRequests, countFile)

    countRequests
end

def updateCountFile(countRequests, countFile = GOOGLE_COUNT)
  file = File.open(countFile, "w")
  countRequests.each do |line|
    File.write(file, line + "\n", mode: "a")
  end
  file.close
end

def addRequestToCount(countFile = GOOGLE_COUNT)
  file = File.open(countFile, "a")
  File.write(file, Time.new.strftime("%Y.%m.%d.%H.%M.%S") + "\n", mode: "a")
  file.close
end

def getNextRequestTime(oldRequests)
  firstRequest = Time.new(*oldRequests[0].split('.'))
  nextResquest = firstRequest + 86400 #We add 24h
  nextResquest.strftime($__date_format_cap_limit)
end

def checkCountRequestLimit(message)
  countRequests = countRecentRequest
  if(countRequests.length < $LimitSearch)
    addRequestToCount
    true
  else
    false
  end
end

def countRecentRequest
  if(!File.exist?("count")) # created by the first request
    return []
  end

  countFile = File.open("count", "r")
    now = Time.new
    countRequests = countFile.readlines.map(&:chomp)
    countRequests.reject! do |line|
      line.empty? || (now - Time.new(*line.split('.'))) / 60 / 60 > 24
    end
    countFile.close
    
    updateCountFile(countRequests)
    
    countRequests
end

def updateCountFile(countRequests)
  countFile = File.open("count", "w")
  countRequests.each do |line|
    File.write(countFile, line + "\n", mode: "a")
  end
  countFile.close
end

def addRequestToCount
  countFile = File.open("count", "a")
  File.write(countFile, Time.new.strftime("%Y.%m.%d.%H.%M.%S") + "\n", mode: "a")
  countFile.close
end

def getNextRequestTime(oldRequests)
  firstRequest = Time.new(*oldRequests[0].split('.'))
  nextResquest = firstRequest + 86400 #We add 24h
  nextResquest.strftime($__date_format_cap_limit)
end
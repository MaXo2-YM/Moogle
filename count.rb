def countRecentRequest
  countFile = File.open("count", "r")
    now = Time.new
    countRequests = countFile.readlines.map(&:chomp)
    countRequests.each_with_index do |line, i|
      secondes = now - Time.new(*line.split('.'))
      if(secondes / 60 / 60 > 24)
        countRequests.slice!(i)
      end
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
  nextResquest = firstRequest + 86400 #We had 24h
  nextResquest.strftime("%d/%m/%Y à %H:%M:%S")
end
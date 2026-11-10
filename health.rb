# The bot's Discord status tells whether a search can be made: red after a failed Tavily call until the next successful one, orange while the daily count is full, green otherwise
$searchHealthy = true
$shownStatus = nil

def isLimitReached
  $LimitSearch != 0 && countRecentRequest.length >= $LimitSearch
end

def currentStatus
  if(!$searchHealthy)
    [:dnd, $__status_search_down]
  elsif(isLimitReached)
    [:idle, $__status_limited.gsub('%1', getNextRequestTime(countRecentRequest))]
  else
    [:online, $__status_ok]
  end
end

# Discord only gets the status when it changes, or on every (re)connection with force
def showStatus(bot, force: false)
  status = currentStatus
  if(!force && status == $shownStatus)
    return
  end

  $shownStatus = status
  bot.update_status(status[0], status[1], nil, 0, false, 3) # 3: "Watching"
  if(status[0] == :idle)
    scheduleStatusRefresh(bot)
  end
end

# Back to green on its own when the oldest search of the day leaves the 24 h window, without waiting for someone to try
def scheduleStatusRefresh(bot)
  $statusRefresh&.kill
  nextRequest = Time.new(*countRecentRequest[0].split('.')) + 86400
  $statusRefresh = Thread.new do
    sleep([nextRequest - Time.now, 0].max + 1)
    begin
      showStatus(bot)
    rescue StandardError => e # e.g. disconnected from Discord: the next reconnection shows it
      puts "status refresh failed: #{e.class}: #{e.message}"
    end
  end
end

def updateSearchHealth(bot, response)
  if(!["-1", "999"].include?(response['code'])) # no query or daily limit: Tavily wasn't called
    $searchHealthy = ["200", "0"].include?(response['code'])
  end
  showStatus(bot)
end

# A real search, outside the daily count, so the status doesn't wait for a user to find the failure
def checkSearchHealth(bot)
  response = sendRequestToJSON(URI($TAVILYCONF['url']), { 'query' => 'Moogle', 'max_results' => 1 })
  if($LogToConsole)
    puts "#{Time.new.strftime("[%d/%m/%Y - %H:%M:%S]")}\thealth check\t#{response['code']}"
  end
  updateSearchHealth(bot, response)
end

def startHealthCheck(bot)
  hours = $HealthCheckHours.nil? ? 24 : $HealthCheckHours
  if(hours <= 0)
    return
  end

  Thread.new do
    loop do
      sleep(hours * 3600)
      begin
        checkSearchHealth(bot)
      rescue StandardError => e # e.g. disconnected from Discord: try again next time
        puts "health check failed: #{e.class}: #{e.message}"
      end
    end
  end
end

# The bot's Discord status follows the search: red with a warning after a failed Tavily call, back to normal after the next successful one
$searchHealthy = true

def showStatus(bot)
  if($searchHealthy)
    bot.update_status(:online, $__status_ok, nil, 0, false, 3) # 3: "Watching"
  else
    bot.update_status(:dnd, $__status_search_down, nil, 0, false, 3)
  end
end

# Discord only gets the status when it changes
def updateSearchHealth(bot, response)
  if(["-1", "999"].include?(response['code'])) # no query or daily limit: Tavily wasn't called
    return
  end

  healthy = ["200", "0"].include?(response['code'])
  if(healthy != $searchHealthy)
    $searchHealthy = healthy
    showStatus(bot)
  end
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

require_relative 'test_helper'

class HealthTest < MoogleTest
  def timestamp(time)
    time.strftime('%Y.%m.%d.%H.%M.%S')
  end

  def test_failure_turns_the_status_red
    bot = FakeBot.new
    updateSearchHealth(bot, { 'code' => '401' })
    refute $searchHealthy
    assert_equal [[:dnd, $__status_search_down]], bot.statuses
  end

  def test_success_after_a_failure_turns_it_back
    bot = FakeBot.new
    updateSearchHealth(bot, { 'code' => 'Net::OpenTimeout' })
    updateSearchHealth(bot, { 'code' => '0' })
    assert $searchHealthy
    assert_equal [[:dnd, $__status_search_down], [:online, $__status_ok]], bot.statuses
  end

  def test_status_only_sent_when_it_changes
    bot = FakeBot.new
    2.times { updateSearchHealth(bot, { 'code' => '200' }) }
    2.times { updateSearchHealth(bot, { 'code' => '432' }) }
    assert_equal [[:dnd, $__status_search_down]], bot.statuses
  end

  def test_no_query_and_daily_limit_are_not_failures
    bot = FakeBot.new
    updateSearchHealth(bot, { 'code' => '-1' })
    updateSearchHealth(bot, { 'code' => '999' })
    assert $searchHealthy
    assert_empty bot.statuses
  end

  def test_reconnection_shows_the_status_again
    bot = FakeBot.new
    showStatus(bot, force: true)
    assert_equal [[:online, $__status_ok]], bot.statuses
  end

  def test_a_failed_search_turns_the_status_red
    message = FakeMessage.new('!google recette crêpes')
    withHTTP(FakeHTTP.new(FakeResponse.new('401', 'Unauthorized', '{}'))) { tavilySearch(message) }
    assert_equal [[:dnd, $__status_search_down]], message.bot.statuses
  end

  def test_last_allowed_search_turns_the_status_orange
    $TAVILYCONF['dailyLimit'] = 1
    message = FakeMessage.new('!google recette crêpes')
    withHTTP(FakeHTTP.new(tavilyResponse(results: [tavilyResult]))) { tavilySearch(message) }

    nextRequest = getNextRequestTime(countRecentRequest)
    assert_equal [[:idle, $__status_limited.gsub('%1', nextRequest)]], message.bot.statuses
    assert $statusRefresh.alive? # waiting for the oldest search to expire
  end

  def test_failure_is_shown_before_the_limit
    $TAVILYCONF['dailyLimit'] = 1
    File.write('count', timestamp(Time.now) + "\n")
    $searchHealthy = false
    assert_equal :dnd, currentStatus[0]
  end

  def test_back_to_green_when_the_oldest_search_expires
    $TAVILYCONF['dailyLimit'] = 1
    File.write('count', timestamp(Time.now - 86400 - 60) + "\n")
    assert_equal [:online, $__status_ok], currentStatus
  end

  def test_no_limit_never_turns_orange
    $TAVILYCONF['dailyLimit'] = 0
    File.write('count', timestamp(Time.now) + "\n")
    assert_equal :online, currentStatus[0]
  end

  def test_refresh_waits_until_the_oldest_search_expires
    $TAVILYCONF['dailyLimit'] = 1
    File.write('count', timestamp(Time.now - 86400 + 1) + "\n")
    bot = FakeBot.new
    showStatus(bot)
    assert_equal :idle, bot.statuses.last[0]

    sleep 2.5 # the oldest search expired 1 s after the refresh was scheduled, then +1 s margin
    assert_equal [:online, $__status_ok], bot.statuses.last
  end

  def test_health_check_searches_outside_the_daily_count
    bot = FakeBot.new
    $searchHealthy = false
    $shownStatus = [:dnd, $__status_search_down]
    fake = FakeHTTP.new(tavilyResponse(results: [tavilyResult]))
    withHTTP(fake) { checkSearchHealth(bot) }

    assert_equal 1, fake.requests.length
    assert_equal 'Moogle', fake.last_body['query']
    assert_equal [[:online, $__status_ok]], bot.statuses
    refute File.exist?('count')
  end

  def test_health_check_disabled_with_0_hours
    $HealthCheckHours = 0
    assert_nil startHealthCheck(FakeBot.new)
  end

  def test_health_check_runs_every_24_hours_by_default
    thread = startHealthCheck(FakeBot.new)
    sleep 0.05
    assert thread.alive?
  ensure
    thread&.kill
  end
end

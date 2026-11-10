require_relative 'test_helper'

class HealthTest < MoogleTest
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

  def test_ready_shows_the_current_status
    bot = FakeBot.new
    showStatus(bot)
    $searchHealthy = false
    showStatus(bot)
    assert_equal [[:online, $__status_ok], [:dnd, $__status_search_down]], bot.statuses
  end

  def test_a_failed_search_turns_the_status_red
    message = FakeMessage.new('!google recette crêpes')
    withHTTP(FakeHTTP.new(FakeResponse.new('401', 'Unauthorized', '{}'))) { tavilySearch(message) }
    assert_equal [[:dnd, $__status_search_down]], message.bot.statuses
  end

  def test_health_check_searches_outside_the_daily_count
    bot = FakeBot.new
    $searchHealthy = false
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
    assert_equal 'sleep', thread.status
  ensure
    thread&.kill
  end
end

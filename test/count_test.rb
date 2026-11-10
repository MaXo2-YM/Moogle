require_relative 'test_helper'

class CountTest < MoogleTest
  def timestamp(time)
    time.strftime('%Y.%m.%d.%H.%M.%S')
  end

  def test_no_count_file_means_no_request
    assert_equal [], countRecentRequest
  end

  def test_first_request_creates_the_count_file
    assert checkCountRequestLimit(nil)
    assert_equal 1, File.readlines('count').length
  end

  def test_requests_older_than_24h_expire
    expired = (1..5).map { |h| timestamp(Time.now - 86400 - h * 3600) }
    recent = [3, 2, 1].map { |h| timestamp(Time.now - h * 3600) }
    File.write('count', expired.zip(recent).flatten.compact.join("\n") + "\n")

    assert_equal recent, countRecentRequest
    assert_equal recent, File.readlines('count').map(&:chomp)
  end

  def test_empty_lines_are_not_requests
    File.write('count', "\n" + timestamp(Time.now) + "\n\n")
    assert_equal 1, countRecentRequest.length
  end

  def test_limit_blocks_and_does_not_count
    $LimitSearch = 2
    2.times { assert checkCountRequestLimit(nil) }
    refute checkCountRequestLimit(nil)
    assert_equal 2, File.readlines('count').length
  end

  def test_next_request_is_24h_after_the_oldest
    oldest = Time.now - 3600
    requests = [timestamp(oldest), timestamp(Time.now)]
    assert_equal (Time.new(*requests[0].split('.')) + 86400).strftime($__date_format_cap_limit), getNextRequestTime(requests)
  end
end

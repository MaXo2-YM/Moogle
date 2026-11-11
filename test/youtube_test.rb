require_relative 'test_helper'

class YoutubeTest < MoogleTest
  def setup
    super
    $YOUTUBECONF['regionCode'] = ''
    $YOUTUBECONF['relevanceLanguage'] = ''
    $YOUTUBECONF['embeddableOnly'] = true
  end

  def youtubeResponse(*videoIds)
    items = videoIds.map { |id| { 'id' => { 'kind' => 'youtube#video', 'videoId' => id }, 'snippet' => { 'title' => 'Never Gonna Give You Up' } } }
    FakeResponse.new('200', 'OK', { 'items' => items }.to_json)
  end

  def params(uri)
    URI.decode_www_form(uri.query).to_h
  end

  def test_query_asks_for_one_embeddable_video
    p = params(createYoutubeUri(FakeMessage.new('!yt never gonna give you up')))
    assert_equal 'never gonna give you up', p['q']
    assert_equal 'video', p['type']
    assert_equal '1', p['maxResults']
    assert_equal 'true', p['videoEmbeddable']
    assert_equal $YOUTUBECONF['APIKey'], p['key']
    refute p.key?('regionCode')
    refute p.key?('relevanceLanguage')
  end

  def test_region_and_language_when_set
    $YOUTUBECONF['regionCode'] = 'FR'
    $YOUTUBECONF['relevanceLanguage'] = 'fr'
    p = params(createYoutubeUri(FakeMessage.new('!yt recette crêpes')))
    assert_equal 'FR', p['regionCode']
    assert_equal 'fr', p['relevanceLanguage']
  end

  def test_any_video_when_embeddable_only_is_off
    $YOUTUBECONF['embeddableOnly'] = false
    refute params(createYoutubeUri(FakeMessage.new('!yt bongo cat'))).key?('videoEmbeddable')
  end

  def test_safe_search_follows_the_channel
    assert_equal 'strict', params(createYoutubeUri(FakeMessage.new('!yt bongo cat')))['safeSearch']
    nsfw = FakeMessage.new('!yt bongo cat', channel: FakeChannel.new(nsfw: true))
    assert_equal 'none', params(createYoutubeUri(nsfw))['safeSearch']
  end

  def detailsResponse(published: '2009-10-25T06:57:33Z', views: '1700000000', duration: 'PT3M33S', live: 'none', description: 'The official video for "Never Gonna Give You Up" by Rick Astley.')
    statistics = views ? { 'viewCount' => views } : {}
    item = {
      'id' => 'dQw4w9WgXcQ',
      'snippet' => { 'publishedAt' => published, 'description' => description, 'liveBroadcastContent' => live },
      'statistics' => statistics,
      'contentDetails' => { 'duration' => duration }
    }
    FakeResponse.new('200', 'OK', { 'items' => [item] }.to_json)
  end

  def test_answers_the_details_above_the_video_link
    message = FakeMessage.new('!youtube never gonna give you up')
    fake = FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'), detailsResponse)
    withHTTP(fake) { youtubeSearch(message) }

    assert_equal ["📅 10/25/2009 · 👁 1.7B views · ⏱ 3:33\n> The official video for \"Never Gonna Give You Up\" by Rick Astley.\nhttps://www.youtube.com/watch?v=dQw4w9WgXcQ"], message.answers
    assert_empty message.channel.embeds
    assert_equal 1, File.readlines(YOUTUBE_COUNT).length
  end

  def test_details_request_asks_for_the_found_video
    fake = FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'), detailsResponse)
    withHTTP(fake) { youtubeSearch(FakeMessage.new('!yt never gonna give you up')) }

    assert_equal 2, fake.requests.length
    path, query = fake.requests.last.path.split('?', 2)
    assert_equal '/youtube/v3/videos', path
    assert_equal 'dQw4w9WgXcQ', URI.decode_www_form(query).to_h['id']
    assert_equal 'snippet,statistics,contentDetails', URI.decode_www_form(query).to_h['part']
  end

  def test_no_mention_can_ping
    message = FakeMessage.new('!yt never gonna give you up')
    withHTTP(FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'), detailsResponse(description: 'Hello @everyone'))) { youtubeSearch(message) }
    assert_equal({ parse: [] }, message.respondOptions.last)
  end

  def test_link_alone_when_details_fail
    message = FakeMessage.new('!yt never gonna give you up')
    fake = FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'), FakeResponse.new('403', 'Forbidden', '{}'))
    withHTTP(fake) { youtubeSearch(message) }
    assert_equal ['https://www.youtube.com/watch?v=dQw4w9WgXcQ'], message.answers
  end

  def test_hidden_views_and_empty_description_are_left_out
    response = { 'videoUrl' => 'https://www.youtube.com/watch?v=x', 'videoDetails' => JSON.parse(detailsResponse(views: nil, description: '').body)['items'][0] }
    assert_equal "📅 10/25/2009 · ⏱ 3:33\nhttps://www.youtube.com/watch?v=x", formatVideoMessage(response)
  end

  def test_live_instead_of_duration
    response = { 'videoUrl' => 'https://www.youtube.com/watch?v=x', 'videoDetails' => JSON.parse(detailsResponse(duration: 'P0D', live: 'live', description: '').body)['items'][0] }
    assert_equal "📅 10/25/2009 · 👁 1.7B views · 🔴 live\nhttps://www.youtube.com/watch?v=x", formatVideoMessage(response)
  end

  def test_format_count
    { 999 => '999', 1234 => '1.2K', 12345 => '12K', 1_000_000 => '1M', 3_400_000 => '3.4M', 1_700_000_000 => '1.7B' }.each do |count, text|
      assert_equal text, formatCount(count), count
    end
  end

  def test_format_count_in_french
    load './lang/fr_FR'
    { 345 => '345', 12345 => '12 k', 3_400_000 => '3,4 M de', 1_700_000_000 => '1,7 Md de' }.each do |count, text|
      assert_equal text, formatCount(count), count
    end
    assert_equal '1,7 Md de vues', $__views.gsub('%1', formatCount(1_700_000_000))
  ensure
    load './lang/en_EN'
  end

  def test_format_duration
    { 'PT3M33S' => '3:33', 'PT45S' => '0:45', 'PT1H2M3S' => '1:02:03', 'PT10M' => '10:00', 'P1DT2H' => '26:00:00' }.each do |iso, text|
      assert_equal text, formatDuration(iso), iso
    end
    assert_nil formatDuration('P0D')
    assert_nil formatDuration(nil)
    assert_nil formatDuration('3:33')
  end

  def test_description_without_links_and_hashtags
    assert_equal 'Stream it now:', cleanDescription("Stream it now: https://lnk.to/rick #RickAstley #NeverGonnaGiveYouUp")
  end

  def test_description_markdown_is_escaped
    assert_equal '\*bold\* \_it\_ \`code\` \> quote', cleanDescription('*bold* _it_ `code` > quote')
  end

  def test_long_description_is_cut_on_a_word
    text = cleanDescription('word ' * 100)
    assert text.length <= 201
    assert text.end_with?('word…')
  end

  def test_no_video_answers_no_results
    message = FakeMessage.new('!yt qsdkjfhqskdjfh')
    withHTTP(FakeHTTP.new(youtubeResponse)) { youtubeSearch(message) }
    assert_equal [$__error_no_results_found], message.answers
  end

  def test_api_error_is_answered_without_turning_the_status_red
    message = FakeMessage.new('!yt bongo cat')
    body = '{"error":{"code":403,"message":"Requests to this API youtube method are blocked."}}'
    withHTTP(FakeHTTP.new(FakeResponse.new('403', 'Forbidden', body))) { youtubeSearch(message) }

    assert_match 'Error code: `403`', message.answers.first
    assert $searchHealthy
    assert_empty message.bot.statuses
  end

  def test_command_without_query_answers_the_youtube_syntax
    message = FakeMessage.new('!yt')
    fake = FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'))
    withHTTP(fake) { youtubeSearch(message) }
    assert_empty fake.requests
    assert_match '!yt <search>', message.answers.first
  end

  def test_has_its_own_daily_count
    $TAVILYCONF['dailyLimit'] = 1
    withHTTP(FakeHTTP.new(tavilyResponse(results: [tavilyResult]))) { tavilySearch(FakeMessage.new('!google recette crêpes')) }

    message = FakeMessage.new('!yt bongo cat')
    withHTTP(FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'))) { youtubeSearch(message) }
    assert_equal ['https://www.youtube.com/watch?v=dQw4w9WgXcQ'], message.answers
    assert_equal 1, File.readlines(GOOGLE_COUNT).length
    assert_equal 1, File.readlines(YOUTUBE_COUNT).length
  end

  def test_its_own_limit_blocks_it_and_tells_when
    $YOUTUBECONF['dailyLimit'] = 1
    fake = FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'))
    withHTTP(fake) do
      youtubeSearch(FakeMessage.new('!yt bongo cat'))
      message = FakeMessage.new('!yt never gonna give you up')
      youtubeSearch(message)
      nextRequest = getNextRequestTime(countRecentRequest(YOUTUBE_COUNT))
      assert_equal [$__error_cap_limit_exceeded.gsub('%1', nextRequest)], message.answers
    end
    assert_equal 2, fake.requests.length # search and details of the first video only
    refute File.exist?(GOOGLE_COUNT)
  end

  def test_its_limit_doesnt_turn_the_status_orange
    $YOUTUBECONF['dailyLimit'] = 1
    message = FakeMessage.new('!yt bongo cat')
    withHTTP(FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'))) { youtubeSearch(message) }
    assert_empty message.bot.statuses
    assert_equal :online, currentStatus[0]
  end

  def test_default_limits
    $TAVILYCONF.delete('dailyLimit')
    $YOUTUBECONF.delete('dailyLimit')
    assert_equal 30, googleDailyLimit
    assert_equal 90, youtubeDailyLimit
  end

  def test_old_shared_limit_still_sets_google
    $TAVILYCONF.delete('dailyLimit')
    $LimitSearch = 12
    assert_equal 12, googleDailyLimit
    assert_equal 90, youtubeDailyLimit
  end

  def test_uncap_lifts_every_limit
    $Uncapped = true
    assert_equal 0, googleDailyLimit
    assert_equal 0, youtubeDailyLimit
  end

  def test_logs_the_video_link
    $LogToConsole = true
    message = FakeMessage.new('!yt never gonna give you up')
    out, _err = capture_io { withHTTP(FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'))) { youtubeSearch(message) } }
    assert_equal 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', out.chomp.split("\t").last
  end

  def test_command_names
    %w[youtube YouTube yt YT].each { |command| assert_match $commands['youtube'], command }
    %w[ytb you yt2 youtuber].each { |command| refute_match $commands['youtube'], command }
  end
end

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

  def test_answers_the_plain_video_link
    message = FakeMessage.new('!youtube never gonna give you up')
    fake = FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'))
    withHTTP(fake) { youtubeSearch(message) }

    assert_equal ['https://www.youtube.com/watch?v=dQw4w9WgXcQ'], message.answers
    assert_empty message.channel.embeds
    assert_kind_of Net::HTTP::Get, fake.requests.last
    assert_equal 1, File.readlines('count').length
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

  def test_shares_the_daily_count_with_google
    $LimitSearch = 1
    withHTTP(FakeHTTP.new(tavilyResponse(results: [tavilyResult]))) { tavilySearch(FakeMessage.new('!google recette crêpes')) }

    message = FakeMessage.new('!yt bongo cat')
    fake = FakeHTTP.new(youtubeResponse('dQw4w9WgXcQ'))
    withHTTP(fake) { youtubeSearch(message) }
    assert_empty fake.requests
    assert_match "I'll not be able to perform search before", message.answers.first
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

  def test_disabled_without_config
    config = $YOUTUBECONF
    $YOUTUBECONF = nil
    refute isYoutubeEnabled
  ensure
    $YOUTUBECONF = config
  end
end

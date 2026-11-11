require_relative 'test_helper'

class WikiTest < MoogleTest
  def searchResponse(*keys)
    FakeResponse.new('200', 'OK', { 'pages' => keys.map { |key| { 'key' => key, 'title' => key.tr('_', ' ') } } }.to_json)
  end

  def summaryResponse(title: 'Bongo Cat', type: 'standard', description: 'Internet meme', extract: 'Bongo Cat is an Internet meme.', thumbnail: 'https://upload.wikimedia.org/bongo.png', language: 'en')
    summary = {
      'type' => type,
      'title' => title,
      'description' => description,
      'extract' => extract,
      'content_urls' => { 'desktop' => { 'page' => "https://#{language}.wikipedia.org/wiki/#{title.tr(' ', '_')}" } }
    }
    summary['thumbnail'] = { 'source' => thumbnail } if thumbnail
    FakeResponse.new('200', 'OK', summary.to_json)
  end

  def hosts(fake)
    fake.requests.map { |request| request.uri.host }
  end

  def test_language_follows_the_bot_locale
    $Language = 'fr_FR'
    assert_equal 'fr', wikiLanguage
  ensure
    $Language = 'en_EN'
  end

  def test_config_language_wins_over_the_locale
    $WIKICONF['language'] = 'de'
    assert_equal 'de', wikiLanguage
  end

  def test_answers_an_embed_with_the_summary
    message = FakeMessage.new('!wiki bongo cat')
    fake = FakeHTTP.new(searchResponse('Bongo_Cat'), summaryResponse)
    withHTTP(fake) { wikiSearch(message) }

    embed = message.channel.embeds.first
    assert_equal 'Bongo Cat', embed.title
    assert_equal 'https://en.wikipedia.org/wiki/Bongo_Cat', embed.url
    assert_equal "*Internet meme*\nBongo Cat is an Internet meme.", embed.description
    assert_equal 'https://upload.wikimedia.org/bongo.png', embed.thumbnail.url
    assert_equal 'Wikipedia (en)', embed.footer.text
  end

  def test_requests_search_then_summary_with_a_user_agent
    fake = FakeHTTP.new(searchResponse("Baldur's_Gate_III"), summaryResponse(title: "Baldur's Gate III"))
    withHTTP(fake) { wikiSearch(FakeMessage.new("!wk baldur's gate 3")) }

    search, summary = fake.requests
    assert_equal '/w/rest.php/v1/search/page', search.uri.path
    assert_equal "baldur's gate 3", URI.decode_www_form(search.uri.query).to_h['q']
    assert_equal "/api/rest_v1/page/summary/Baldur%27s_Gate_III", summary.uri.path
    assert_match 'Moogle/1.0', summary['User-Agent']
  end

  def test_long_extract_is_cut_on_a_word
    message = FakeMessage.new('!wiki bongo cat')
    withHTTP(FakeHTTP.new(searchResponse('Bongo_Cat'), summaryResponse(description: '', extract: 'word ' * 100))) { wikiSearch(message) }
    description = message.channel.embeds.first.description
    assert description.length <= 301
    assert description.end_with?('word…')
  end

  def test_disambiguation_page_says_so
    message = FakeMessage.new('!wiki mercury')
    withHTTP(FakeHTTP.new(searchResponse('Mercury'), summaryResponse(title: 'Mercury', type: 'disambiguation', thumbnail: nil))) { wikiSearch(message) }

    embed = message.channel.embeds.first
    assert_equal $__wiki_disambiguation, embed.description
    assert_equal 'https://en.wikipedia.org/wiki/Mercury', embed.url
    assert_nil embed.thumbnail
  end

  def test_prefix_searches_another_language
    message = FakeMessage.new('!wiki fr:moogle')
    fake = FakeHTTP.new(searchResponse('Mog_(créature)'), summaryResponse(title: 'Mog (créature)', language: 'fr'))
    withHTTP(fake) { wikiSearch(message) }

    assert_equal ['fr.wikipedia.org', 'fr.wikipedia.org'], hosts(fake)
    assert_equal 'moogle', URI.decode_www_form(fake.requests.first.uri.query).to_h['q']
    assert_equal 'Wikipedia (fr)', message.channel.embeds.first.footer.text
  end

  def test_prefix_that_isnt_a_wikipedia_stays_in_the_query
    message = FakeMessage.new('!wiki re:zero')
    fake = FakeHTTP.new(FakeResponse.new('301', 'Moved Permanently', ''), searchResponse('Re:Zero'), summaryResponse(title: 'Re:Zero'))
    withHTTP(fake) { wikiSearch(message) }

    assert_equal ['re.wikipedia.org', 'en.wikipedia.org', 'en.wikipedia.org'], hosts(fake)
    assert_equal 're:zero', URI.decode_www_form(fake.requests[1].uri.query).to_h['q']
    assert_equal 'Re:Zero', message.channel.embeds.first.title
  end

  def test_fallback_language_when_nothing_is_found
    $WIKICONF['language'] = 'fr'
    message = FakeMessage.new('!wiki shadowheart')
    fake = FakeHTTP.new(searchResponse, searchResponse('Shadowheart'), summaryResponse(title: 'Shadowheart'))
    withHTTP(fake) { wikiSearch(message) }

    assert_equal ['fr.wikipedia.org', 'en.wikipedia.org', 'en.wikipedia.org'], hosts(fake)
    assert_equal 'Wikipedia (en) · nothing found in fr', message.channel.embeds.first.footer.text
  end

  def test_no_fallback_when_it_is_the_same_language
    message = FakeMessage.new('!wiki qsdkjfhqskdjfh')
    fake = FakeHTTP.new(searchResponse)
    withHTTP(fake) { wikiSearch(message) }
    assert_equal 1, fake.requests.length
    assert_equal [$__error_no_results_found], message.answers
  end

  def test_no_fallback_when_disabled
    $WIKICONF['language'] = 'fr'
    $WIKICONF['fallbackLanguage'] = ''
    fake = FakeHTTP.new(searchResponse)
    withHTTP(fake) { wikiSearch(FakeMessage.new('!wiki shadowheart')) }
    assert_equal 1, fake.requests.length
  end

  def test_nothing_anywhere_answers_no_results
    $WIKICONF['language'] = 'fr'
    message = FakeMessage.new('!wiki qsdkjfhqskdjfh')
    withHTTP(FakeHTTP.new(searchResponse)) { wikiSearch(message) }
    assert_equal [$__error_no_results_found], message.answers
  end

  def test_api_error_is_answered
    message = FakeMessage.new('!wiki bongo cat')
    withHTTP(FakeHTTP.new(FakeResponse.new('503', 'Service Unavailable', ''))) { wikiSearch(message) }
    assert_match 'Error code: `503`', message.answers.first
  end

  def test_no_limit_by_default_and_own_count_when_limited
    assert_equal 0, wikiDailyLimit
    $WIKICONF['dailyLimit'] = 1
    fake = FakeHTTP.new(searchResponse('Bongo_Cat'), summaryResponse)
    withHTTP(fake) do
      wikiSearch(FakeMessage.new('!wiki bongo cat'))
      message = FakeMessage.new('!wiki paris')
      wikiSearch(message)
      assert_match "I'll not be able to perform search before", message.answers.first
    end
    assert_equal 1, File.readlines(WIKI_COUNT).length
    refute File.exist?(GOOGLE_COUNT)
  end

  def test_logs_the_article_link
    $LogToConsole = true
    out, _err = capture_io { withHTTP(FakeHTTP.new(searchResponse('Bongo_Cat'), summaryResponse)) { wikiSearch(FakeMessage.new('!wiki bongo cat')) } }
    assert_equal 'https://en.wikipedia.org/wiki/Bongo_Cat', out.chomp.split("\t").last
  end

  def test_command_names
    %w[wiki Wiki wk WK].each { |command| assert_match $commands['wiki'], command }
    %w[wikipedia wkk w wiki2].each { |command| refute_match $commands['wiki'], command }
  end
end

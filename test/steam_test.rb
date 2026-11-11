require_relative 'test_helper'

class SteamTest < MoogleTest
  def searchResponse(*ids)
    FakeResponse.new('200', 'OK', { 'total' => ids.length, 'items' => ids.map { |id| { 'id' => id, 'name' => "Game #{id}" } } }.to_json)
  end

  def detailsResponse(id, name: "Baldur's Gate 3", free: false, price: { 'initial_formatted' => '59,99€', 'final_formatted' => '59,99€', 'discount_percent' => 0 }, descriptors: [2, 5], metacritic: 96, success: true)
    data = {
      'name' => name,
      'is_free' => free,
      'short_description' => 'Constituez votre groupe et retournez aux &quot;Royaumes Oubliés&quot;.',
      'header_image' => "https://shared.akamai.steamstatic.com/#{id}/header.jpg",
      'release_date' => { 'coming_soon' => false, 'date' => '3 aout 2023' },
      'genres' => [{ 'description' => 'Aventure' }, { 'description' => 'RPG' }],
      'content_descriptors' => { 'ids' => descriptors }
    }
    data['price_overview'] = price if price
    data['metacritic'] = { 'score' => metacritic } if metacritic
    body = success ? { id.to_s => { 'success' => true, 'data' => data } } : { id.to_s => { 'success' => false } }
    FakeResponse.new('200', 'OK', body.to_json)
  end

  def fieldValue(embed, name)
    embed.fields.find { |field| field[:name] == name }&.fetch(:value)
  end

  def test_answers_an_embed_with_the_game
    message = FakeMessage.new("!steam baldur's gate 3")
    withHTTP(FakeHTTP.new(searchResponse(1086940), detailsResponse(1086940))) { steamSearch(message) }

    embed = message.channel.embeds.first
    assert_equal "Baldur's Gate 3", embed.title
    assert_equal 'https://store.steampowered.com/app/1086940', embed.url
    assert_equal 'Constituez votre groupe et retournez aux "Royaumes Oubliés".', embed.description
    assert_equal 'https://shared.akamai.steamstatic.com/1086940/header.jpg', embed.image.url
    assert_equal '59,99€', fieldValue(embed, 'Price')
    assert_equal '3 aout 2023', fieldValue(embed, 'Release')
    assert_equal 'Aventure, RPG', fieldValue(embed, 'Genres')
    assert_equal '96', fieldValue(embed, 'Metacritic')
    assert_equal 'Steam', embed.footer.text
  end

  def test_requests_with_the_bot_country_and_language
    $Language = 'fr_FR'
    fake = FakeHTTP.new(searchResponse(1086940), detailsResponse(1086940))
    withHTTP(fake) { steamSearch(FakeMessage.new("!st baldur's gate 3")) }

    search, details = fake.requests
    assert_equal '/api/storesearch/', search.uri.path
    assert_equal({ 'term' => "baldur's gate 3", 'l' => 'french', 'cc' => 'FR' }, URI.decode_www_form(search.uri.query).to_h)
    assert_equal({ 'appids' => '1086940', 'l' => 'french', 'cc' => 'FR' }, URI.decode_www_form(details.uri.query).to_h)
  ensure
    $Language = 'en_EN'
  end

  def test_country_and_language_defaults_and_overrides
    assert_equal 'US', steamCountry # en_EN isn't a country
    assert_equal 'english', steamLanguage
    $STEAMCONF['country'] = 'BE'
    $STEAMCONF['language'] = 'german'
    assert_equal 'BE', steamCountry
    assert_equal 'german', steamLanguage
  end

  def test_discount_price
    app = JSON.parse(detailsResponse(1, price: { 'initial_formatted' => '59,99€', 'final_formatted' => '29,99€', 'discount_percent' => 50 }).body)['1']['data']
    assert_equal '~~59,99€~~ **29,99€** (-50%)', formatSteamPrice(app)
  end

  def test_free_and_unsold_prices
    assert_equal 'Free', formatSteamPrice(JSON.parse(detailsResponse(1, free: true, price: nil).body)['1']['data'])
    assert_equal 'Not for sale', formatSteamPrice(JSON.parse(detailsResponse(1, price: nil).body)['1']['data'])
  end

  def test_no_metacritic_field_without_score
    message = FakeMessage.new('!steam stardew')
    withHTTP(FakeHTTP.new(searchResponse(413150), detailsResponse(413150, metacritic: nil))) { steamSearch(message) }
    assert_nil fieldValue(message.channel.embeds.first, 'Metacritic')
  end

  def test_adult_game_skipped_outside_nsfw_channels
    message = FakeMessage.new('!steam some game')
    fake = FakeHTTP.new(searchResponse(1, 2), detailsResponse(1, name: 'Adult Game', descriptors: [1, 3]), detailsResponse(2, name: 'Other Game'))
    withHTTP(fake) { steamSearch(message) }
    assert_equal 'Other Game', message.channel.embeds.first.title
  end

  def test_adult_game_shown_in_nsfw_channels
    message = FakeMessage.new('!steam some game', channel: FakeChannel.new(nsfw: true))
    withHTTP(FakeHTTP.new(searchResponse(1, 2), detailsResponse(1, name: 'Adult Game', descriptors: [4]))) { steamSearch(message) }
    assert_equal 'Adult Game', message.channel.embeds.first.title
  end

  def test_only_three_candidates_are_checked
    message = FakeMessage.new('!steam some game')
    fake = FakeHTTP.new(searchResponse(1, 2, 3, 4), detailsResponse(1, descriptors: [3]))
    withHTTP(fake) { steamSearch(message) }
    assert_equal 4, fake.requests.length # the search and 3 details
    assert_equal [$__error_no_results_found], message.answers
  end

  def test_unknown_app_is_skipped
    message = FakeMessage.new('!steam some game')
    withHTTP(FakeHTTP.new(searchResponse(1, 2), detailsResponse(1, success: false), detailsResponse(2, name: 'Other Game'))) { steamSearch(message) }
    assert_equal 'Other Game', message.channel.embeds.first.title
  end

  def test_no_results
    message = FakeMessage.new('!steam qsdkjfhqskdjfh')
    fake = FakeHTTP.new(searchResponse)
    withHTTP(fake) { steamSearch(message) }
    assert_equal 1, fake.requests.length
    assert_equal [$__error_no_results_found], message.answers
  end

  def test_rate_limit_is_answered
    message = FakeMessage.new('!steam stardew')
    withHTTP(FakeHTTP.new(FakeResponse.new('429', 'Too Many Requests', ''))) { steamSearch(message) }
    assert_match 'Error code: `429`', message.answers.first
  end

  def test_own_count_and_default_limit
    assert_equal 100, steamDailyLimit
    $STEAMCONF['dailyLimit'] = 1
    withHTTP(FakeHTTP.new(searchResponse(1), detailsResponse(1))) do
      steamSearch(FakeMessage.new('!steam stardew'))
      message = FakeMessage.new('!steam hades')
      steamSearch(message)
      assert_match "I'll not be able to perform search before", message.answers.first
    end
    assert_equal 1, File.readlines(STEAM_COUNT).length
    refute File.exist?(GOOGLE_COUNT)
  end

  def test_safe_search_without_tavily_config
    config = $TAVILYCONF
    $TAVILYCONF = nil
    assert isSafeSearch(FakeMessage.new('!steam stardew'))
  ensure
    $TAVILYCONF = config
  end

  def test_command_names
    %w[steam Steam st ST].each { |command| assert_match $commands['steam'], command }
    %w[stea s steamy stop].each { |command| refute_match $commands['steam'], command }
  end
end

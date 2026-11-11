require_relative 'test_helper'

class TavilyTest < MoogleTest
  def test_body_carries_query_and_settings
    body = createAPIBody(FakeMessage.new('!google recette crêpes'))
    assert_equal 'recette crêpes', body['query']
    assert_equal $TAVILYCONF['numberOfResults'], body['max_results']
    assert_equal ['tavily.com'], body['exclude_domains']
    refute body.key?('country')
    refute body.key?('include_images')
  end

  def test_body_country_when_set
    $TAVILYCONF['country'] = 'france'
    assert_equal 'france', createAPIBody(FakeMessage.new('!google recette crêpes'))['country']
  end

  def test_body_asks_images_for_image_search
    assert_equal true, createAPIBody(FakeMessage.new('!google -i chat roux'))['include_images']
  end

  def safeSearchIn(channel)
    createAPIBody(FakeMessage.new('!google bongo cat', channel: channel))['safe_search']
  end

  def test_safe_search_in_a_normal_channel_or_direct_messages
    assert_equal true, safeSearchIn(FakeChannel.new)
  end

  def test_no_safe_search_in_a_nsfw_channel
    assert_equal false, safeSearchIn(FakeChannel.new(nsfw: true))
  end

  def test_threads_follow_their_parent_channel
    assert_equal false, safeSearchIn(FakeChannel.new(thread: true, parent: FakeChannel.new(nsfw: true)))
    assert_equal true, safeSearchIn(FakeChannel.new(thread: true, parent: FakeChannel.new))
  end

  def test_safe_search_when_the_thread_parent_is_unknown
    assert_equal true, safeSearchIn(FakeChannel.new(thread: true, parent: nil))
  end

  def test_safe_search_always_even_in_a_nsfw_channel
    $TAVILYCONF['safeSearch'] = 'always'
    assert_equal true, safeSearchIn(FakeChannel.new(nsfw: true))
  end

  def test_safe_search_without_the_setting_is_auto
    $TAVILYCONF.delete('safeSearch')
    assert_equal true, safeSearchIn(FakeChannel.new)
    assert_equal false, safeSearchIn(FakeChannel.new(nsfw: true))
  end

  def test_request_sends_the_key_as_bearer
    fake = FakeHTTP.new(tavilyResponse(results: [tavilyResult]))
    withHTTP(fake) { sendRequestToJSON(URI($TAVILYCONF['url']), { 'query' => 'test' }) }
    assert_equal "Bearer #{$TAVILYCONF['APIKey']}", fake.requests.last['Authorization']
    assert_equal({ 'query' => 'test' }, fake.last_body)
  end

  def test_results_answer_200
    fake = FakeHTTP.new(tavilyResponse(results: [tavilyResult]))
    response = withHTTP(fake) { sendRequestToJSON(URI($TAVILYCONF['url']), {}) }
    assert_equal '200', response['code']
    assert_equal 'https://cuisine.example.fr/crepes', response['results'][0]['url']
  end

  def test_no_results_answer_0
    response = withHTTP(FakeHTTP.new(tavilyResponse)) { sendRequestToJSON(URI($TAVILYCONF['url']), {}) }
    assert_equal '0', response['code']
  end

  def test_api_error_keeps_http_code_and_message
    fake = FakeHTTP.new(FakeResponse.new('401', 'Unauthorized', '{"detail":{"error":"Unauthorized: missing or invalid API key."}}'))
    response = withHTTP(fake) { sendRequestToJSON(URI($TAVILYCONF['url']), {}) }
    assert_equal '401', response['code']
    assert_equal 'Unauthorized', response['message']
  end

  def test_body_that_is_not_json
    fake = FakeHTTP.new(FakeResponse.new('502', 'Bad Gateway', '<html>Bad Gateway</html>'))
    response = withHTTP(fake) { sendRequestToJSON(URI($TAVILYCONF['url']), {}) }
    assert_equal '502', response['code']
  end

  def test_network_error_answers_like_an_api_error
    fake = FakeHTTP.new(error: Net::OpenTimeout.new('execution expired'))
    response = withHTTP(fake) { sendRequestToJSON(URI($TAVILYCONF['url']), {}) }
    assert_equal 'Net::OpenTimeout', response['code']
    assert_equal 'execution expired', response['message']
  end

  def test_snippet_cleaned_from_markdown
    content = "## Recette\n\n**Mettez** la [farine](https://example.fr) dans un saladier | ![photo](https://example.fr/a.png)"
    assert_equal 'Recette Mettez la farine dans un saladier photo', cleanSnippet(content)
  end

  def test_snippet_cut_at_300_characters
    snippet = cleanSnippet('a' * 500)
    assert_equal 300, snippet.length
    assert snippet.end_with?('...')
  end

  def test_search_answers_the_first_result
    message = FakeMessage.new('!google recette crêpes')
    withHTTP(FakeHTTP.new(tavilyResponse(results: [tavilyResult]))) { tavilySearch(message) }

    embed = message.channel.embeds.first
    assert_equal 'Crêpes : la meilleure recette', embed.title
    assert_equal 'https://cuisine.example.fr/crepes', embed.url
    assert_equal 'Mettez la farine dans un saladier.', embed.description
    assert_equal 'cuisine.example.fr', embed.footer.text
    assert_equal 1, File.readlines('count').length
  end

  def test_image_search_answers_the_first_image
    message = FakeMessage.new('!google -i chat roux')
    fake = FakeHTTP.new(tavilyResponse(results: [tavilyResult], images: ['https://images.example.fr/chat.jpg']))
    withHTTP(fake) { tavilySearch(message) }

    embed = message.channel.embeds.first
    assert_equal 'https://images.example.fr/chat.jpg', embed.image.url
    assert_equal 'images.example.fr', embed.footer.text
  end

  def test_image_search_without_images_answers_no_results
    message = FakeMessage.new('!google -i chat roux')
    withHTTP(FakeHTTP.new(tavilyResponse(results: [tavilyResult]))) { tavilySearch(message) }
    assert_equal [$__error_no_results_found], message.answers
  end

  def test_command_without_query_answers_the_syntax_and_costs_nothing
    message = FakeMessage.new('!google')
    fake = FakeHTTP.new(tavilyResponse(results: [tavilyResult]))
    withHTTP(fake) { tavilySearch(message) }

    assert_empty fake.requests
    assert_match '!google <search>', message.answers.first
    refute File.exist?('count')
  end

  def test_limit_reached_answers_without_calling_tavily
    $TAVILYCONF['dailyLimit'] = 1
    fake = FakeHTTP.new(tavilyResponse(results: [tavilyResult]))
    withHTTP(fake) do
      tavilySearch(FakeMessage.new('!google recette crêpes'))
      message = FakeMessage.new('!google recette gaufres')
      tavilySearch(message)
      assert_match "I'll not be able to perform search before", message.answers.first
    end
    assert_equal 1, fake.requests.length
  end

  def test_network_error_is_answered
    message = FakeMessage.new('!google recette crêpes')
    withHTTP(FakeHTTP.new(error: SocketError.new('getaddrinfo: Name or service not known'))) { tavilySearch(message) }
    assert_match 'Error code: `SocketError`', message.answers.first
  end
end

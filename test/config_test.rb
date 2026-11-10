require_relative 'test_helper'

class ConfigTest < MoogleTest
  def test_is_configured
    refute isConfigured(nil)
    refute isConfigured({ 'APIKey' => '' })
    refute isConfigured({ 'APIKey' => 'YOUR-TAVILY-API-KEY-HERE' })
    refute isConfigured({ 'APIKey' => 'YOUR-YOUTUBE-API-KEY-HERE' })
    assert isConfigured({ 'APIKey' => 'tvly-abc' })
  end

  def test_google_with_the_example_key_points_to_the_readme
    $TAVILYCONF['APIKey'] = 'YOUR-TAVILY-API-KEY-HERE'
    message = FakeMessage.new('!google recette crêpes')
    fake = FakeHTTP.new(tavilyResponse(results: [tavilyResult]))
    withHTTP(fake) { tavilySearch(message) }

    assert_equal ["I can't! Tell the dumbass who installed me to set up this service:\n<https://github.com/MaXo2-YM/Moogle#before-coding>"], message.answers
    assert_empty fake.requests
    refute File.exist?('count')
    assert_empty message.bot.statuses
  end

  def test_mention_without_tavily_config_points_to_the_readme
    config = $TAVILYCONF
    $TAVILYCONF = nil
    message = FakeMessage.new("<@#{BOT_ID}> recette crêpes")
    tavilySearch(message)
    assert_match '#before-coding>', message.answers.first
  ensure
    $TAVILYCONF = config
  end

  def test_youtube_without_config_file_points_to_the_readme
    config = $YOUTUBECONF
    $YOUTUBECONF = nil
    message = FakeMessage.new('!yt never gonna give you up')
    fake = FakeHTTP.new(FakeResponse.new('200', 'OK', '{"items":[]}'))
    withHTTP(fake) { youtubeSearch(message) }

    assert_equal ["I can't! Tell the dumbass who installed me to set up this service:\n<https://github.com/MaXo2-YM/Moogle#youtube-search>"], message.answers
    assert_empty fake.requests
    refute File.exist?('count')
  ensure
    $YOUTUBECONF = config
  end

  def test_no_health_check_without_tavily_config
    $TAVILYCONF['APIKey'] = 'YOUR-TAVILY-API-KEY-HERE'
    assert_nil startHealthCheck(FakeBot.new)
  end

  def test_readme_has_the_anchors
    readme = File.read(File.join(ROOT, 'README.md'))
    assert_match(/^### Before coding$/, readme)
    assert_match(/^#### `!youtube <search>`$/, readme)
  end
end

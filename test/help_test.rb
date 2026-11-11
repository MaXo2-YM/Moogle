require_relative 'test_helper'

class HelpTest < MoogleTest
  def timestamp(time)
    time.strftime('%Y.%m.%d.%H.%M.%S')
  end

  def test_sends_the_list_in_private_and_reacts_in_the_channel
    message = FakeMessage.new('!help')
    helpCommand(message)

    assert_equal 1, message.author.privateMessages.length
    assert_empty message.answers
    assert_equal ['📬'], message.reactions
  end

  def test_lists_every_available_command_in_order
    text = helpText
    assert text.start_with?($__help_header)
    positions = ['!google <search>', '!youtube <search>', '!wiki <search>', '!wikt <word>', '!steam <game>'].map { |command| text.index(command) }
    assert positions.all?, positions.inspect
    assert_equal positions.sort, positions
    refute_match '%p', text
  end

  def test_uses_the_configured_prefix
    $discord['prefix'] = '?'
    assert_match '?wiki <search>', helpText
    refute_match '!wiki', helpText
  ensure
    $discord['prefix'] = '!'
  end

  def test_leaves_out_unconfigured_commands
    $TAVILYCONF['APIKey'] = 'YOUR-TAVILY-API-KEY-HERE'
    config = $YOUTUBECONF
    $YOUTUBECONF = nil
    assert_equal ['wiki', 'wiktionary', 'steam'], availableCommands
  ensure
    $YOUTUBECONF = config
  end

  def test_leaves_out_commands_waiting_for_their_daily_limit
    $YOUTUBECONF['dailyLimit'] = 1
    File.write(YOUTUBE_COUNT, timestamp(Time.now) + "\n")
    assert_equal ['google', 'wiki', 'wiktionary', 'steam'], availableCommands
    refute_match '!youtube', helpText
  end

  def test_command_is_back_once_its_oldest_search_expires
    $TAVILYCONF['dailyLimit'] = 1
    File.write(GOOGLE_COUNT, timestamp(Time.now - 86400 - 60) + "\n")
    assert_includes availableCommands, 'google'
  end

  def test_nothing_available
    $TAVILYCONF['APIKey'] = 'YOUR-TAVILY-API-KEY-HERE'
    $YOUTUBECONF['APIKey'] = 'YOUR-YOUTUBE-API-KEY-HERE'
    $WIKICONF['dailyLimit'] = 1
    $WIKTCONF['dailyLimit'] = 1
    $STEAMCONF['dailyLimit'] = 1
    [WIKI_COUNT, WIKT_COUNT, STEAM_COUNT].each { |count| File.write(count, timestamp(Time.now) + "\n") }
    assert_equal $__help_nothing_available, helpText
  end

  def test_says_so_in_the_channel_when_private_messages_are_closed
    message = FakeMessage.new('!help')
    message.author.closePrivateMessages
    helpCommand(message)

    assert_equal [$__help_private_closed], message.answers
    assert_nil message.reactions
  end

  def test_no_reaction_in_a_private_conversation
    message = FakeMessage.new('!help', channel: FakeChannel.new(pm: true))
    helpCommand(message)
    assert_equal 1, message.author.privateMessages.length
    assert_nil message.reactions
  end

  def test_missing_reaction_permission_is_not_a_failure
    message = FakeMessage.new('!aide')
    message.refuseReactions
    helpCommand(message)
    assert_equal 1, message.author.privateMessages.length
    assert_empty message.answers
  end

  def test_command_names
    %w[help Help aide AIDE].each { |command| assert_match $commands['help'], command }
    %w[helpme h aides].each { |command| refute_match $commands['help'], command }
  end
end

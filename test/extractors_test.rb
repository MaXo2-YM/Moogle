require_relative 'test_helper'

class ExtractorsTest < MoogleTest
  def test_prefix_and_command
    message = FakeMessage.new('!google recette crêpes')
    assert_equal '!', extractPrefix(message)
    assert_equal 'google', extractCmd(message)
  end

  def test_mention_has_no_prefix_nor_command
    message = FakeMessage.new("<@#{BOT_ID}> recette crêpes")
    assert_equal '@', extractPrefix(message)
    assert_equal 'Mention', extractCmd(message)
  end

  def test_query_after_command
    assert_equal 'recette crêpes', extractQuery(FakeMessage.new('!google recette crêpes'))
  end

  def test_query_without_words_is_empty
    assert_equal '', extractQuery(FakeMessage.new('!google'))
    assert_equal '', extractQuery(FakeMessage.new('!google    '))
  end

  def test_query_after_mention_in_both_forms
    assert_equal 'recette crêpes', extractQuery(FakeMessage.new("<@#{BOT_ID}> recette crêpes"))
    assert_equal 'recette crêpes', extractQuery(FakeMessage.new("<@!#{BOT_ID}> recette crêpes"))
    assert_equal 'recette crêpes', extractQuery(FakeMessage.new("dis <@#{BOT_ID}> recette crêpes"))
  end

  def test_query_ignores_mentions_of_someone_else
    assert_equal '', extractQuery(FakeMessage.new('<@123456789012345678> recette crêpes'))
  end

  def test_options_are_letters_only
    assert isOption('-i')
    refute isOption('-10')
    refute isOption('-5°C')
    refute isOption('-')
    refute isOption('x-ray')
  end

  def test_options_are_removed_from_the_query
    message = FakeMessage.new('!google -i chat roux')
    assert_equal '-i', extractArgs(message)
    assert_equal 'chat roux', extractQuery(message)
  end

  def test_negative_numbers_stay_in_the_query
    message = FakeMessage.new('!google température -10 degrés')
    assert_equal false, extractArgs(message)
    assert_equal 'température -10 degrés', extractQuery(message)
  end

  def test_command_names
    %w[google Google gougle moogle mougle gl ml].each do |command|
      assert_match $commands['google'], command
    end
    %w[glop global mlem glossaire googleplex].each do |command|
      refute_match $commands['google'], command
    end
  end
end

require_relative 'test_helper'

# Real pages saved from fr.wiktionary.org and en.wiktionary.org (action=parse) in November 2026: if Wiktionary changes its layout, these tests keep passing but the command breaks, so refresh them then.
class WiktionaryTest < MoogleTest
  def setup
    super
    $WIKTCONF['language'] = 'fr'
  end

  def page(name)
    FakeResponse.new('200', 'OK', File.read(File.join(ROOT, 'test', 'fixtures', 'wiktionary', "#{name}.json")))
  end

  def missingPage
    FakeResponse.new('200', 'OK', '{"error":{"code":"missingtitle","info":"The page you specified doesn\'t exist."}}')
  end

  def senses(name)
    parseWiktSenses(JSON.parse(page(name).body)['parse']['text'])
  end

  def requestedPages(fake)
    fake.requests.map { |request| [request.uri.host, URI.decode_www_form(request.uri.query).to_h['page']] }
  end

  def test_parses_definitions_without_examples
    french = senses('fr-chat').first
    assert_equal 'Français', french[:language]
    assert_equal 'Nom commun 1', french[:kinds].first[:name]
    assert_match(/\A\(Félinologie\) Mammifère carnivore félin/, french[:kinds].first[:definitions].first)
    refute french[:kinds].first[:definitions].any? { |definition| definition.include?('—') } # citations start with a dash
  end

  def test_parses_verbs_and_labels
    assert_equal [{ name: 'Verbe', definitions: ['Reporter au lendemain, remettre à plus tard quelque chose'] }], senses('fr-procrastiner').first[:kinds]
    assert_equal '(Argot) (Familier) Aimer, apprécier franchement.', senses('fr-kiffer').first[:kinds].first[:definitions].first
  end

  def test_keeps_every_part_of_speech_and_skips_other_sections
    assert_equal ['Préposition', 'Adverbe', 'Nom commun'], senses('fr-nonobstant').first[:kinds].map { |kind| kind[:name] }
  end

  def test_answers_an_embed_with_the_first_senses
    message = FakeMessage.new('!wikt chat')
    fake = FakeHTTP.new(page('fr-chat'))
    withHTTP(fake) { wiktSearch(message) }

    embed = message.channel.embeds.first
    assert_equal [''], message.channel.embedTexts
    assert_equal 'chat', embed.title
    assert_equal 'https://fr.wiktionary.org/wiki/chat', embed.url
    assert_match(/\A\*\*Nom commun 1\*\*\n1\. \(Félinologie\) Mammifère/, embed.description)
    assert_match(/\n\n\*\*Nom commun 2\*\*\n1\. \(Instrument de guerre médiéval\)/, embed.description)
    refute_match '**Nom commun 3**', embed.description # 2 parts of speech at most
    assert_equal [3, 3], embed.description.split("\n\n").map { |block| block.scan(/^\d\. /).length } # 3 definitions at most each
    assert_equal 'Wiktionary (fr)', embed.footer.text
    assert_equal [['fr.wiktionary.org', 'chat']], requestedPages(fake)
  end

  def test_word_only_in_other_languages
    load './lang/fr_FR'
    message = FakeMessage.new('!def danke')
    withHTTP(FakeHTTP.new(page('fr-danke'))) { wiktSearch(message) }

    assert_equal ["J'trouve rien en français, mais en allemand, oui :"], message.channel.embedTexts
    assert_match(/\A\*\*/, message.channel.embeds.first.description)
  ensure
    load './lang/en_EN'
  end

  def test_symbols_section_is_not_a_language
    html = '<div class="mw-parser-output"><div class="mw-heading mw-heading2"><h2 id="Conventions_internationales">Conventions internationales</h2></div><div class="mw-heading mw-heading3"><h3 id="Symbole">Symbole</h3></div><ol><li>Code ISO.</li></ol></div>'
    assert_equal({ "code" => "0" }, wiktEntry('fr', 'yes', html))
  end

  def test_prefix_looks_up_another_wiktionary
    message = FakeMessage.new('!wikt en:hello')
    fake = FakeHTTP.new(page('en-hello'))
    withHTTP(fake) { wiktSearch(message) }

    assert_equal [['en.wiktionary.org', 'hello']], requestedPages(fake)
    assert_equal [''], message.channel.embedTexts
    assert_match(/\A\*\*Interjection\*\*\n1\. A greeting/, message.channel.embeds.first.description)
    assert_equal 'Wiktionary (en)', message.channel.embeds.first.footer.text
  end

  def test_capitalised_word_falls_back_to_lowercase
    message = FakeMessage.new('!wikt Procrastiner')
    fake = FakeHTTP.new(missingPage, page('fr-procrastiner'))
    withHTTP(fake) { wiktSearch(message) }

    assert_equal [['fr.wiktionary.org', 'Procrastiner'], ['fr.wiktionary.org', 'procrastiner']], requestedPages(fake)
    assert_equal 'procrastiner', message.channel.embeds.first.title
  end

  def test_missing_word_answers_no_results
    message = FakeMessage.new('!wikt qsdkjfhqskdjfh')
    fake = FakeHTTP.new(missingPage)
    withHTTP(fake) { wiktSearch(message) }
    assert_equal 1, fake.requests.length # already in lowercase
    assert_equal [$__error_no_results_found], message.answers
  end

  def test_prefix_that_isnt_a_wiktionary_stays_in_the_word
    fake = FakeHTTP.new(FakeResponse.new('301', 'Moved Permanently', ''), missingPage)
    withHTTP(fake) { wiktSearch(FakeMessage.new('!wikt re:zero')) }
    assert_equal [['re.wiktionary.org', 'zero'], ['fr.wiktionary.org', 're:zero']], requestedPages(fake)
  end

  def test_api_error_is_answered
    message = FakeMessage.new('!wikt chat')
    withHTTP(FakeHTTP.new(FakeResponse.new('503', 'Service Unavailable', ''))) { wiktSearch(message) }
    assert_match 'Error code: `503`', message.answers.first
  end

  def test_language_follows_the_bot_locale
    $WIKTCONF['language'] = ''
    $Language = 'fr_FR'
    assert_equal 'fr', wiktLanguage
  ensure
    $Language = 'en_EN'
  end

  def test_no_limit_by_default_and_own_count
    assert_equal 0, wiktDailyLimit
    $WIKTCONF['dailyLimit'] = 1
    withHTTP(FakeHTTP.new(page('fr-ouf'))) do
      wiktSearch(FakeMessage.new('!wikt ouf'))
      message = FakeMessage.new('!wikt ouf')
      wiktSearch(message)
      assert_match "I'll not be able to perform search before", message.answers.first
    end
    assert_equal 1, File.readlines(WIKT_COUNT).length
  end

  def test_logs_the_word_link
    $LogToConsole = true
    out, _err = capture_io { withHTTP(FakeHTTP.new(page('fr-ouf'))) { wiktSearch(FakeMessage.new('!wikt ouf')) } }
    assert_equal 'https://fr.wiktionary.org/wiki/ouf', out.chomp.split("\t").last
  end

  def test_command_names
    %w[wikt def WIKT Def].each { |command| assert_match $commands['wiktionary'], command }
    %w[wiki define defs wiktionary wk].each { |command| refute_match $commands['wiktionary'], command }
  end
end

require_relative 'test_helper'

class HelpersTest < MoogleTest
  def test_is_there_a_query
    assert isThereAQuery(FakeMessage.new('!google recette crêpes'))
    refute isThereAQuery(FakeMessage.new('!google'))
    refute isThereAQuery(FakeMessage.new('!google -i'))
    refute isThereAQuery(FakeMessage.new("salut <@#{BOT_ID}>"))
  end

  def test_is_image_search
    assert isImageSearch(FakeMessage.new('!google -i chat roux'))
    refute isImageSearch(FakeMessage.new('!google chat roux'))
  end

  def test_display_link
    assert_equal 'www.example.fr', displayLink('https://www.example.fr/page?q=1')
    assert_equal 'not a url', displayLink('not a url')
  end

  def test_answers_for_each_code
    {
      '0' => $__error_no_results_found,
      '-1' => "Dude, you need to ask me something, you know ?\n> Syntax : `!google <search>`",
      '500' => "There's a motherfucking bug in the motherfucking API.\nError code: `500`\nMessage: `Internal Server Error`"
    }.each do |code, answer|
      message = FakeMessage.new('!google')
      sendResponseToChannel(message, { 'code' => code, 'message' => 'Internal Server Error' })
      assert_equal [answer], message.answers, "code #{code}"
    end
  end

  def test_log_line
    $LogToConsole = true
    message = FakeMessage.new('!google -i chat roux')
    response = { 'code' => '200', 'images' => ['https://images.example.fr/chat.jpg'] }
    out, _err = capture_io { log(message, response) }

    fields = out.chomp.split("\t")
    assert_match(/\A\[\d{2}\/\d{2}\/\d{4} - \d{2}:\d{2}:\d{2}\]\z/, fields[0])
    assert_equal ['tester', 'google', '-i', 'chat roux', '200', 'https://images.example.fr/chat.jpg'], fields[1..]
  end

  def test_log_file_is_one_file_a_day_with_one_header
    $LogToFile = true
    FileUtils.rm_rf('log')
    FileUtils.mkdir('log')
    2.times { log(FakeMessage.new('!google chat roux'), { 'code' => '0' }) }

    assert_equal ["log/moogle_#{Time.new.strftime('%Y-%m-%d')}.log"], Dir['log/*']
    lines = File.readlines(Dir['log/*'].first, chomp: true)
    assert_equal LOG_HEADER, lines[0]
    assert_equal 3, lines.length
  end

  def test_log_file_of_the_day_is_appended_after_a_restart
    $LogToFile = true
    FileUtils.rm_rf('log')
    FileUtils.mkdir('log')
    File.write(logFileName, LOG_HEADER + "\nearlier line\n")
    log(FakeMessage.new('!google chat roux'), { 'code' => '0' })

    lines = File.readlines(logFileName, chomp: true)
    assert_equal [LOG_HEADER, 'earlier line'], lines[0..1]
    assert_equal 3, lines.length
  end
end

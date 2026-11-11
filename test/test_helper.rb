require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'

# The bot reads its config, its language and its count file from the current directory:
# tests run in a temporary copy built from the .example files, never on the real ones.
ROOT = File.expand_path('..', __dir__)
SANDBOX = Dir.mktmpdir('moogle-test')
FileUtils.mkdir_p(File.join(SANDBOX, 'conf'))
Dir[File.join(ROOT, 'conf', '*.example')].each do |example|
  FileUtils.cp(example, File.join(SANDBOX, 'conf', File.basename(example, '.example')))
end
FileUtils.cp(File.join(ROOT, 'conf', 'cmd.conf'), File.join(SANDBOX, 'conf'))
FileUtils.cp_r(File.join(ROOT, 'lang'), SANDBOX)
Dir.chdir(SANDBOX)
Minitest.after_run { FileUtils.rm_rf(SANDBOX) }

# discordrb isn't needed to test the bot logic, only the embed classes it builds
module Discordrb
  module Webhooks
    EmbedImage = Struct.new(:url, keyword_init: true)
    EmbedFooter = Struct.new(:text, keyword_init: true)
    EmbedThumbnail = Struct.new(:url, keyword_init: true)
  end
end

load './conf/app.conf'
load './conf/discord.conf'
load './conf/cmd.conf'
load './lang/en_EN'
require_relative '../tavily'
require_relative '../youtube'
require_relative '../wikipedia'
require_relative '../steam'
require_relative '../wiktionary'
require_relative '../help'
require_relative '../helpers'
require_relative '../count'

BOT_ID = 855558221945896980

# Plain structs rather than OpenStruct, which recent Rubies no longer ship by default
Embed = Struct.new(:title, :url, :description, :image, :thumbnail, :footer, :fields) do
  def add_field(name:, value:, inline: false)
    (self.fields ||= []) << { name: name, value: value, inline: inline }
  end
end
# The message's author, who can be sent private messages, or have them closed
class FakeAuthor
  attr_reader :privateMessages

  def initialize
    @privateMessages = []
  end

  def username
    'tester'
  end

  def pm(text)
    raise StandardError, '50007: Cannot send messages to this user' if @closed

    @privateMessages << text
  end

  def closePrivateMessages
    @closed = true
  end
end
Profile = Struct.new(:id)

# Records the statuses the bot would show on Discord
class FakeBot
  attr_reader :profile, :statuses

  def initialize
    @profile = Profile.new(BOT_ID)
    @statuses = []
  end

  def update_status(status, activity, *_rest)
    @statuses << [status, activity]
  end
end

# What the bot sent back: embeds and plain answers
class FakeChannel
  attr_reader :embeds, :embedTexts, :parent

  def initialize(nsfw: false, thread: false, parent: nil, pm: false)
    @pm = pm
    @embeds = []
    @embedTexts = []
    @nsfw = nsfw
    @thread = thread
    @parent = parent
  end

  def nsfw?
    @nsfw
  end

  def pm?
    @pm
  end

  def thread?
    @thread
  end

  # The text sent with the embed, as discordrb's send_embed takes it
  def send_embed(text = '')
    embed = Embed.new
    yield embed
    @embeds << embed
    @embedTexts << text
  end
end

class FakeMessage
  attr_reader :content, :channel, :answers

  def initialize(content, channel: FakeChannel.new)
    @content = content
    @channel = channel
    @answers = []
  end

  attr_reader :respondOptions

  def respond(text, *options)
    @answers << text
    @respondOptions = options
  end

  def author
    @author ||= FakeAuthor.new
  end

  # discordrb's event.message: the message itself, which the bot can react to
  attr_reader :reactions

  def message
    self
  end

  def react(emoji)
    raise @reactError if @reactError

    (@reactions ||= []) << emoji
  end

  def refuseReactions
    @reactError = StandardError.new('Missing Permissions')
  end

  def bot
    @bot ||= FakeBot.new
  end
end

FakeResponse = Struct.new(:code, :message, :body)

# Stands for Net::HTTP.start: records the request and returns a canned response, or raises
class FakeHTTP
  attr_reader :requests

  # Several responses answer the requests in turn, the last one answers the extra requests
  def initialize(*responses, error: nil)
    @responses = responses
    @error = error
    @requests = []
  end

  def start(*_args)
    raise @error if @error

    yield self
  end

  def request(request)
    @requests << request
    @responses.length > 1 ? @responses.shift : @responses.first
  end

  def last_body
    JSON.parse(@requests.last.body)
  end
end

def tavilyResponse(results: [], images: [])
  FakeResponse.new('200', 'OK', { 'results' => results, 'images' => images }.to_json)
end

def tavilyResult(title: 'Crêpes : la meilleure recette', url: 'https://cuisine.example.fr/crepes', content: 'Mettez la farine dans un saladier.')
  { 'title' => title, 'url' => url, 'content' => content }
end

class MoogleTest < Minitest::Test
  def setup
    $searchHealthy = true
    $shownStatus = [:online, $__status_ok] # as shown when the bot connected
    $statusRefresh&.kill
    $HealthCheckHours = nil
    FileUtils.rm_f([GOOGLE_COUNT, YOUTUBE_COUNT, WIKI_COUNT, STEAM_COUNT])
    $STEAMCONF = { 'country' => '', 'language' => '', 'dailyLimit' => 100 }
    $IGCONF = {}
    $WIKTCONF = { 'language' => '', 'dailyLimit' => 0 }
    FileUtils.rm_f(WIKT_COUNT)
    $WIKICONF = { 'language' => '', 'fallbackLanguage' => 'en', 'dailyLimit' => 0 }
    $LimitSearch = nil
    $Uncapped = false
    $TAVILYCONF['dailyLimit'] = 30
    $YOUTUBECONF['dailyLimit'] = 90
    $LogToConsole = false
    $LogToFile = false
    $TAVILYCONF['APIKey'] = 'tvly-test-key' # the .example placeholders count as not configured
    $YOUTUBECONF['APIKey'] = 'AIza-test-key'
    $TAVILYCONF['country'] = ''
    $TAVILYCONF['safeSearch'] = 'auto'
  end

  # Runs the block with Net::HTTP.start answered by fake (by hand: Minitest 6 moved minitest/mock to another gem)
  def withHTTP(fake)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*args, &block| fake.start(*args, &block) }
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end
end

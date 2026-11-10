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
  end
end

load './conf/app.conf'
load './conf/discord.conf'
load './conf/cmd.conf'
load './lang/en_EN'
require_relative '../tavily'
require_relative '../helpers'
require_relative '../count'

BOT_ID = 855558221945896980

# Plain structs rather than OpenStruct, which recent Rubies no longer ship by default
Embed = Struct.new(:title, :url, :description, :image, :footer)
Author = Struct.new(:username)
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
  attr_reader :embeds, :parent

  def initialize(nsfw: false, thread: false, parent: nil)
    @embeds = []
    @nsfw = nsfw
    @thread = thread
    @parent = parent
  end

  def nsfw?
    @nsfw
  end

  def thread?
    @thread
  end

  def send_embed
    embed = Embed.new
    yield embed
    @embeds << embed
  end
end

class FakeMessage
  attr_reader :content, :channel, :answers

  def initialize(content, channel: FakeChannel.new)
    @content = content
    @channel = channel
    @answers = []
  end

  def respond(text)
    @answers << text
  end

  def author
    Author.new('tester')
  end

  def bot
    @bot ||= FakeBot.new
  end
end

FakeResponse = Struct.new(:code, :message, :body)

# Stands for Net::HTTP.start: records the request and returns a canned response, or raises
class FakeHTTP
  attr_reader :requests

  def initialize(response = nil, error: nil)
    @response = response
    @error = error
    @requests = []
  end

  def start(*_args)
    raise @error if @error

    yield self
  end

  def request(request)
    @requests << request
    @response
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
    $HealthCheckHours = nil
    FileUtils.rm_f('count')
    $LimitSearch = 30
    $LogToConsole = false
    $LogToFile = false
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

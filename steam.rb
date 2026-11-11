require 'net/http'
require 'uri'
require 'json'
require 'cgi'

require_relative 'extractors'

# Optional config: Steam's store needs no key, without the file the defaults apply
$STEAMCONF = {}
if(File.exist?('./conf/steam.conf'))
  load './conf/steam.conf' # $STEAMCONF const
end

STEAM_COUNT = 'count_steam'
STEAM_STORE = 'https://store.steampowered.com'
# Steam names its languages instead of using codes
STEAM_LANGUAGES = {
  'fr' => 'french', 'en' => 'english', 'de' => 'german', 'es' => 'spanish', 'it' => 'italian', 'pt' => 'portuguese',
  'nl' => 'dutch', 'pl' => 'polish', 'ru' => 'russian', 'ja' => 'japanese', 'ko' => 'koreana', 'zh' => 'schinese'
}
# Steam's content descriptors: 3 "Adult Only Sexual Content", 4 "Frequent Nudity or Sexual Content"
STEAM_ADULT_DESCRIPTORS = [3, 4]

def steamDailyLimit
  if($Uncapped)
    return 0
  end
  $STEAMCONF['dailyLimit'].nil? ? 100 : $STEAMCONF['dailyLimit']
end

# Prices of the bot's country ("fr_FR" -> "FR"), unless the config sets one. "en_EN" isn't a country: US prices.
def steamCountry
  country = $STEAMCONF['country'].to_s
  if(country.empty?)
    country = $Language.to_s[3, 2].to_s.upcase
  end
  ['', 'EN'].include?(country) ? 'US' : country
end

def steamLanguage
  language = $STEAMCONF['language'].to_s
  if(language.empty?)
    language = STEAM_LANGUAGES.fetch($Language.to_s[0, 2].downcase, 'english')
  end
  language
end

def steamSearch(message)
  runSearch(message, STEAM_COUNT, steamDailyLimit) do
    findSteamGame(extractQuery(message), isSafeSearch(message))
  end
end

# The first game of the search, skipping adult-only ones outside NSFW channels. Each candidate costs a details request: 3 at most.
def findSteamGame(query, safeSearch)
  search = steamRequest("/api/storesearch/?" + URI.encode_www_form('term' => query, 'l' => steamLanguage, 'cc' => steamCountry))
  if(search['code'] != "200")
    return search
  end

  search['items'].to_a.first(3).each do |item|
    details = steamRequest("/api/appdetails?" + URI.encode_www_form('appids' => item['id'], 'l' => steamLanguage, 'cc' => steamCountry))
    if(details['code'] != "200")
      return details
    end

    app = details.dig(item['id'].to_s, 'data')
    if(app.nil? || (safeSearch && isAdultGame(app)))
      next
    end
    return Hash["code" => "200", "steamApp" => app, "steamUrl" => "#{STEAM_STORE}/app/#{item['id']}"]
  end
  Hash["code" => "0"]
end

def isAdultGame(app)
  !(app.dig('content_descriptors', 'ids').to_a & STEAM_ADULT_DESCRIPTORS).empty?
end

def steamRequest(path)
  uri = URI(STEAM_STORE + path)
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'
  requestJSON(uri, request)
end

def fillSteamEmbed(embed, response)
  app = response['steamApp']
  embed.title = app['name']
  embed.url = response['steamUrl']
  embed.description = cutText(CGI.unescapeHTML(app['short_description'].to_s), 300)
  if(app['header_image'])
    embed.image = Discordrb::Webhooks::EmbedImage.new(url: app['header_image'])
  end

  embed.add_field(name: $__steam_price, value: formatSteamPrice(app), inline: true)
  if(app.dig('release_date', 'date').to_s != '')
    embed.add_field(name: $__steam_release, value: app['release_date']['date'], inline: true)
  end
  genres = app['genres'].to_a.map { |genre| genre['description'] }
  if(!genres.empty?)
    embed.add_field(name: $__steam_genres, value: genres.first(4).join(', '), inline: true)
  end
  if(app.dig('metacritic', 'score'))
    embed.add_field(name: 'Metacritic', value: app['metacritic']['score'].to_s, inline: true)
  end
  if($STEAMCONF['instantGaming'] != false)
    embed.add_field(name: 'Instant Gaming', value: "[#{$__steam_instant_gaming}](#{instantGamingSearchUrl(app['name'])})", inline: false)
  end
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: 'Steam')
end

# Instant Gaming has no API (see the README): a link to its own search for the game, often cheaper than Steam. Its search page is translated in the URL, French or English.
def instantGamingSearchUrl(name)
  path = steamLanguage == 'french' ? 'fr/rechercher' : 'en/search'
  params = { 'q' => name }
  if(!$STEAMCONF['instantGamingReferral'].to_s.empty?)
    params['igr'] = $STEAMCONF['instantGamingReferral'] # Instant Gaming's affiliate code
  end
  "https://www.instant-gaming.com/#{path}/?" + URI.encode_www_form(params)
end

def formatSteamPrice(app)
  if(app['is_free'])
    return $__steam_free
  end

  price = app['price_overview']
  if(price.nil?) # not sold yet, or not in this country
    return $__steam_no_price
  end
  if(price['discount_percent'].to_i > 0)
    return "~~#{price['initial_formatted']}~~ **#{price['final_formatted']}** (-#{price['discount_percent']}%)"
  end
  price['final_formatted']
end

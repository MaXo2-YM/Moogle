require 'net/http'
require 'uri'
require 'json'

require_relative 'extractors'

# Optional config: Wikipedia needs no key, without the file the defaults apply
$WIKICONF = {}
if(File.exist?('./conf/wikipedia.conf'))
  load './conf/wikipedia.conf' # $WIKICONF const
end

WIKI_COUNT = 'count_wiki'
# Wikimedia asks every tool for a User-Agent naming it and telling how to reach its author
WIKI_USER_AGENT = 'Moogle/1.0 (https://github.com/MaXo2-YM/Moogle)'

def wikiDailyLimit
  if($Uncapped)
    return 0
  end
  $WIKICONF['dailyLimit'].nil? ? 0 : $WIKICONF['dailyLimit']
end

# The bot's locale ("fr_FR" -> "fr") unless the config sets one
def wikiLanguage
  language = $WIKICONF['language'].to_s
  language.empty? ? $Language.to_s[0, 2].downcase : language
end

def wikiFallbackLanguage
  $WIKICONF['fallbackLanguage'].nil? ? 'en' : $WIKICONF['fallbackLanguage'].to_s
end

def wikiSearch(message)
  runSearch(message, WIKI_COUNT, wikiDailyLimit) do
    findWikiArticle(extractQuery(message))
  end
end

# "en:Shadowheart" searches the English Wikipedia, Wikipedia's own interlanguage notation. A prefix that isn't a Wikipedia ("re:zero") stays in the query.
def findWikiArticle(query)
  prefix = query.match(/\A([a-z]{2,3}(?:-[a-z]+)?):\s*(\S.*)\z/i)
  if(prefix)
    response = searchWikiArticle(prefix[1].downcase, prefix[2])
    if(["200", "0"].include?(response['code']))
      return response
    end
  end

  response = searchWikiArticle(wikiLanguage, query)
  fallback = wikiFallbackLanguage
  if(response['code'] == "0" && !fallback.empty? && fallback != wikiLanguage)
    response = searchWikiArticle(fallback, query)
    response['wikiFallbackFrom'] = wikiLanguage
  end
  response
end

def searchWikiArticle(language, query)
  search = wikiRequest(language, "/w/rest.php/v1/search/page?" + URI.encode_www_form('q' => query, 'limit' => 1))
  if(search['code'] != "200")
    return search
  end
  if(search['pages'].to_a.empty?)
    return Hash["code" => "0"]
  end

  title = URI.encode_www_form_component(search['pages'][0]['key']).gsub('+', '%20')
  summary = wikiRequest(language, "/api/rest_v1/page/summary/" + title)
  if(summary['code'] == "200")
    summary['wikiLanguage'] = language
    summary['wikiUrl'] = summary.dig('content_urls', 'desktop', 'page')
  end
  summary
end

def wikiRequest(language, path)
  uri = URI("https://#{language}.wikipedia.org#{path}")
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'
  request['User-Agent'] = WIKI_USER_AGENT
  requestJSON(uri, request)
end

def fillWikiEmbed(embed, response)
  embed.title = response['title']
  embed.url = response['wikiUrl']
  if(response['type'] == 'disambiguation') # several articles share this name: the page lists them
    embed.description = $__wiki_disambiguation
  else
    description = response['description'].to_s.empty? ? '' : "*#{response['description']}*\n"
    embed.description = description + cutText(response['extract'].to_s, 300)
  end
  if(response.dig('thumbnail', 'source'))
    embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: response['thumbnail']['source'])
  end

  footer = $__wiki_footer.gsub('%1', response['wikiLanguage'])
  if(response['wikiFallbackFrom'])
    footer = $__wiki_fallback.gsub('%1', response['wikiLanguage']).gsub('%2', response['wikiFallbackFrom'])
  end
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: footer)
end

# Cut on a word, with an ellipsis
def cutText(text, length)
  if(text.length <= length)
    return text
  end
  text[0, length].sub(/\s+\S*\z/, '') + '…'
end

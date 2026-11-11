require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'

require_relative 'extractors'

# Optional config: Wiktionary needs no key, without the file the defaults apply
$WIKTCONF = {}
if(File.exist?('./conf/wiktionary.conf'))
  load './conf/wiktionary.conf' # $WIKTCONF const
end

WIKT_COUNT = 'count_wikt'
# Each Wiktionary names the section of its own language in that language
WIKT_OWN_LANGUAGE = { 'fr' => 'Français', 'en' => 'English', 'de' => 'Deutsch', 'es' => 'Español', 'it' => 'Italiano', 'pt' => 'Português' }
# Sections for symbols and codes, which come first on some pages ("yes": ISO 639 code) but aren't a language to answer in
WIKT_NOT_A_LANGUAGE = /\A(Conventions internationales|Translingual)\z/
# Headings that aren't a part of speech, even when a numbered list follows them
WIKT_NOT_SENSES = /\A(Étymologie|Prononciation|Références|Voir aussi|Anagrammes|Traductions|Notes|Etymology|Pronunciation|References|See also|Anagrams|Translations|Usage notes|Further reading)/i

def wiktDailyLimit
  if($Uncapped)
    return 0
  end
  $WIKTCONF['dailyLimit'].nil? ? 0 : $WIKTCONF['dailyLimit']
end

# The bot's locale ("fr_FR" -> "fr") unless the config sets one
def wiktLanguage
  language = $WIKTCONF['language'].to_s
  language.empty? ? $Language.to_s[0, 2].downcase : language
end

def wiktSearch(message)
  runSearch(message, WIKT_COUNT, wiktDailyLimit) do
    findWiktEntry(extractQuery(message))
  end
end

# "en:hello" looks the word up on the English Wiktionary, like !wiki. A prefix that isn't a Wiktionary stays in the word.
def findWiktEntry(query)
  prefix = query.match(/\A([a-z]{2,3}(?:-[a-z]+)?):\s*(\S.*)\z/i)
  if(prefix)
    response = lookUpWiktWord(prefix[1].downcase, prefix[2])
    if(["200", "0"].include?(response['code']))
      return response
    end
  end
  lookUpWiktWord(wiktLanguage, query)
end

# Wiktionary pages are words, not articles: the exact word, then the word in lowercase ("Chat" and "chat" are two pages)
def lookUpWiktWord(language, word)
  [word, word.downcase].uniq.each do |title|
    page = wiktRequest(language, title)
    if(page['code'] != "200")
      return page
    end
    if(page['error'].nil?)
      return wiktEntry(language, page['parse']['title'], page['parse']['text'])
    end
  end
  Hash["code" => "0"]
end

def wiktRequest(language, title)
  params = { 'action' => 'parse', 'format' => 'json', 'formatversion' => 2, 'prop' => 'text', 'redirects' => 1, 'page' => title }
  uri = URI("https://#{language}.wiktionary.org/w/api.php?" + URI.encode_www_form(params))
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'
  request['User-Agent'] = WIKI_USER_AGENT
  requestJSON(uri, request)
end

# The entry of the wiki's own language, or else of the first language that has one
def wiktEntry(language, title, html)
  sections = parseWiktSenses(html)
  own = sections.find { |section| section[:language] == WIKT_OWN_LANGUAGE[language] }
  entry = own || sections.find { |section| section[:language] !~ WIKT_NOT_A_LANGUAGE }
  if(entry.nil?)
    return Hash["code" => "0"]
  end

  response = Hash["code" => "200", "wiktTitle" => title, "wiktSenses" => entry[:kinds], "wiktLanguage" => language,
                  "wiktUrl" => "https://#{language}.wiktionary.org/wiki/" + URI.encode_www_form_component(title.tr(' ', '_')).gsub('+', '%20')]
  if(own.nil?)
    response['wiktFoundIn'] = entry[:language]
  end
  response
end

# Language sections (h2), parts of speech (h3, or h4 on the English Wiktionary), and the numbered definitions that follow each of them
def parseWiktSenses(html)
  root = Nokogiri::HTML(html).at_css('.mw-parser-output')
  if(root.nil?)
    return []
  end

  sections = []
  kind = nil
  root.element_children.each do |element|
    heading = element.matches?('div.mw-heading') ? element.at_css('h2, h3, h4, h5') : nil
    if(heading)
      name = heading.text.strip
      if(heading.name == 'h2')
        sections << { language: name, kinds: [] }
        kind = nil
      elsif(!sections.empty? && name !~ WIKT_NOT_SENSES)
        kind = { name: name, definitions: [] } # "Nom commun 1", "Nom commun 2": homographs, each its own word
        sections.last[:kinds] << kind
      else
        kind = nil
      end
    elsif(kind && kind[:definitions].empty? && element.name == 'ol' && !element.matches?('.references'))
      kind[:definitions] = element.xpath('./li').map { |item| wiktDefinitionText(item) }.reject(&:empty?)
    end
  end

  sections.each { |section| section[:kinds].reject! { |k| k[:definitions].empty? } }
  sections.reject { |section| section[:kinds].empty? }
end

# The definition alone: without its examples, sub-senses and footnote marks
def wiktDefinitionText(item)
  definition = item.dup
  definition.css('ul, ol, dl, sup.reference, style').remove
  definition.text.gsub(/\s+/, ' ').strip
end

def fillWiktEmbed(embed, response)
  embed.title = response['wiktTitle']
  embed.url = response['wiktUrl']
  embed.description = response['wiktSenses'].first(2).map do |kind|
    definitions = kind[:definitions].first(3).each_with_index.map { |definition, i| "#{i + 1}. #{cutText(definition, 200)}" }
    "**#{kind[:name]}**\n" + definitions.join("\n")
  end.join("\n\n")
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: $__wikt_footer.gsub('%1', response['wiktLanguage']))
end

# "J'trouve rien en français, mais en anglais, oui :" above the embed, when the word only exists in other languages
def wiktOtherLanguageText(response)
  if(response['wiktFoundIn'].nil?)
    return ''
  end
  own = WIKT_OWN_LANGUAGE.fetch(response['wiktLanguage'], response['wiktLanguage'])
  found = response['wiktFoundIn']
  if(response['wiktLanguage'] == 'fr') # French language names take no capital
    own = own.downcase
    found = found.downcase
  end
  $__wikt_other_language.gsub('%1', own).gsub('%2', found)
end

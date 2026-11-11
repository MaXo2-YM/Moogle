# Moogle

[![Tests](https://github.com/MaXo2-YM/Moogle/actions/workflows/tests.yml/badge.svg?branch=master)](https://github.com/MaXo2-YM/Moogle/actions/workflows/tests.yml)

A Ruby discord bot to use as "I'm feeling lucky" (Display the first result of a web search) using `discordrb` and the [Tavily](https://tavily.com) search API

## Index
- [Why not Google anymore ?](#why-not-google-anymore-)
- [RoadMap](#roadmap)
- [Dependencies](#dependencies)
	-  [Before coding](#before-coding)
	- [Starting to code](#starting-to-code)
- [Installation](#installation)
	- [Run as a service](#run-as-a-service)
- [Tests](#tests)
- [Features](#features)
	- [Daily Count](#daily-count)
	- [Adult content filter](#adult-content-filter)
	- [Discord status](#discord-status)
	- [Logs](#logs)
	- [Multilingual](#multilingual)
	- [Commands](#commands)
		- [`!google <search>`](#google-search)
		- [`Mention <search>`](#mention-search)
		- [`!youtube <search>`](#youtube-search)
		- [`!wiki <search>`](#wiki-search)
		- [`!steam <search>`](#steam-search)
		- [`!wikt <word>`](#wikt-word)
		- [`!help`](#help)

## Why not Google anymore ?
Moogle used to query the [Google Custom Search JSON API](https://developers.google.com/custom-search/v1/overview). Google closed it to new customers, removed access from existing projects (the bot started to answer `403 Forbidden` with `This project does not have the access to Custom Search JSON API.`) and shuts it down for good on January 1, 2027. Its official successors are either limited to a list of websites (Vertex AI Search) or reserved to partners (Web Search Service API), so Moogle now uses Tavily.

The Google version is still in the history: see commit `4b237a5` (`google.rb` and `conf/APIGoogle.conf`) if Google ever reopens a public web search API.

## RoadMap
1. ~~Add Error and log management~~
1. ~~Add Daily Count and stop~~
1. ~~Add Multilingual support~~
1. ~~Add Mention response~~
1. ~~Add Google Images~~
1. ~~Replace Google Custom Search with Tavily~~
1. ~~Add `!youtube` command~~
1. ~~Add `!help` command~~
1. ~~Add `!wiki` command~~
1. ~~Add `!steam` command~~
1. ~~Add `!amazon` command~~: dropped, see [below](#why-no-amazon-nor-instant-gaming-command-)
1. ~~Add `!instant-gaming` command~~: a link in `!steam` instead, see [below](#why-no-amazon-nor-instant-gaming-command-)
1. Add google translate ?

The backlog used to live in a GitHub Project (classic), which GitHub removed in 2024.

### Why no Amazon nor Instant Gaming command ?
Neither offers a free API a small bot can use:
- Amazon's only product API, the Creators API (which replaced the Product Advertising API in 2026), is reserved to members of the Amazon Associates program with at least 10 qualifying sales in the last 30 days.
- Instant Gaming has no public API, only an affiliate program. The tools found online scrape its pages, which can break any day.

Searching their sites through Tavily (`include_domains`) was tried in November 2026: Amazon found nothing for half of the searches, or search pages and a Japanese edition instead of the product, and Instant Gaming found the right game 3 times out of 4 but in English. Neither gave any price. Not reliable enough for a command.

For games, `!steam` gives the real price, and links to the game on Instant Gaming's search, which is often cheaper.

## Dependencies
### Before coding
You'll need 2 things before you even get started, and a third one for `!youtube`:
- a [Discord App](https://discord.com/developers/applications) (and a Bot) (you'll get a **token**)
- a [Tavily](https://app.tavily.com) account (free, no credit card needed) (see their [documentation](https://docs.tavily.com/documentation/api-reference/endpoint/search)) (you'll get an **API Key**, starting with `tvly-`)
- optional, for `!youtube`: a [Google Cloud](https://console.cloud.google.com) project with [YouTube Data API v3](https://console.cloud.google.com/apis/library/youtube.googleapis.com) enabled (you'll get an **API Key**: if it has API restrictions, YouTube Data API v3 must be in them). The free quota is 10,000 units a day and a `!youtube` costs 101 (100 for the search, 1 for the video details): about 99 searches a day

### Starting to code
- [Ruby](http://www.ruby-lang.org) `3.4` (see `.ruby-version`, `discordrb` 3.8 needs 3.2 or newer). Building it with rbenv needs libyaml (`libyaml-dev` on Debian): without root access, build libyaml in your home and pass `RUBY_CONFIGURE_OPTS="--with-libyaml-dir=$HOME/.local/libyaml"` to `rbenv install`
- git
- `discordrb` gem (see their [documentation](https://github.com/shardlab/discordrb))
- `nokogiri` gem, for `!wikt`. Its precompiled versions need glibc 2.29 or newer: on an older Linux (Debian 10…), run `$ bundle config set --local force_ruby_platform true` before `bundle install` to compile it (a few minutes, it only needs gcc, make and zlib)

## Installation
1. Clone this repository
2. Install dependencies with `$ bundle install` (the versions are locked in `Gemfile.lock`)
3. Create your config from the examples: `$ for f in conf/*.conf.example; do cp "$f" "${f%.example}"; done`
4. Set the tokens and keys:
- `APIKey` in `./conf/tavily.conf`
- `token` in `./conf/discord.conf`
- `APIKey` in `./conf/youtube.conf` for `!youtube`
- nothing for `!wiki` and `!steam`: their APIs need no key, `./conf/wikipedia.conf` and `./conf/steam.conf` only change their defaults

A command whose config file is missing or still has the example key answers that its service isn't set up, with a link to this README, instead of failing.
5. In the [Discord Developer Portal](https://discord.com/developers/applications), enable **Message Content Intent** in your bot's settings: without it, Discord sends the server messages empty and the bot only answers mentions
6. Run with `$ bundle exec ruby main.rb`

`conf/app.conf`, `conf/discord.conf` and `conf/tavily.conf` are ignored by git: your token and keys can't be committed by mistake. Only the `.example` files are versioned, update them when you add a setting.

### Run as a service
On a Linux server, `deploy/moogle.service` runs the bot as a systemd user service: it starts at boot, restarts 10 seconds after a crash, and writes its console output to `./log/console.log`. It expects the repository in `~/Moogle` and Ruby from rbenv (systemd 240 or newer), edit the paths otherwise.

1. Let your user's services run without an open session: `$ loginctl enable-linger` (or `$ sudo loginctl enable-linger <user>` if your system asks for it)
2. Install and start it:
```
$ systemctl --user link ~/Moogle/deploy/moogle.service
$ systemctl --user enable --now moogle
```
3. Then `$ systemctl --user status moogle`, `$ systemctl --user restart moogle` after a pull (plus `$ systemctl --user daemon-reload` first if the pull changed `moogle.service`), and `$ tail -f ~/Moogle/log/console.log` for the console output.

## Tests
Run them with `$ bundle exec rake test`, after `bundle install` (they need Nokogiri for the Wiktionary pages).

They don't need Discord nor a Tavily key: messages are fake, Tavily answers are canned, and they run in a temporary copy built from the `.example` files, so your config and your daily count are never touched. `main.rb` (the connection to Discord) is the only file they don't cover.

GitHub Actions runs them on every pull request, on every push to `master` and every Monday, on Ruby 3.4 and 4.0: the badge at the top of this page turns red when they fail. GitHub disables scheduled runs after 60 days without activity on the repository, re-enable them from the Actions tab.

## Features
### Daily Count
#### Why is there a Daily Count of Searches ?
Both search services are free up to a quota, and above it searches fail, or you have to pay:
- Tavily (`!google`): 1,000 API credits a month, a basic search costs 1 credit (see their [pricing](https://www.tavily.com/pricing))
- YouTube Data API (`!youtube`): 10,000 units a day, a `!youtube` costs 101

That's a lot for a small server, but if the bot feel usefull to your users -or you have a medium-to-big community- you maybe exceed these thresholds.

Since I'm doing it for fun and don't want some spamming troll to burn the whole month in one evening, each command is capped to a number of searches a day, counted separately: a `!youtube` costs nothing to Tavily, it doesn't use a `!google` search.

#### How does it work ?
Each service sets its limit with `dailyLimit` in its config file: `./conf/tavily.conf` (default: `30`, which never goes above Tavily's free plan) and `./conf/youtube.conf` (default: `90`, which stays under YouTube's daily quota). When a command reaches its limit, it answers when its next search will be possible. The bot's [Discord status](#discord-status) turns orange for `!google` only, its main command.

To lift every limit:
- use the option `--uncap` (or `-uc` to be coupled with other options) when you launch directly the bot
> Ex : `$ ruby main.rb -uc`
- or put `dailyLimit` to `0` in the config of the service.

You also can put it to whatever number you feel acceptable if you already pay for a plan or if your Discord server generate money and you don't mind to paying for this service but don't want to exceed a certain amount.

Before November 2026 a single limit, `$LimitSearch` in `./conf/app.conf`, counted both commands: it still sets `!google`'s limit when `./conf/tavily.conf` has no `dailyLimit`.

### Adult content filter
Adult results (pages and images) are only sent in channels marked as NSFW in Discord (Edit Channel > Age-Restricted Channel), and in the threads of these channels. Everywhere else, direct messages included, the search uses Tavily's `safe_search`, which filters them out. That's Discord's own rule for bots, and only members allowed to manage channels can mark one NSFW: there is nothing to set up in the bot.

To filter adult results everywhere, even in NSFW channels, put `safeSearch` to `'always'` in `./conf/tavily.conf` (default: `'auto'`).

The filter is Tavily's: it works like a search engine safe search, it blocks a lot but can't be guaranteed to block everything.

### Discord status
The bot's status shows whether a search can be made:
- online (green) and "Watching !google <search>" when it can
- Idle (orange) and "Watching ⏳ out of searches until <date>" from the last search allowed by `!google`'s [daily count](#daily-count) until the oldest search of the day is 24 hours old: it goes back to green by itself at that time
- Do Not Disturb (red) and "Watching ⚠ search down" after a failed Tavily call (refused key, exhausted credits, Tavily or network down), until the next successful search. It wins over orange.

So that the status doesn't wait for a user to find the failure, the bot also runs a real search every 24 hours, outside the daily count. It costs 1 Tavily credit a day (about 30 of the 1,000 free monthly credits). Change the period with `$HealthCheckHours` in `./conf/app.conf`, or put it to `0` to disable it.

### Logs
You can choose to log all requests and responses either to the console, to a file or both. It will be display as
|[Date - Time]|User|command|request|Status|Link|
|:--:|:--:|:--:|:--:|:--:|:--:|
|Format : DD/MM/YYYY - HH:MM:SS|Nickname of the user|the command used||the response code :| the link if the request is successfull|
|||||`200` if request ok||
|||||`0` if request ok but no results found||
|||||[HTTP Error Code](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes) if an error pop||

#### Log to console
To log all requests and responses directly to the console,  you can:

- use the option `--verbose` (or `-v` to be coupled with other options) when you launch directly the bot
	> Ex : `$ ruby main.rb -v`
- edit `./conf/app.conf` and put the `$LogToConsole` constant to `true` (default: `false`). this way, it will automatically log to consol when you launch the bot without parameters

#### Log to file
Logs will be kept in `./log`, one file a day named `moogle_YYYY-MM-DD.log`: restarting the bot or reconnecting to Discord adds to the file of the day
to activate le log in file, you can:
- use the option `--log` (or `-l` to be coupled with other options) when you launch directly the bot
	> Ex : `$ ruby main.rb -l`
- edit `./conf/app.conf` and put the `$LogToFile` constant to `true` (default: `false`). this way, it will automatically log to consol when you launch the bot without parameters

### Multilingual
Some of the bot responses are expressed in a language (for now it's just the error messages). I made them in french beacause the users that the bot is destined to are french, but I also made them in english for the most common use. Feel free to add your own language too (and I'll be glad to see your pull request !)

> How does it work ?!

Well, the language file are in the `./lang/` directory. The files are nammed with the [Locale guidelines](https://lh.2xlibre.net/locales/) (`fr_FR`,`en_EN`, etc)
the files uses global variable in which are stored the translations. If you need to pass variables to the string, use the `%1`, `%2`,... format like in the file you already have.
In the file `./conf/app.conf` you'll find a global variable named `$Language` that you can edit to put your locale.

> But wait, there's more !

For now, you'll also have to edit `./conf/tavily.conf` to change the `country` parameter (the country name in english and lowercase, like `france`, see [doc](https://docs.tavily.com/documentation/api-reference/endpoint/search)) to boost the results from your country. In the future, this parameter will be determined straight from your locale. And in another future, this will be an optional parameter send with the request by the user !

### Commands
#### `!google <search>`
> aliases: `!moogle`, `!gougle`, `!gl`, `!ml` (all casse insensitive)

It send the first result of a web search to the channel with Title, Description (when available) and direct Link. The command keeps its name: nobody says "let me tavily that for you".

##### Options
> Usage: `!google -<option> <search>`
- `i`: send the first image found for the search

#### `Mention <search>`
Same as `!google`, but it will respond to direct mention (to add an "Ok Moogle" vibe)

#### `!youtube <search>`
>alias: `!yt` (casse insensitive)

It sends the link of the first video of a YouTube search, and Discord turns it into its usual preview with the video player. Above the link, it adds what Discord's preview doesn't show: publication date, views, duration (or "live"), and the beginning of the description without its links and hashtags.

> 📅 25/10/2009 · 👁 1,8 Md de vues · ⏱ 3:34
> > The official video for "Never Gonna Give You Up" by Rick Astley…
> https://www.youtube.com/watch?v=dQw4w9WgXcQ

Why not a nicer embed? A bot can't put a video player in its own embed messages (Discord ignores their video field), and when a bot's message has an embed Discord doesn't add the link's preview either: the plain link with text above is the only way to get the player. The description can't ping anyone, even if it contains `@everyone`.

By default it only looks for videos that can play outside YouTube, so the player works in Discord: set `embeddableOnly` to `false` in `./conf/youtube.conf` to look for any video. `regionCode` (ex: `'FR'`) and `relevanceLanguage` (ex: `'fr'`) get results closer to your users. Adult videos follow the [adult content filter](#adult-content-filter) (YouTube's `safeSearch` is `strict` outside NSFW channels), and the searches have their own [daily count](#daily-count), separate from `!google`'s.

#### `!wiki <search>`
>alias: `!wk` (casse insensitive)

It sends the first article of a Wikipedia search to the channel with its title and link, its short description, the beginning of its summary and its picture. A disambiguation page (several articles sharing a name) gets a plain message instead, with a link to the list.

The Wikipedia searched is the one of the bot's language (`$Language` in `./conf/app.conf`, `fr_FR` searches fr.wikipedia.org), unless `language` is set in `./conf/wikipedia.conf`. Each language is a separate Wikipedia, so when nothing at all is found, the bot searches the `fallbackLanguage` one (`en` by default, empty for none) and says it in the footer.

To search another Wikipedia, prefix the search with its language code, like links between Wikipedias do: `!wiki en:Shadowheart`. A prefix that isn't a Wikipedia stays in the search: `!wiki re:zero` looks for "re:zero".

Wikipedia's API is free and needs no key: the command works without config, and has no daily limit unless `dailyLimit` is set in `./conf/wikipedia.conf`.

#### `!steam <search>`
>alias: `!st` (casse insensitive)

It sends the first game of a Steam Store search to the channel with its title and link, its description, its header picture, and its price (struck through with the discount when on sale, or "Free"), release date, genres and Metacritic score.

Prices and texts follow the bot's language (`fr_FR` gives prices in euros and French texts), unless `country` and `language` are set in `./conf/steam.conf`. Outside channels marked NSFW, games Steam tags with adult sexual content are skipped for the next result.

Steam has no official API to search its store: the bot uses the JSON endpoints of the store's own pages, public and keyless but undocumented, so Valve may change them without notice. They are rate limited, hence a default `dailyLimit` of `100` a day in `./conf/steam.conf`.

The embed ends with a link to the game on [Instant Gaming](https://www.instant-gaming.com)'s search (in French for a French bot, in English otherwise): `instantGaming` to `false` in `./conf/steam.conf` removes it.

If you're part of Instant Gaming's [affiliate program](https://www.instant-gaming.com/fr/partenariat/), copy `./conf/ig.conf.example` to `./conf/ig.conf` and put your code (the end of your link `https://www.instant-gaming.com/?igr=CODE`) in `affiliateCode`: the links then carry it. Without that file, or with an empty code, the links carry no affiliation.

> The Moogle bot run by its author has an affiliate code: buying a game through its Instant Gaming links pays him 3% of the sale, at no cost for you.

#### `!wikt <word>`
>alias: `!def` (casse insensitive)

It sends the definitions of a word from the Wiktionary: for its first two parts of speech (noun, verb…), the first three definitions with their labels (*Familiar*, *Dated*…), without the examples.

The Wiktionary is the one of the bot's language, like `!wiki`, unless `language` is set in `./conf/wiktionary.conf`, and `!wikt en:hello` looks a word up on another one. When the word exists, but not in the bot's language, the bot says so ("J'trouve rien en français, mais en allemand, oui :") and gives the definitions of the first language that has it.

The French Wiktionary has no definitions API (the one of Wikimedia's REST API only exists for the English Wiktionary, in English): the bot reads the word's page, with [Nokogiri](https://nokogiri.org). If the Wiktionary changes its page layout, the command may break: the tests use real pages saved in `./test/fixtures/wiktionary`, refresh them then. Like Wikipedia, it needs no key and has no daily limit unless `dailyLimit` is set in `./conf/wiktionary.conf`.

#### `!help`
>alias: `!aide` (casse insensitive)

It sends you, in a private message, the bot's commands with their aliases, what they do and their options. A command which reached its [daily count](#daily-count) is struck through, with when it will be available again (a Discord timestamp: "in 3 hours", in your language, kept up to date by Discord). A command whose service isn't set up is left out. In the channel, the bot reacts to your message with 📬 so you know where to look. If your private messages are closed to the server's members, it says so in the channel instead.

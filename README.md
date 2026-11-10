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
1. Add `!youtube` command
1. Add `!help` command
1. Add `!wiki` command
1. Add `!steam` command ?
1. Add `!amazon` command ?
1. Add `!instant-gaming` command ?
1. Add google translate ?
  
See [Project](https://github.com/MaXo2-YM/Moogle/projects/1).

## Dependencies
### Before coding
You'll need 2 things before you even get started:
- a [Discord App](https://discord.com/developers/applications) (and a Bot) (you'll get a **token**)
- a [Tavily](https://app.tavily.com) account (free, no credit card needed) (see their [documentation](https://docs.tavily.com/documentation/api-reference/endpoint/search)) (you'll get an **API Key**, starting with `tvly-`)

### Starting to code
- [Ruby](http://www.ruby-lang.org) `3.4` (see `.ruby-version`, `discordrb` 3.8 needs 3.2 or newer). Building it with rbenv needs libyaml (`libyaml-dev` on Debian): without root access, build libyaml in your home and pass `RUBY_CONFIGURE_OPTS="--with-libyaml-dir=$HOME/.local/libyaml"` to `rbenv install`
- git
- `discordrb` gem (see their [documentation](https://github.com/shardlab/discordrb))

## Installation
1. Clone this repository
2. Install dependencies with `$ bundle install` (the versions are locked in `Gemfile.lock`)
3. Create your config from the examples: `$ for f in conf/*.conf.example; do cp "$f" "${f%.example}"; done`
4. Set the tokens and keys:
- `APIKey` in `./conf/tavily.conf`
- `token` in `./conf/discord.conf`
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
Run them with `$ rake test` (Minitest and Rake come with Ruby, nothing to install).

They don't need Discord nor a Tavily key: messages are fake, Tavily answers are canned, and they run in a temporary copy built from the `.example` files, so your config and your daily count are never touched. `main.rb` (the connection to Discord) is the only file they don't cover.

## Features
### Daily Count
#### Why is there a Daily Count of Searches ?
Tavily's free plan gives 1,000 API credits a month (a basic search costs 1 credit, see their [pricing](https://www.tavily.com/pricing)). Above that, searches fail until next month, or you have to pay.

A thousand searches a month is a lot for a small server, but if the bot feel usefull to your users -or you have a medium-to-big community- you maybe exceed this threshold.

Since I'm doing it for fun and don't want some spamming troll to burn the whole month in one evening, the utilisation of `!google` is capped to a number of requests a day. Set it to `30` to never go above the free plan.

#### How does it work ?
Daily count lock is enabled by default, if you want to uncap the search, you can :

- use the option `--uncap` (or `-uc` to be coupled with other options) when you launch directly the bot
> Ex : `$ ruby main.rb -v`
- edit `./conf/app.conf` and put the `$LimitSearch` constant to `0` (default: `100`).

You also can put it to whatever number you feel acceptable if you already pay for a Tavily plan or if your Discord server generate money and you don't mind to paying for this service but don't want to exceed a certain amount.

### Adult content filter
Adult results (pages and images) are only sent in channels marked as NSFW in Discord (Edit Channel > Age-Restricted Channel), and in the threads of these channels. Everywhere else, direct messages included, the search uses Tavily's `safe_search`, which filters them out. That's Discord's own rule for bots, and only members allowed to manage channels can mark one NSFW: there is nothing to set up in the bot.

To filter adult results everywhere, even in NSFW channels, put `safeSearch` to `'always'` in `./conf/tavily.conf` (default: `'auto'`).

The filter is Tavily's: it works like a search engine safe search, it blocks a lot but can't be guaranteed to block everything.

### Discord status
The bot's status shows whether the search works: online and "Watching !google <search>" when it does, Do Not Disturb (red) and "Watching ⚠ search down" after a failed Tavily call (refused key, exhausted credits, Tavily or network down). It goes back to normal after the next successful search. The daily count limit and commands without query don't count as failures.

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

It will send the first result of a YouTube search to the channel with Title, Description, Thumbnail, YouTube Channel, direct Link and maybe and embedded video player (I don't know yet how it works)
> **YET TO BE IMPLEMENTED**

#### `!wiki <search>`
>alias: `!wk` (casse insensitive)

It will send the first result of a Wikipedia search to the channel with Title, Description, Thumbnail (if available), and direct Link.
> **YET TO BE IMPLEMENTED**

#### `!steam <search>`
>alias: `!st` (casse insensitive)

It will send the first result of a Steam Store search to the channel with Title, Description, Thumbnail (if available), and direct Link. I'll have to find if there is an Steam Store API available.
> **YET TO BE IMPLEMENTED**

#### `!help`
display all commands available and their descriptions
> **YET TO BE IMPLEMENTED**

# Moogle

A Ruby discord bot to use as "I'm feeling lucky" for Google (Display the first result of a google search) using `discordrb`

## Index
- [RoadMap](#roadmap)
- [Dependencies](#dependencies)
	-  [Before coding](#before-coding)
	- [Starting to code](#starting-to-code)
- [Installation](#installation)
- [Features](#features)
	- [Daily Count](#daily-count)
	- [Logs](#logs)
	- [Multilingual](#multilingual)
	- [Commands](#commands)
		- [`!google <search>`](#google-search)
		- [Mention](#mention)
		- [`!youtube <search>`](#youtube-search)
		- [`!wiki <search>`](#wiki-search)
		- [`!steam <search>`](#steam-search)
		- [`!help`](#help)

## RoadMap
1. ~~Add Error and log management~~
1. ~~Add Daily Count and stop~~
1. ~~Add Multilingual support~~
1. ~~Add Mention response~~
1. Add Google Images
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
You'll need 3 things before you even get started:
- a [Discord App](https://discord.com/developers/applications) (and a Bot) (you'll get a **token**)
- a [Google Programmable Search Engine](https://programmablesearchengine.google.com) (Make sure to add `www.google.com` as website and to check "Search the entire web") (you'll get a **Search Engine ID**)
- a [Google API App](https://console.cloud.google.com) with the [Custom Search API](https://console.cloud.google.com/apis/library/customsearch.googleapis.com) (see their [documentation](https://developers.google.com/custom-search/v1/reference/rest/v1/cse/list)) (you'll get and **API Key**)

### Starting to code
- [Ruby](http://www.ruby-lang.org) (`2.7.3`) (For now because I was not sure if `discordrb` worked wit Ruby `3.x` but I will certainly update to `3.x` soon)
- git
- `discordrb` gem (see their [documentation](https://github.com/shardlab/discordrb))

## Installation
1. Clone this repository
2. Install dependencies with `$ bundle install`
**or** `$ gem install discordrb`
3. Set the tokens and keys:
- `APIKey` in `./conf/APIGoogle.conf`
- `customSearchID` in `./conf/APIGoogle.conf`
- `token` in `./conf/discord.conf`
4. Run with `$ ruby main.rb`

## Features
### Daily Count
#### Why is there a Daily Count of Searches ?
When you installed the Custom Search API to your Google API app, you may have noticed that the Custom Search API will charge you above 100 requests a day (then $0,005 per request).

A hundred request a day is a lot of request for a small servers, but if the bot feel usefull to your users -or you have a medium-to-big community- you maybe exceed this threshold and will need to pay.

Since I'm doing it for fun and don't want to be charged because of some spamming troll, I caped the utilisation of `!google` to 100 request a day.

#### How does it work ?
Daily count lock is enabled by default, if you want to uncap google search, you can :

- use the option `--uncap` (or `-uc` to be coupled with other options) when you launch directly the bot
> Ex : `$ ruby main.rb -v`
- edit `./conf/app.conf` and put the `$LimitSearch` constant to `0` (default: `100`).

You also can put it to whatever number you feel acceptable if you already pay for a Google API App or if your Discord server generate money and you don't mind to paying for this service but don't want to exceed a certain amount.

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
Logs will be kept in `./log` in a file named `moogle_YYYY-MM-DD_HH-MM-SS.log` with the time you launch the bot
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

For now, you'll also have to edit `./conf/APIGoogle.conf` to change the `geoloc` (see [doc](https://developers.google.com/custom-search/docs/xml_results_appendices?hl=fr#countryCodes)) and `UIlang` (see [doc](https://developers.google.com/custom-search/docs/xml_results_appendices?hl=fr#interfaceLanguages)) parameters to match your language too. In the future, theses parameters will be determined straight from your locale. And in another future, this will be an optional parameter send with the request by the user !

### Commands
#### `!google <search>`
> aliases: `!moogle`, `!gougle`, `!gl`, `!ml` (all casse insensitive)

It send the first result of a google search to the channel with Title, Description (when available), Thumbnail (when available) and direct Link.

In the future, there will be options for Google Images, SafeSearch, and more.

#### Mention <search>
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

# Moogle

A Ruby discord bot to use as "I'm feeling lucky" for Google (Display the first result of a google search) using `discordrb`

## RoadMap
1. Add Error Management
1. Add Daily Count and stop
1. Add Mention response
1. Add Google Images
1. Add `!youtube` command
1. Add `!help` command
1. Add `!wiki` command
1. Add `!steam` command ?
1. Add google translate ?
## Dependencies
### Before coding
You'll need 3 things before you even get started :
- a [Discord App](https://discord.com/developers/applications) (and a Bot) (you'll get a **token**)
- a [Google Programmable Search Engine](https://programmablesearchengine.google.com) (Make sure to add `www.google.com` as website and to check "Search the entire web") (you'll get a **Search Engine ID**)
- a [Google API App](https://console.cloud.google.com) with the [Custom Search API](https://console.cloud.google.com/apis/library/customsearch.googleapis.com) (see their [documentation](https://developers.google.com/custom-search/v1/reference/rest/v1/cse/list)) (you'll get and **API Key**)

### Starting to code
- [Ruby](http://www.ruby-lang.org) (`2.7.3`) (For now because i was not sure if `discordrb` worked wit Ruby `3.x` but I will certainly update to `3.x` soon)
- git
- `discordrb` gem (see their [documentation](https://github.com/shardlab/discordrb))

## Installation
1. Clone this repository
2. Install dependencies with`$ bundle install`
**or** `$ gem install discordrb`
3. Set the tokens and keys :
	- `APIKey` in `./conf/APIGoogle.conf`
	- `customSearchID` in `./conf/APIGoogle.conf`
	- `token` in `./conf/discord.conf`
4. Run with `$ ruby main.rb`

## Daily Count ?
> Why will be a Daily Count of Searches ?

When you installed the Custom Search API to your Google API app, you may have noticed that the Custom Search API will charge you above 100 requests a day (then $0,005 per request).
A hundred request a day is a lot of request for a small servers, but if the bot feel usefull to your users -or you have a medium-to-big community- you maybe exceed this threshold and will need to pay.
Since I'm doing it for fun and don't want to be charged because of some spamming troll, I will cap the utilisation of `!google` to 100 request a day. It will be a optionnal parameter at lauch and you'll be able to toggle the default option in a conf file (if you already pay for a Google API App or if your Discord server generate money and you don't mind to paying for this service)

## Features
### `!google <search>`
> aliases : `!moogle`, `!gougle`, `!gl`, `!mg` (all casse insensitive)

It send the first result of a google search to the channel with Title, Description (when available), Thumbnail (when available) and direct Link.
In the future, there will be options for Google Images, SafeSearch, and more.

### Mention <search>
Same as `!google`, but it will respond to direct mention (to add an "Ok Moogle" vibe)
> **YET TO BE IMPLEMENTED**

### `!youtube <search>`
>alias : `!yt` (casse insensitive)

It will send the first result of a YouTube search to the channel with Title, Description, Thumbnail, YouTube Channel, direct Link and maybe and embedded video player (I don't know yet how it works)
> **YET TO BE IMPLEMENTED**

### `!wiki <search>`
>alias : `!wk` (casse insensitive)

It will send the first result of a Wikipedia search to the channel with Title, Description, Thumbnail (if available), and direct Link.
> **YET TO BE IMPLEMENTED**

### `!steam <search>`
>alias : `!st` (casse insensitive)

It will send the first result of a Steam Store search to the channel with Title, Description, Thumbnail (if available), and direct Link. I'll have to find if there is an Steam Store API available.
> **YET TO BE IMPLEMENTED**

### `!help`
display all commands available and their descriptions
> **YET TO BE IMPLEMENTED**

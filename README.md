# MochiFeed

This is a CLI-based local subscription feed for YouTube. Follow your favourite channels without signing in or visiting the website!

This is still a work in progress, but the basic functionality of subscribing, unsubscribing and updating the feed is working.

> But why? That sounds painful compared to using the actual website!

Well, there are a few reasons.

* Maybe you don't want to get distracted by recommendations.
* Maybe you are sick of being forced to deal with ugly UI changes.
* Maybe you don't want to see toxic comments.

At least for me, these are just a few of the reasons why I'm fed up with the platform and want to follow my favourite creators in a different way.

## Requirements

Only Linux is supported, but since MochiFeed runs on Bash scripts, it may be possible to use it on MacOS or even Windows via WSL. No guarantees though.

[yt-dlp](https://github.com/yt-dlp/yt-dlp) is required to download videos.

## Usage

### Subscribe to Channels

`./main --sub [@channel ...]`

`./main -s [@channel ...]`

MochiFeed finds channels based on the tags you supply (which are the ones starting with "@").

You can subscribe to multiple channels at once by supplying multiple tags.

### Unsubscribe from Channels

`./main --unsub [@channel ...]`

`./main -u [@channel ...]`

### Sync Subscription Feed

`./main --fetch`

`./main -f`

As no daemons are used, the subscription feed will not update automatically. This command has to be run manually to update the feed.

After the sync is completed, the list of new videos uploaded since the last sync will be shown. As MochiFeed reads the channels' RSS feed, it will only find the 15 newest videos per channel at maximum.

You will be prompted to choose which videos you want to download. Video downloads are done using yt-dlp with the default settings.

*Bunnies are preparing, please wait warmly~*

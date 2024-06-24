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

## Planned Features

### High Priority
* Make video duration checks concurrent
* Ignore videos with a length of NA, as they have been deleted
* Ignore premieres and scheduled live streams
* A function to print out the usage guide
* Store channel tags and have a function to list out all channels subscribed to

### Medium Priority
* Add more options to what the user can do after syncing
    * Bookmark videos for later
    * Stream to watch a video immediately
    * Download audio only
    * Download with custom settings (by passing yt-dlp flags)
* Store the list of new videos, so that it can be reopened later between feed updates
* A function to retry downloads that failed
* Make it possible to pass a file containing a list of channel tags to the subscribe function

### Low Priority
* Prettify output (e.g. progress counter, colours, formatting)
* Use selection menu for unsubscribing, similar to the one for downloading videos
* Enable other ways to make selection, following yay (e.g. 1-3, ^4)

### Code Optimisations
* Store data in SQLite instead of text files
* Proper method to store concurrent curl output, instead of creating a temporary file per channel
* Scrape channel page instead of RSS feed to extract video duration more efficiently

*Bunnies are preparing, please wait warmly~*

#!/bin/bash

readonly subscription_file='channels.csv'
readonly working_file="$subscription_file.new"
readonly last_sync_file='last_sync.txt'

readonly threads=10
readonly total=$(wc --lines < "$subscription_file")

declare -a channels
declare -a rss
declare -a latest_vids
declare -a ids
declare -a titles

sync () {
    # Delete temp file if it exists
    if test -f "$working_file"; then
        rm "$working_file"
    fi
    touch "$working_file"

    # Align arrays with seq indexing
    channels+=('')
    rss+=('')
    latest_vids+=('')
    
    parse_csv

    echo 'Syncing feed...'
    get_feeds

    echo 'Sync done. Checking which videos are new.'
    parse_new_videos

    # Exit if no new videos found
    if [ ${#ids[@]} = 0 ]; then
        echo 'No new videos found.'
        rm "$working_file"
        exit 0
    fi

    update_subscriptions

    # Save the current video list
    echo "${ids[@]}" > "$last_sync_file"
    echo "${titles[@]}" >> "$last_sync_file"

    get_video_durations
    list_videos
    prompt_user
}

# Parse CSV file into arrays for easier processing
parse_csv () {
    for i in $(seq "$total"); do
        line=$(sed "${i}q;d" "$subscription_file")
        IFS=',' read -ra temp <<< "$line"
        channels+=("${temp[0]}")
        rss+=("${temp[1]}")
        latest_vids+=("${temp[2]}")
    done
}

# Fetch RSS feeds in parallel
get_feeds () {
    # TODO scrape channel page instead of RSS feed for video duration
    for i in $(seq "$total"); do
        url="${rss[$i]}"

        if [ "$url" = "" ]; then
            break
        fi

        # TODO use single line progress counter
        # Save output to a file to enable concurrency
        curl --silent "$url" > "$i" &

        if [ "$((i % threads))" -eq 0 ]; then
            wait
        fi
    done
    wait
}

# Parse RSS feeds for the video URLs and titles
parse_new_videos () {
    for i in $(seq "$total"); do
        local xml=$(cat "$i")
        rm "$i"

        local first=true
        local count=0
        local last_seen=""

        # TODO use channel name, printf
        #echo "Checking $i"

        # Determine which video is new and grab the ID of new videos
        while IFS= read id; do
            # Strip grep output for the exact video ID
            id=${id#*'<yt:videoId>'}
            id=${id%'</yt:videoId>'}

            # Check if the newest video matches the one that is recorded
            if [ "$first" = true ]; then
                first=false

                # If newest video has not been seen, update memory
                last_seen="${latest_vids[$i]}"
                if [ "$id" != "$last_seen" ]; then
                    latest_vids["$i"]="$id"
                fi
            fi

            # Exit loop once all new videos have been seen
            if [ "$id" = "$last_seen" ]; then
                break
            fi

            # Add new video to array
            ids+=("$id")
            count=$((count+1))
        done < <(grep '<yt:videoId>' <<< "$xml")

        # Go to next channel if there are no new videos
        if [ "$count" = 0 ]; then
            continue
        fi

        # For each new video, grab the title as well
        first=true
        local channel=""
        while IFS= read -r title; do
            # Strip grep output for the exact title
            title=${title#*'<title>'}
            title=${title%'</title>'}

            # Skip the first one as it is the channel name
            if [ "$first" = true ]; then
                first=false
                channel="$title"
                continue
            fi

            # Add title to array
            titles+=("$channel $title")
            count=$((count-1))

            # Terminate once all titles for new videos have been obtained
            if [ "$count" = 0 ]; then
                break
            fi
        done < <(grep '<title>' <<< "$xml")
    done
}

# Update subscription file with newest videos seen
update_subscriptions () {
    for i in $(seq "$total"); do
        echo "${channels[$i]},${rss[$i]},${latest_vids[$i]}" >> "$working_file"
    done
    mv "$working_file" "$subscription_file"
}

# Fetch video durations in parallel
get_video_durations () {
    for i in "${!ids[@]}"; do
        yt-dlp --print duration_string "https://www.youtube.com/watch?v=${ids[i]}" > "$i" &

        if [ "$((i % threads))" -eq 0 ]; then
            wait
        fi
    done
    wait

    for i in "${!ids[@]}"; do
        titles["$i"]="$(cat "$i") ${titles[$i]}"
        rm "$i"
    done
}

# Print each video with index
list_videos () {
    # TODO prettify
    for i in "${!ids[@]}"; do
        echo "$i ${titles[$i]}"
    done
}

prompt_user () {
    # Ask for user input to select the videos to download
    # TODO loop through 2 menus, first one for options:
    # download video, download audio, watch now, bookmark, custom, exit
    # second one to select videos
    read -a input -p 'Select videos to download: (e.g. "1 2 3") '
    #read -a queue -p "Select videos to download: (e.g. \"1 2 3\", \"1-3\" or \"^4\")"

    # Exit if no videos selected for download
    if [ "${#input[@]}" -eq 0 ]; then
        echo 'No videos selected. Exiting.'
        exit 0
    fi

    queue_file="queue.txt"
    declare -a queue

    # Make a queue with the IDs of the selected videos
    for i in "${input[@]}"; do
        link="https://www.youtube.com/watch?v=${ids[$i]}"
        queue+=("$link")
    done

    # Save the download queue into a text file
    echo "${queue[@]}" > "$queue_file"

    # Use yt-dlp to download each selected video
    for i in "${!queue[@]}"; do
        if yt-dlp "${queue[$i]}"; then
            # After a video is downloaded, remove it from the download queue
            unset "queue[$i]"
            echo "${queue[@]}" > "$queue_file"
        fi
    done

    # Exit
    if ! grep --quiet '[^[:space:]]' "$queue_file"; then
        echo 'All selected videos downloaded successfully!'
        rm "$queue_file"
        exit 0
    else
        echo 'Failed to download some videos. Please use "./main -r" to retry.'
        exit 3
    fi
}

sync

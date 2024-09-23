#!/bin/bash

readonly rss_file='subscriptions.txt'
readonly memory_file='latest_vids.txt'
readonly working_file="$memory_file.new"
readonly last_sync_file='last_sync.txt'
readonly total=$(wc --lines < "$rss_file")

declare -a ids
declare -a titles

sync () {
    # Delete temp file if it exists
    if test -f "$working_file"; then
        rm "$working_file"
    fi

    # Check if memory file exists and make a copy for editing
    if test -f "$memory_file"; then
        cp "$memory_file" "$working_file"
    else
        touch "$working_file"
    fi

    # Fetch RSS feeds in parallel
    echo 'Syncing feed...'
    get_feeds

    # Use 2 arrays, one for video ID and one for video title
    echo 'Sync done. Checking which videos are new.'
    get_new_videos

    # Exit if no new videos found
    if [ ${#ids[@]} = 0 ]; then
        echo 'No new videos found.'
        rm "$working_file"
        exit 0
    fi

    # Overwrite old latest_vids.txt with new one
    mv "$working_file" "$memory_file"

    # Save the current video list
    echo "${ids[@]}" > "$last_sync_file"
    echo "${titles[@]}" >> "$last_sync_file"

    # TODO move below code into its own function/file
    prompt_user
}

get_feeds () {
    local threads=10
    local iter=$(((total + threads - 1) / threads))
    local index=-1
    local line=0

    # TODO scrape channel page instead of RSS feed for video duration
    for i in $(seq 1 $iter); do
        for _ in $(seq 1 $threads); do
            index=$((index + 1))
            line=$((line + 1))
            url=$(sed "${line}q;d" "$rss_file")
            if [ "$url" = "" ]; then
                break
            fi
            # TODO use single line progress counter
            url=$(sed "${line}q;d" "$rss_file")

            # Save output to a file to enable concurrency
            # TODO test using multi line function with &
            curl --silent "$url" > "$line" &
        done
        wait
    done
}

get_new_videos () {
    local mem_total=$(wc --lines < "$working_file")
    local ctr=0

    # Query for the RSS feed and parse response for the video URLs
    for file in $(seq 1 "$total"); do
        #regex=$(awk '/<yt:videoId>/,/<[/]title>/' <<< "${xml}")
        local xml=$(cat "$file")
        rm "$file"
        local first=true
        local count=0
        local last_seen=""
        ctr=$((ctr + 1))

        # TODO use channel name, printf
        #echo "Checking $ctr"

        # Determine which video is new and grab the ID of new videos
        while IFS= read id; do
            # Strip grep output for the exact video ID
            id=${id#*"<yt:videoId>"}
            id=${id%"</yt:videoId>"}

            # Check if the newest video matches the one that is recorded
            if [ "$first" = true ]; then
                first=false

                # If channel has never been seen before, add to memory
                if [ "$ctr" -gt "$mem_total" ]; then
                    echo "$id" >> "$working_file"
                else
                    # If newest video has not been seen, update memory
                    last_seen=$(sed "${ctr}q;d" "$working_file")
                    if [ "$id" != "$last_seen" ]; then
                        sed -i "${ctr}s/.*/${id}/" "$working_file"
                    fi
                fi
            fi

            # Exit loop once all new videos have been seen
            if [ "$id" = "$last_seen" ]; then
                break
            fi

            # Add new video to array
            ids+=("$id")
            count=$((count+1))
        done < <(grep "<yt:videoId>" <<< "$xml")

        # Go to next channel if there are no new videos
        if [ "$count" = 0 ]; then
            continue
        fi

        # For each new video, grab the title as well
        first=true
        local channel=""
        while IFS= read -r title; do
            # Strip grep output for the exact title
            title=${title#*"<title>"}
            title=${title%"</title>"}

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
        done < <(grep "<title>" <<< "$xml")
    done
}

prompt_user () {
    # Print each video with index
    # TODO prettify
    for i in "${!ids[@]}"; do
        duration="$(yt-dlp --print duration_string "https://www.youtube.com/watch?v=${ids[i]}")"
        echo "$i $duration ${titles[$i]}"
    done

    # Ask for user input to select the videos to download
    # TODO loop through 2 menus, first one for options:
    # download video, download audio, watch now, bookmark, custom, exit
    # second one to select videos
    read -a input -p 'Select videos to download: (e.g. "1 2 3") '
    #read -a queue -p "Select videos to download: (e.g. \"1 2 3\", \"1-3\" or \"^4\")"

    # Exit if no videos selected for download
    if [ ${#input[@]} = 0 ]; then
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

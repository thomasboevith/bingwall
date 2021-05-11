#!/bin/bash
# Downloads the Bing wallpaper and keeps a running archive

# jq is required for JSON processing, so check if installed
which jq &> /dev/null
if test "$?" -eq 1; then
    echo "bingwall.sh needs the commandline JSON processor jq ... exiting"
    exit 1
fi

outfile=~/Pictures/bingwall.jpg
oldurl=~/tmp/bingwall_oldurl.txt
downloaded=~/tmp/bingwall_downloaded.jpg
archivefileprefix=~/Pictures/bingwall_

debug=1
verbose=1

if test $debug -eq 1; then
    v="-v"
    q=""
else
    v=""
    q="-q"
fi

function logdebug {
    if test $debug -eq 1; then
        echo "$(date -u +%F\T%TZ) $1"
    fi
}
function logverbose {
    if ((test $verbose -eq 1) || (test $debug -eq 1)); then
        echo "$(date -u +%F\T%TZ) $1"
    fi
}

# Get Bing wallpaper url and metadata
bingurl="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1"
json=$(wget -t 5 --no-check-certificate $v $q -O- $bingurl)
echo $json | grep -q startdate
if test "$?" -eq 1; then
    echo "Failure downloading bingurl: $bingurl ... exiting"
    exit 1
fi

imgurl=https://www.bing.com$(echo $json | jq -r '.images[0].url')

# Check if imgurl is different from the currently downloaded one
if test -e "$oldurl"; then
    logdebug "oldurl: $(cat $oldurl)"
fi
logdebug "imgurl: $imgurl"
if test -e "$oldurl"; then
    if test "$(cat $oldurl)" == "$imgurl"; then
        logdebug "Previous imgage url: $oldurl is similar to current image url: $imgurl"
        logverbose "No new wallpaper is available ... exiting"
        exit 1
    else
        logdebug "Previous imgage url: $oldurl is diffent from current image url: $imgurl"
        logverbose "New wallpaper is available"
    fi
fi

# Download wallpaper
wget -t 5 --no-check-certificate  $v $q $imgurl -O $downloaded
if test "$?" -eq 0; then
    logdebug "Downloaded: $imgurl"
else
    echo "Failure downloding imgurl: $imgurl ... exiting"
    exit 1
fi

# Extract metadata
startdate=$(echo $json | jq -r '.images[0].startdate')
title=$(echo $json | jq -r '.images[0].title')
copyright=$(echo $json | jq -r '.images[0].copyright')

# Sometimes title field is empty and the title info is in copyright field
if ( (test ! -n "$title") || (test "$title" == "Info") ); then
  title=$copyright
fi

# Print metadata if verbose output
logverbose "Bing wallpaper metadata:"
logverbose "imgurl=$imgurl"
logverbose "startdate=$startdate"
logverbose "title=$title"
logverbose "copyright=$copyright"
logverbose "downloaded=$downloaded"
logverbose "json=$json"

# Add caption
convert -fill 'white' -annotate 0 "$title" -gravity south -pointsize 16 $downloaded $downloaded

archivefile=$archivefileprefix${startdate}.jpg

# Copy to outfile and archive files
if test ! -e "$outfile"; then
    /bin/cp -f $v $downloaded $outfile
    if test ! -e "$archivefile"; then
        /bin/cp -f $v $downloaded $archivefile
    fi
    logverbose "New bing wallpaper downloaded"
    echo "$imgurl" > $oldurl
else
    # Another check on new wallpaper
    cmp --silent $downloaded $outfile  # Returns code 1 at first byte difference
    if test "$?" -eq 1; then
        /bin/cp -f $v $downloaded $outfile
        /bin/cp -f $v $downloaded $archivefile
        logdebug "Downloaded file: $downloaded and outfile: $outfile are different"
        logverbose "New bing wallpaper downloaded"
        echo "$imgurl" > $oldurl
    else
        if test ! -e "$oldurl"; then
            echo "$imgurl" > $oldurl
        fi
        logdebug "Downloaded file: $downloaded and outfile: $outfile are similar"
        logverbose "No new wallpaper available ... exiting"
        exit 1
    fi
fi

# In some systems the wallpaper does not automatically update the wallpaper on
# file change and the next command or similar can be necessary

# gsettings set org.gnome.desktop.background picture-uri $outfile

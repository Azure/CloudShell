#!/bin/sh

# Trigger the script with the file watcher in the background
#/watcher.sh &
/watchUpdate.sh &
tail -f /dev/null

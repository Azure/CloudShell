#!/bin/sh

# Trigger the script with the file watcher in the background
/watchUpdate.sh &
tail -f /dev/null

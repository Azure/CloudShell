#!/bin/bash
PACKAGES_FOLDER=/tmp/cloudshellpkgs
file_removed() {
    xmessage "$2 was removed from $PACKAGES_FOLDER" &
}

file_modified() {
    TIMESTAMP=`date`
    echo "[$TIMESTAMP]: The file $PACKAGES_FOLDER$2 was modified" >> /tmp/monitor_log
}

file_created() {
    TIMESTAMP=`date`
    echo "[$TIMESTAMP]: The file $PACKAGES_FOLDER$2 was created" >> /tmp/monitor_log
}

nohup inotifywait -q -m -r -e modify,delete,create $PACKAGES_FOLDER  | while read DIRECTORY EVENT FILE; do
    case $EVENT in
        MODIFY*)
            file_modified "$DIRECTORY" "$FILE"
            ;;
        CREATE*)
            file_created "$DIRECTORY" "$FILE"
            ;;
        DELETE*)
            file_removed "$DIRECTORY" "$FILE"
            ;;
    esac
done &
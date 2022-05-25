#!/bin/bash
PACKAGES_FOLDER=/tmp/cloudshellpkgs/
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
    echo "[$TIMESTAMP]: Installing $2....." >> /tmp/monitor_log
    cd $PACKAGES_FOLDER &&  /bin/bash $2
}

nohup inotifywait -q -m -r -e modify,delete,create,moved_to $PACKAGES_FOLDER  | while read DIRECTORY EVENT FILE; do
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
        MOVED_TO*)
            file_created "$DIRECTORY" "$FILE"
            ;;
    esac
done &
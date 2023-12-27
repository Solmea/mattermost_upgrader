#!/bin/bash
#
# Source from https://github.com/aljazceru/mattermost-retention
# Modified by Roalt for a dry run analysis. 20231227


###
# configure vars
####

DRY_RUN=false

# Database user name
DB_USER="mmuser"

# Database name
DB_NAME="mattermost"

# Database password
DB_PASS=""

# Database hostname
DB_HOST="127.0.0.1"

# How many days to keep of messages/files?
RETENTION="730"

# Mattermost data directory
DATA_PATH="/opt/mattermost/data/"

# Database drive (postgres OR mysql)
DB_DRIVE="mysql"

## For fun some SQL statemenats
# Get all Tripolis Channels and the count use
# select c.DisplayName, c.TotalMsgCountRoot from Channels c join Teams t on t.Id = c.TeamId order by 2 desc;



###
# calculate epoch in milisec
###
delete_before=$(date  --date="$RETENTION day ago"  "+%s%3N")
echo $(date  --date="$RETENTION day ago")

case $DB_DRIVE in

  postgres)
        echo "Using postgres database."
        export PGPASSWORD=$DB_PASS

        ###
        # get list of files to be removed
        ###
        psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "select path from fileinfo where createat < $delete_before;" > /tmp/mattermost-paths.list
        psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "select thumbnailpath from fileinfo where createat < $delete_before;" >> /tmp/mattermost-paths.list
        psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "select previewpath from fileinfo where createat < $delete_before;" >> /tmp/mattermost-paths.list

        ###
        # cleanup db
        ###
        psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "delete from posts where createat < $delete_before;"
        psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "delete from fileinfo where createat < $delete_before;"
    ;;

  mysql)
        echo "Using mysql database."

        ###
        # get list of files to be removed
        ###
        mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="select path from FileInfo where createat < $delete_before;" > /tmp/mattermost-paths.list
        mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="select thumbnailpath from FileInfo where createat < $delete_before;" >> /tmp/mattermost-paths.list
        mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="select previewpath from FileInfo where createat < $delete_before;" >> /tmp/mattermost-paths.list
        if [ "${DRY_RUN}" == "false" ]; then
                ###
                # cleanup db
                ###
                #mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="delete from Posts where createat < $delete_before;"
                mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="delete from FileInfo where createat < $delete_before;"
        else
                mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="Select count(*) from Posts where createat < $delete_before;" > /tmp/mattermost-post-count.txt
        fi
    ;;
  *)
        echo "Unknown DB_DRIVE option. Currently ONLY mysql AND postgres are available."
        exit 1
    ;;
esac

if [ "${DRY_RUN}" == "false" ]; then
        ###
        # delete files
        ###
        while read -r fp; do
                if [ -n "$fp" ]; then
                        echo "$DATA_PATH""$fp"
                        shred -u "$DATA_PATH""$fp"
                fi
        done < /tmp/mattermost-paths.list

        ###
        # cleanup after script execution
        ###
        rm /tmp/mattermost-paths.list

        ###
        # cleanup empty data dirs
        ###
        find $DATA_PATH -type d -empty -delete
        exit 0
else
        echo "Found files: "
        wc -l /tmp/mattermost-paths.list
        echo "Posts to delete count"
        cat /tmp/mattermost-post-count.txt
        TOTAL_SIZE=0
        while read -r fp; do
                if [ -n "$fp" ]; then
                        #echo "$DATA_PATH""$fp"
                        if [ -f "$DATA_PATH""$fp" ]; then
                                FILESIZE=$(ls -l "$DATA_PATH""$fp"| awk '{ print $5 }')
                                #echo $FILESIZE
                                TOTAL_SIZE=$((${TOTAL_SIZE}+${FILESIZE}))
                        fi
                fi
        done < /tmp/mattermost-paths.list
        TOTAL_MB=$((${TOTAL_SIZE}/1024))
        echo "Total size: ${TOTAL_MB} Mb"
fi

 #!/bin/bash

# This bash script goes out to each server and writes the data in /proc/upti    me
# to /usr/share/tuptime/$SERVER/uptime for each server

# This script is meant to run as a cron job so that the servers that are being statused
# always have up to date information.

# Note that `tuptime -i` needs to be run first to initialize all the directories and files

FILE='servers.conf'
if [ ! -e $FILE ]; then
        echo "$FILE does not exist.  Please create the file!"
        exit 1;
elif [ ! -r $FILE ]; then
        echo "$FILE is not readable!"
        exit 1;
fi

SERVERS=()
while read line; do
        SERVERS+=($line)
done < $FILE
echo "${SERVERS[@]}"

UPTIME_DIR='/usr/share/tuptime/'

# Check if the uptime directory is there.  If not, make it.
if [ ! -d $UPTIME_DIR ]; then
        mkdir $UPTIME_DIR
fi

# Check if the specific server directory is there.  If not, make it.
for server_dir in ${SERVERS[@]}
do
        if [ ! -d "$UPTIME_DIR$server_dir" ]; then
                mkdir "$UPTIME_DIR$server_dir"
        fi
done

# ssh into each server and write out the uptime data to a local file stored
# on the host server.
for server in ${SERVERS[@]}
do
        ssh jhaas@$server cat /proc/uptime > "$UPTIME_DIR$server/uptime" 
        ssh jhaas@$server cat /proc/stat > "$UPTIME_DIR$server/stat"
done

./tuptime.pl -u  # run the tuptime update command after the data has been grabbed from the servers

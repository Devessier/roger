#!/usr/bin/env bash

readonly SUM_FILE="$HOME/.crontab.sum"

touch $SUM_FILE 

oldsum=$(cat $SUM_FILE)
newsum=$(shasum /etc/crontab | awk '{ print $1 }')

echo $oldsum
echo $newsum 

if [ "$oldsum" != "$newsum" ]
then
	# a modification occured, send an email to the root user
	echo $newsum > $SUM_FILE 

	cat <<'EOF' | sudo mail -s "The file /etc/crontab has been modified" root@localhost
Go to /etc/crontab NOW !
Someone modified it !
EOF

fi

#!/bin/bash

# Get the current UTC date and time
if [ "$1" == "" ];
then
	CURRENT_DATE=`date -u +"%Y%m%d"`
else
	CURRENT_DATE=$1
fi

# Determine which Harmonie run shuold be used
if [ "$2" == "" ]; then
	CURRENT_HOUR=`date -u +"%H"`
	if [ ${CURRENT_HOUR} -ge 21 ]; 	then
		MODEL_HOUR=18
	else
		if [ ${CURRENT_HOUR} -ge 15 ]; then
			MODEL_HOUR=12
		else
			if [ ${CURRENT_HOUR} -ge 9 ]; then
				MODEL_HOUR=06
			else
				MODEL_HOUR=00
			fi
		fi
	fi
else
	MODEL_HOUR=$2
fi
echo "About to convert ${CURRENT_DATE} ${MODEL_HOUR}"

# Remove the previous run
cd ~/Downloads/
if [ -d work ]; then
	rm work
fi
# Prepare for the new run
ln -s harm36_v1_ned_surface_${MODEL_HOUR} work

# Only convert if the correct files are present. (The downloaded tar-file only has the time
# in its name. For any date check we need the actual files from the tar-file.)
if [ -f work/harm36_v1_ned_surface_${CURRENT_DATE}${MODEL_HOUR}_000_GB ]; then
	echo "Converting"
	~/Projects/convert.py
	echo "LAST_RUN=${CURRENT_DATE}${MODEL_HOUR}" > ~/Downloads/harmonie-last-run
else
	echo "No files present to process, running too early?"
	exit 1
fi

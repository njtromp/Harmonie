#!/bin/bash
echo "Activated at `date -u`"

# Harmonie runs at 00:00, 06:00, 12:00, and 18:00 UTC 
# Get the current UTC date and time
if [ "$1" == "" ];
then
	CURRENT_DATE=`date -u +"%Y%m%d"`
else
	CURRENT_DATE=$1
fi

# Determine which Harmonie run should be used
# Hoarmnie runs take 3 hours hence the check for > 21 for the run of 18:00 etc 
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
				if [ ${CURRENT_HOUR} -ge 3 ]; then
					MODEL_HOUR=00
				else
					# Use last run on previous day 
					CURRENT_DATE=`date -v-1d -u +"%Y%m%d"`
					MODEL_HOUR=18
				fi
			fi
		fi
	fi
else
	MODEL_HOUR=$2
fi

cd ~/Downloads
# Make sure only to run when there actually is something to do.
# This makes it possible to have this script be run as a cronjob every hour
# and handle the UTC time here. The last successfull run is stored in the
# ~/Downloads/harmonie-last-run file.
source ~/Downloads/harmonie-last-run
if [ "${CURRENT_DATE}${MODEL_HOUR}" == "${LAST_RUN}" ]; then
	echo "Already run..."
	exit 1
fi

# We could be just a tiny bit to early therefore we need to do the downloading and conversion in a loop!
while true; do

	# Wait untill the lid is open so we really can download...
	source ~/Downloads/lid-status
	while [ "${LID_STATUS}" == "CLOSED" ]; do
		sleep 60
		# Refresh the status
		source ~/Downloads/lid-status
	done

	# Keep trying to download if it failed until it succeeds.
	# (Might not be a good idea though...)
	while true; do
		echo "Checking for new data `date -u`"
		# User and password are stored in .netrc!
		# ftp "ftp://data.knmi.nl/download/harmonie_p1/0.2/noversion/0000/00/00/harm36_v1_ned_surface_${MODEL_HOUR}.tgz"
		/usr/local/bin/wget -m -nd -np -nv --unlink "ftp://data.knmi.nl/download/harmonie_p1/0.2/noversion/0000/00/00/"
		# Download successfull?
		if [ $? == 0 ]; then
			break
		fi
		# Some delay in order to prevent the FTP server from overloading
		sleep 60
	done

	# Removing old GRIB file
	if [ -f *${MODEL_HOUR}_zygrib_nl.grb.bz2 ]; then
		rm *${MODEL_HOUR}_zygrib_nl.grb.bz2
	fi

	# Make sure there is an empty directory for the latest model files
	if [ -d harm36_v1_ned_surface_${MODEL_HOUR} ]; then
		rm harm36_v1_ned_surface_${MODEL_HOUR}/*
	else
		mkdir harm36_v1_ned_surface_${MODEL_HOUR}
	fi

	# Before extracting go into the correct folder
	cd ~/Downloads/harm36_v1_ned_surface_${MODEL_HOUR}
	echo "Extracting..."
	tar -xzvf ../harm36_v1_ned_surface_${MODEL_HOUR}.tgz
	cd ~/Downloads

	# Remove the previous run
	if [ -d work ]; then
		rm work
	fi
	# Prepare for the new run
	ln -s harm36_v1_ned_surface_${MODEL_HOUR} work

	# Only convert if the correct files are present. (The downloaded tar-file only has the time
	# in its name. For any date check we need the actual files from the tar-file.)
	if [ -f work/harm36_v1_ned_surface_${CURRENT_DATE}${MODEL_HOUR}_000_GB ]; then
		echo "Converting"
		~/Projects/Harmonie/convert.py
		# If everything went fine..
		if [ $? -eq 0 ]; then
			# ... lets remember it ...
			echo "LAST_RUN=${CURRENT_DATE}${MODEL_HOUR}" > ~/Downloads/harmonie-last-run
			# ..and cleanup the campgrouond
			rm ~/Downloads/work
			rm -fr ~/Downloads/harm36_v1_ned_surface_${MODEL_HOUR}
			break
		else
			echo "Unable to convert, breaking off the attempt..."
			exit 2
		fi
	fi

	echo "KNMI most likely not ready, we'll try again shortly..."
	sleep 60
done

echo "Ready `date -u`."

#!/bin/bash
echo "Activated at `date -u`"

WAIT_FOR_DOWNLOAD=true
# We could be just a tiny bit to early therefore we need to do the downloading and conversion in a loop!
while ${WAIT_FOR_DOWNLOAD}; do
	cd ~/Downloads

	# Wait untill the lid is open so we really can download...
	source ~/Downloads/lid-status
	if [ "${LID_STATUS}" == "CLOSED" ]; then
		echo "Waiting for my master...."
	fi
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
		/usr/local/bin/wget -m -nd -np -nv --unlink "ftp://data.knmi.nl/download/harmonie_p1/0.2/noversion/0000/00/00/" 2> ~/Downloads/harmonie-ftp.log
		# /usr/local/bin/wget -m -nd -np -nv --unlink "ftp://data.knmi.nl/download/harmonie_p1/0.2/noversion/0000/00/00/"
		# Download successfull?
		DOWNLOADS=`grep tgz ~/Downloads/harmonie-ftp.log|wc -l|xargs`
		echo "Number of upateted files [${DOWNLOADS}]"
		if [ ! "${DOWNLOADS}" == "0" ]; then
			WAIT_FOR_DOWNLOAD=false
			break
		fi
		# Some delay in order to prevent the FTP server from overloading
		sleep 60
	done

	for MODEL in `grep tgz ~/Downloads/harmonie-ftp.log | cut -d\" -f2 | cut -d\. -f1`; do
		MODEL_HOUR=`echo "${MODEL}" | cut -d_ -f5`
		echo "About to process [${MODEL}], run from [${MODEL_HOUR}]"
		MODEL_RUNS="${MODEL_RUNS}\n\t${MODEL_HOUR}"
	
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

		echo "Converting"
		~/Projects/Harmonie/convert.py

		# If everything went fine ...
		if [ $? -eq 0 ]; then
			# ... cleanup the campground
			rm ~/Downloads/work
			rm -fr ~/Downloads/harm36_v1_ned_surface_${MODEL_HOUR}
		fi
	done

done

echo "Ready `date -u`."
osascript -e "display alert \"KNMI update\" message \"New Harmonie data is available from runs ${MODEL_RUNS}\""


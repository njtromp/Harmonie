#!/bin/bash
echo "Activated at `date -u`"

cd ~/Downloads

# Only wait for the lid to be open if supported.
if [ -f ~/Downloads/lid-status ]; then
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
fi

while true; do
	# Keep trying to download if it failed until it succeeds.
	# (Might not be a good idea though...)
	while true; do
		echo "Checking for new data `date -u`"
		# User and password are stored in ~/.netrc!
		/usr/local/bin/wget -m -nd -np -nv --unlink "ftp://data.knmi.nl/download/harmonie_p1/0.2/noversion/0000/00/00/" 2> ~/Downloads/harmonie-ftp.log
		# Download successfull?
		DOWNLOADS=`grep tgz ~/Downloads/harmonie-ftp.log|wc -l|xargs`
		echo "Number of upateted files [${DOWNLOADS}]"
		if [ ! "${DOWNLOADS}" == "0" ]; then
			break
		fi
		# Some delay in order to prevent the FTP server from overloading
		sleep 60
	done

	LAST_RUN=0
	# Convert only the newly downloaded model data.
	for MODEL in `grep tgz ~/Downloads/harmonie-ftp.log | cut -d\" -f2 | cut -d\. -f1`; do
		cd ~/Downloads
		MODEL_HOUR=`echo "${MODEL}" | cut -d_ -f5`
		echo "About to process [${MODEL}], run from [${MODEL_HOUR}]"
		MODEL_RUNS="${MODEL_RUNS}\n\t${MODEL_HOUR}"

		# Removing old GRIB files
		rm ~/Downloads/*${MODEL_HOUR}_zygrib_nl.grb.bz2

		# Make sure there is an empty directory for the latest model files
		if [ -d "harm36_v1_ned_surface_${MODEL_HOUR}" ]; then
			rm "harm36_v1_ned_surface_${MODEL_HOUR}/*"
		else
			mkdir "harm36_v1_ned_surface_${MODEL_HOUR}"
		fi

		# Before extracting go into the correct folder
		cd "harm36_v1_ned_surface_${MODEL_HOUR}"
		echo "Extracting..."
		tar -xzvf "../harm36_v1_ned_surface_${MODEL_HOUR}.tgz"
		cd ~/Downloads

		# Remove the previous run
		if [ -d work ]; then
			rm work
		fi
		# Prepare for the new run
		ln -s "harm36_v1_ned_surface_${MODEL_HOUR}" work

		# Register the data-time of the most recent run
		CURRENT_RUN=`ls ~/Downloads/work/*_000_GB|cut -d'_' -f5`
		if [ "${CURRENT_RUN}" -gt "${LAST_RUN}" ]; then
			LAST_RUN=${CURRENT_RUN}
		fi

		echo "Converting"
		~/Projects/Harmonie/convert.py

		# If everything went fine ...
		if [ $? -eq 0 ]; then
			# ... cleanup the campground
			rm ~/Downloads/work
			rm -fr "harm36_v1_ned_surface_${MODEL_HOUR}"
		fi
	done

	# OS-X only display trick
	osascript -e "display alert \"KNMI update\" message \"New Harmonie data is available from run(s) ${MODEL_RUNS}\""

	# If there is a more recent run available which we missed, run the script again...
	# The check is the other way around, otherwise we can't bail out of the while-loop.
	THRESHOLD=`date -v-9H -u +"%Y%m%d%H"`
	if [ "${LAST_RUN}" -ge "${THRESHOLD}" ]; then
		# Goodbye
		echo "Ready `date -u`."
		exit 0
	fi
done

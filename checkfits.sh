#!/bin/bash

#: Title	: checkfits.sh
#: Date		: 2014/10/28
#: Author	: "Marco De Marco" <demarco@oats.inaf.it>
#: Version	: 2.0
#: Description	: Fits verification and proccessing script

#Tools paths
VERIFY_TOOL="/usr/local/bin/fitsverify"
LISTHEAD_TOOL="/usr/local/bin/listhead"
MODHEAD_TOOL="/usr/local/bin/modhead"

if [ "$1" == "CHECK" ]; then

	#: Section	: CHECK
	#: Parameter	: none
	#: Response	: CHECK OK
	#: 		: CHECK FATAL
	#: Description	: Check availability of script tools

	#Check fitsverify tools
	CHECK_STRING="conform to the FITS format"

	res=$($VERIFY_TOOL 2>&1)

	check=$(echo $res | grep "$CHECK_STRING" | wc | awk '{print $1}')
	if [ "$check" -lt "1" ]; then
		echo "CHECK FATAL"
		exit 0
	fi

	#Check listhead tools
	CHECK_STRING="Usage: listhead filename"

	res=$($LISTHEAD_TOOL 2>&1)

	check=$(echo $res | grep "$CHECK_STRING" | wc | awk '{print $1}')
	if [ "$check" -lt "1" ]; then
		echo "CHECK FATAL"
		exit 0
	fi

	#Check modhead tools
	CHECK_STRING="Usage: modhead filename"

	res=$($MODHEAD_TOOL 2>&1)

	check=$(echo $res | grep "$CHECK_STRING" | wc | awk '{print $1}')
	if [ "$check" -lt "1" ]; then
		echo "CHECK FATAL"
		exit 0
	fi

	echo "CHECK OK"
	exit 0

elif [ "$1" == "VALID" ]; then

	#: Section	: VALID
	#: Parameter	: file path
	#: Response	: VALID OK
	#: 		: VALID IGNORE
	#: Description	: Check file name compliance

	file=$2
	file_name=${file##*/}

        #Check regex for tec files -> ignore
        if [[ "${file_name,,}" =~ ^.*lbc.?tec.*\.(fits|fit|fts).*$ ]]; then
                echo "VALID IGNORE: discard tec file"
                exit 0
        fi

	#Check regex for rsync temporary file -> ignore
	if [[ ! "${file_name,,}" =~ ^[^\.].*\.(fits|fit|fts).*$ ]]; then
		echo "VALID IGNORE: invalid regular expression"
		exit 0
	fi

	echo "VALID OK"
	exit 0

elif [ "$1" == "VERIFY" ]; then

	#: Section	: VERIFY
	#: Parameter	: file path
	#: Response	: VERIFY OK
	#: 		: VERIFY WAIT
	#: 		: VERIFY FATAL
	#: Description	: Check file compliance to fits format

	file=$2

	FATAL_ERROR="Fatal"
	EOF_ERROR="End-of-file"

        #Change file and permission before processing
        /usr/bin/sudo -n /bin/chmod go+r $file

	#if fits verify tools exists -> fatal
	if [ ! -x $VERIFY_TOOL ]; then
		echo "VERIFY FATAL : verify tools not exists"
		exit 0
	fi

	#if fits file not exists -> fatal
	if [ ! -f $file ]; then
		echo "VERIFY FATAL : file not exists"
		exit 0
	fi

	#Check with fits verify
	res=$($VERIFY_TOOL $file 2>&1)

	#if fitsverify return fatal error -> wait
	fatal=$(echo $res | grep "$FATAL_ERROR" | wc | awk '{print $1}')
	if [ "$fatal" -ge "1" ]; then
		echo "VERIFY FATAL"
		exit 0
	fi

	#if fitsverify return end of file -> wait
	eof=$(echo $res | grep "$EOF_ERROR" | wc | awk '{print $1}')
	if [ "$eof" -ge "1" ]; then
		echo "VERIFY WAIT"
		exit 0
	fi

	#else -> ok
	echo "VERIFY OK"
	exit 0

elif [ "$1" == "PREPROCESS" ]; then

	#: Section	: PREPROCESS
	#: Parameter	: file path
	#: 		: ingestion result [OK, WAIT, FATAL]
	#: Response	: PREPROCESS OK
	#: 		: PREPROCESS FATAL
	#: Description	: Apply preprocessing before ingestion

	file=$2
	file_name=${file##*/}

	verified=$3

	#Check verified parameter value
	if [ "$verified" != "OK" -a "$verified" != "WAIT" -a "$verified" != "FATAL" ]; then
		echo "PREPROCESS FATAL"
		exit 0
	fi

	#Pre processing for verified OK files
	if [ "$verified" == "OK" ]; then

		#Change file ownership
		/usr/bin/sudo -n /bin/chown controls:controls $file
		#Change file and permission before processing
		/usr/bin/sudo -n /bin/chmod u+rw $file

		#Check regular expression for luci files
		if [[ "${file_name,,}" =~ ^.*luci.*\.(fits|fit|fts).*$ ]]; then

			#if listhead tools exists -> fatal
			if [ ! -x $LISTHEAD_TOOL ]; then
				echo "PREPROCESS FATAL : listhead tools not exists"
				exit 0
			fi

			#if modhead tools exists -> fatal
			if [ ! -x $MODHEAD_TOOL ]; then
				echo "PREPROCESS FATAL : listhead tools not exists"
				exit 0
			fi

			#if fits file not exists -> fatal
			if [ ! -f $file ]; then
				echo "PREPROCESS FATAL : file not exists"
				exit 0
			fi

			#Change GRATWLEN key from 'not used' to 0.0
			gratwlen=`$LISTHEAD_TOOL $file 2>&1 | grep -i GRATWLEN`
			if [[ $gratwlen =~ "'not used'/" ]]; then
				$MODHEAD_TOOL $file GRATWLEN 0.0 &>/dev/null
			fi

			#Change GRATORDE key from 'not used' to 0.0
			gratorde=`$LISTHEAD_TOOL $file 2>&1 | grep -i GRATORDE`
			if [[ $gratorde =~ "'not used'/" ]]; then
				$MODHEAD_TOOL $file GRATORDE 0.0 &>/dev/null
			fi
		fi #luci files

		#Check regular expression for irt files
		if [[ "${file_name,,}" =~ ^.*irt.*\.(fits|fit|fts).*$ ]]; then

			#if listhead tools exists -> fatal
			if [ ! -x $LISTHEAD_TOOL ]; then
				echo "PREPROCESS FATAL : listhead tools not exists"
				exit 0
			fi

			#if modhead tools exists -> fatal
			if [ ! -x $MODHEAD_TOOL ]; then
				echo "PREPROCESS FATAL : listhead tools not exists"
				exit 0
			fi

			#if fits file not exists -> fatal
			if [ ! -f $file ]; then
				echo "PREPROCESS FATAL : file not exists"
				exit 0
			fi

			#Search for DATE_OBS keyword
			res=`$LISTHEAD_TOOL $file 2>&1 | grep DATE_OBS | wc | awk '{print $1}'`
			if [ $res -eq 0 ]; then

				date=`$LISTHEAD_TOOL $file 2>&1 | grep DATE-OBS`
				time=`$LISTHEAD_TOOL $file 2>&1 | grep TIME-OBS`

				if [ ! -z "$date" -a ! -z "$time" ]; then
					date_obs=${date:11:10}T${time:11:12}
					$MODHEAD_TOOL $file DATE_OBS "'$date_obs'" &>/dev/null
				fi
			fi
		fi #irt files

	fi #verified ok files

	echo "PREPROCESS OK"
	exit 0

elif [ "$1" == "POSTPROCESS" ]; then

	#: Section	: POSTPROCESS
	#: Parameter	: file path
	#: 		: ingestion result [OK, WAIT, FATAL]
	#: Response	: POSTPROCESS OK
	#: 		: POSTPROCESS FATAL
	#: Description	: Apply postprocessing after ingestion

	file=$2
	file_name=${file##*/}

	verified=$3

	#Check verified parameter value
	if [ "$verified" != "OK" -a "$verified" != "WAIT" -a "$verified" != "FATAL" ]; then
		echo "POSTPROCESS FATAL"
		exit 0
	fi

	#Post process verified WAIT files
	if [ "$verified" == "WAIT" ]; then
		echo "New data file $file_name has reached a wait eof timeout" | mutt -s "Pre process log" scienceops@lbto.org -c ia2-lbt-log@oats.inaf.it
	fi

	#Post process verified FATAL files
	if [ "$verified" == "FATAL" ]; then
		echo "New data file $file_name has fatal error" | mutt -s "Pre process log" scienceops@lbto.org -c ia2-lbt-log@oats.inaf.it
	fi

	echo "POSTPROCESS OK"
	exit 0

else

	#: Section	: DEFAULT
	#: Parameter	: none
	#: Response	: UNKNOWN

	echo "UNKNOWN"
	exit 0

fi

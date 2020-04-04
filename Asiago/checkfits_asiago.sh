#!/bin/bash

#: Title	: fits.sh
#: Date		: 2014/03/03
#: Author	: "Marco De Marco" <demarco@oats.inaf.it>
#: Version	: 0.1
#: Description	: Fits verification and preproccessing script

#Tools paths
VERIFY_TOOL="/usr/local/bin/fitsverify"



if [ "$1" == "CHECK" ]; then

	#: Section	: CHECK
	#: Parameter	: none
	#: Response	: CHECK OK
	#: 		: CHECK FATAL
	#: Description  : Check availability of script tools

	#Check fitsverify tools
	CHECK_STRING="conform to the FITS format"

	res=$($VERIFY_TOOL 2>&1)

	check=$(echo $res | grep "$CHECK_STRING" | wc | awk '{print $1}')
	if [ "$check" -ge "1" ]; then
		echo "CHECK OK"
	else
		echo "CHECK FATAL"
	fi
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
	#: Description  : Check file compliance to fits format

	file=$2

	FATAL_ERROR="Fatal"
	EOF_ERROR="End-of-file"

        #Change file and permission before processing
        /usr/bin/sudo -n /bin/chmod go+r $file

	#if fits verify tools exists -> fatal
	if [ ! -x $VERIFY_TOOL ]; then
		echo "VERIFY FATAL : verify tool does not exist"
		exit 0
	fi

	#if fits file not exists -> fatal
	if [ ! -f $file ]; then
		echo "VERIFY FATAL : file does not exist"
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

        #: Section      : PREPROCESS
        #: Parameter    : file path
        #:              : ingestion result [OK, WAIT, FATAL]
        #: Response     : PREPROCESS OK
        #:              : PREPROCESS FATAL
        #: Description  : Apply preprocessing before ingestion

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
                /usr/bin/sudo -n /bin/chown archivio:archivio $file
                #Change file and permission before processing
                /usr/bin/sudo -n /bin/chmod u+rw $file

                #Unpack Schmidt files
		if [[ "${file_name##*.}" == fz ]]; then
			funpack -D $file	
	        fi #Schmidt files

        fi #verified ok files

        echo "PREPROCESS OK"
        exit 0

elif [ "$1" == "POSTPROCESS" ]; then

        #: Section      : POSTPROCESS
        #: Parameter    : file path
        #:              : ingestion result [OK, WAIT, FATAL]
        #: Response     : POSTPROCESS OK
        #:              : POSTPROCESS FATAL
        #: Description  : Apply postprocessing after ingestion

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
                echo "New data file $file_name has reached a wait eof timeout" | mutt -s "Pre-process log" elisa.londero@inaf.it -c ia2-lbt-log@oats.inaf.it
        fi

        #Post process verified FATAL files
        if [ "$verified" == "FATAL" ]; then
                echo "New data file $file_name has fatal error" | mutt -s "Pre-process log" elisa.londero@inaf.it -c ia2-lbt-log@oats.inaf.it
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

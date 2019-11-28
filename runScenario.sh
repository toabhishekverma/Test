


function sendFD(){	
	local MON=$2
	local CODE=$3
	local SC=$1
	mkdir -p $SC
	
	if [ -z $CODE ] ; then 
		touch $SC/db
	else
		#echo "	Sending $CODE,Month=$2"
		echo "$2-$CODE,"
		echo $MON,$CODE>>$SC/db
	fi	
}

function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

function runFDFlow(){
	local MON=$1
	local SCF=$2
	local COUNT=$(cat $SCF/LAST3|wc -l|rev|cut -d' ' -f1|rev)
	local LAST_CODE=$(cat $SCF/LAST3 |tail -1|cut -d, -f2)
	local LAST_DIFFICULTY=$(echo $LAST_CODE|cut -d'=' -f1)
	local LAST_MONTH=$(cat $SCF/LAST3 |tail -1|cut -d, -f1)
	local DIFF_LAST_MONTH=$(cat $SCF/LAST3 |tail -1|cut -d, -f3)
	local LAST2FDCOUNT=$(cat sc1/LAST3|tail -2|grep "FD=1\|FD=3"|grep FD|cut -d, -f3|wc -l)
	local LAST2FDMON=0
	#echo runFDFlow MON=$MON Count=$COUNT 
	if [ $LAST2FDCOUNT -eq 2 ] ; then 
		LAST2FDM1=$(cat sc1/LAST3|grep FD |tail -2|cut -d, -f3)
		LAST2FDM2=$(echo $LAST2FDM1 |tr ' ' '-')
		let LAST2FDMON=$LAST2FDM2 
	fi	
	
	if [ ! -z $LAST_DIFFICULTY ] && [ "$LAST_DIFFICULTY" != "FD" ] ; then
		#echo LAST_DIFFICULTY = $LAST_DIFFICULTY
        COUNT=0
	fi

	if [ $COUNT -eq "0" ] ; then
			#echo Fresh cycle $COUNT 
			sendFD $SCF $MON "FD=1"  
	elif [ $LAST2FDMON -le 12 ] && [ $LAST2FDCOUNT -eq 2 ]; then
		#echo LAST2FDMON=$LAST2FDMON LAST2FDCOUNT=$LAST2FDCOUNT
		sendFD $SCF $MON "FD=2";
	else
			
			if [ "$LAST_CODE" == "FD=1" ] && [ $DIFF_LAST_MONTH -eq 1 ] ; then 
				sendFD $SCF $MON "FD=2";
			elif [ "$LAST_CODE" == "FD=2" ] && [ $DIFF_LAST_MONTH -eq 2 ] ; then
				sendFD $SCF $MON "FD=3";
			elif [ "$LAST_CODE" = "FD=3" ] && [ $DIFF_LAST_MONTH -eq 6 ]  ; then
				  sendFD $SCF $MON "FD=1"
			else	
				if [ "$LAST_CODE" = "FD=1" ] && [ $DIFF_LAST_MONTH -gt 1 ]  ; then	
					#echo 1. Starting fresh cycle
					sendFD $SCF $MON "FD=1"
				elif [ "$LAST_CODE" = "FD=2" ] && [ $DIFF_LAST_MONTH -gt 2 ] ; then
					#echo 2. Starting fresh cycle
                    sendFD $SCF $MON "FD=1"
				elif [ "$LAST_CODE" = "FD=3" ] && [ $DIFF_LAST_MONTH -gt 6 ] ; then
					#echo 3. Starting fresh cycle
					 sendFD $SCF $MON "FD=1"
				fi
			fi
		fi

}

function runRUFlow(){
	local MON=$1
	local SCF=$2
	DB=$SCF/db
	local COUNT=$(cat $SCF/LAST3|wc -l|rev|cut -d' ' -f1|rev)
	local LAST_CODE=$(cat $SCF/LAST3 |tail -1|cut -d, -f2)
	local LAST_DIFFICULTY=$(echo $LAST_CODE|cut -d'=' -f1)
	local DIFF_LAST_MONTH=$(cat $SCF/LAST3 |tail -1|cut -d, -f3)
	local COUNT_RU_18MONTH=$(cat $DB |grep RU|wc -l|rev|cut -d' ' -f1|rev)
	if [ -z $LAST_DIFFICULTY ] ; then
        COUNT=0
	else
		if [ $LAST_DIFFICULTY = "FD" ] ; then
			if [ $COUNT_RU_18MONTH -ge 2 ] ; then 
				LAST_CODE="RU=2"
			else
				local LAST_RU_CODE=$(cat $DB |grep RU |tail -1|cut -d, -f2)
				if [ "$LAST_RU_CODE" == "RU=1" ] ; then
					LAST_CODE="RU=1"
				else
					LAST_CODE="RU=2"
				fi
			fi
		fi
	fi
	#cho LAST_DIFFICULTY = $LAST_DIFFICULTY Count=$COUNT
	if [ $COUNT -eq "0" ] ; then
				sendFD $SCF $MON "RU=1"
	else
		if [ "$LAST_CODE" = "RU=1" ] && [ $DIFF_LAST_MONTH -ge 6 ]  ; then
			sendFD $SCF $MON "RU=2"
		elif [ "$LAST_CODE" = "RU=2" ] && [ $DIFF_LAST_MONTH -ge 12 ] ; then
			sendFD $SCF $MON "RU=3"
		elif [ "$LAST_CODE" = "RU=3" ] && [ $DIFF_LAST_MONTH -ge 12 ]  ; then
			sendFD $SCF $MON "RU=2"
		fi
	fi
}

function processDB(){
	local CUR_MON=$1
	local SCF=$2
	local DB=$SCF/db
	local LINE_COUNT=0;
	while read LINE; 
	do 
		local LINE_MON=$(echo $LINE|cut -d, -f1); 
		local DIFF=$((CUR_MON-LINE_MON)); 
		if [ $DIFF -gt 18 ] ; then
			LINE_COUNT=$((LINE_COUNT+1))
			continue;
		else
			break;
		fi
	done<$DB
	if [ $LINE_COUNT -gt 0 ] ; then
		#echo Trimming $LINE_COUNT lines from DB
		local LINES=$(cat $DB |wc -l|rev|cut -d' ' -f1|rev)
		local TAIL_LINE=$((LINES-LINE_COUNT))
		cat $DB |tail -$TAIL_LINE >$SCF/db_backup
		cp $SCF/db_backup $DB
	fi
}

function runScenario(){
	
	MONTH=$1
	SCF=$2
	DB=$SCF/db
	DIFFICULTY=$3	
	processDB $MONTH $SCF

	cat $DB| tail -3 |./getMonthDiff.sh $MONTH >$SCF/LAST3
    
	if [ "$DIFFICULTY" = "FD" ] ; then 
		#echo COUNT=$COUNT MONTH=$MON SCF=$SCF DIFF_LAST_MONTH=$LAST_MONTH LASTCODE=$LAST_CODE DIFFICULTY=$DIFFICULTY LAST_DIFFICULTY=$LAST_DIFFICULTY LAST2FDMON=$LAST2FDMON
		runFDFlow $MONTH $SCF
	else
		runRUFlow $MONTH $SCF
	fi
}

function prepareScenario(){
	local SCF=$1
	rm -rf $SCF
	sendFD $SCF
	echo Prepared scenario $SCF
}

function processScnario(){

	local SCF=$1
	local DIFFICULTY=$2
	local START=$3 
	local END=$4
	local MISSED_DATES=( $5 ) 
	#, Missing Months $MISSED_DATES
	for count in $(seq $START $END)
	do
		if [ ! $(contains "${MISSED_DATES[@]}" "$count") == "y" ]; then
			OUTPUT=$(runScenario $count $SCF $DIFFICULTY)
			echo -n $OUTPUT >>$SCF/OUTPUT
			printf "$OUTPUT"
		fi
	done

}


function checkScenario(){
	RESULT=$(cat $1/OUTPUT)
	echo -e
	echo -e $RESULT 
	if [ "$RESULT" = "$2" ] ; then
		echo Scenario $1 Pass
	else 
		echo Scenario $1 fail
	fi

	echo
}



function oldTestcases(){

	#RU_DATES=(1 7 19 31 43)
	FD_DATES_MISSED=( 2 3 4 5 6 7 8 9 10 11 12 13 15 16 18)
	#FD_DATES=( 19 )
	#processScnario sc1 FD 50 "2 3 4 5 6 7 8 9 10 11 12 13 15 16 18"

	prepareScenario sc2
	processScnario sc2 RU 1 4 " 7 8 "
	processScnario sc2 FD 5 5 " "
	processScnario sc2 RU 6 18 " "

	prepareScenario sc3
	processScnario sc3 RU 1 1 " 7 8 "
	processScnario sc3 FD 2 2 " "
	processScnario sc3 RU 3 3 " "
	processScnario sc3 FD 4 4 " "
	processScnario sc3 RU 5 50 " "

	
SCENE=ru1
prepareScenario $SCENE
processScnario $SCENE RU 1 100 " 67 68 69 70 71 72 73"
checkScenario $SCENE 1-RU=1,7-RU=2,19-RU=3,31-RU=2,43-RU=3,55-RU=2,74-RU=1,80-RU=2,92-RU=3,

SCENE=ru2
prepareScenario $SCENE
processScnario $SCENE RU 1 100 " 6 7 8 45 46 47"
checkScenario $SCENE 1-RU=1,9-RU=2,21-RU=3,33-RU=2,48-RU=3,60-RU=2,72-RU=3,84-RU=2,96-RU=3,


SCENE=ru3
prepareScenario $SCENE
processScnario $SCENE RU 1 47 " 6 7 8 45 46 47"
processScnario $SCENE FD 48 48  " "
processScnario $SCENE RU 49 100 " "
checkScenario $SCENE 1-RU=1,9-RU=2,21-RU=3,33-RU=2,48-FD=1,60-RU=3,72-RU=2,84-RU=3,96-RU=2,

SCENE=ru4
prepareScenario $SCENE
processScnario $SCENE RU 1 40 " 6 7 8 45 46 47"
processScnario $SCENE FD 41 41  " "
processScnario $SCENE RU 42 100 " "
#cat $SCENE/OUTPUT
checkScenario $SCENE "1-RU=1,9-RU=2,21-RU=3,33-RU=2,41-FD=1,53-RU=3,65-RU=2,77-RU=3,89-RU=2,"
echo

SCENE=ru5
prepareScenario $SCENE
processScnario $SCENE RU 1 40 " 6 7 8 45 46 47"
processScnario $SCENE FD 41 42  " "
processScnario $SCENE RU 42 100 " "
 checkScenario $SCENE  "1-RU=1,9-RU=2,21-RU=3,33-RU=2,41-FD=1,42-FD=2,54-RU=3,66-RU=2,78-RU=3,90-RU=2,"
#$SCENE/OUTPUT
echo
SCENE=ru6
prepareScenario $SCENE
processScnario $SCENE RU 1 8 " 6 7 8 45 46 47"
processScnario $SCENE FD 9 9  " "
processScnario $SCENE RU 10 60 " "
 checkScenario $SCENE  "1-RU=1,9-FD=1,15-RU=2,27-RU=3,39-RU=2,51-RU=3,"
#$SCENE/OUTPUT
echo


SCENE=fd-a2
prepareScenario $SCENE
processScnario $SCENE FD 1 36 " 4 "
checkScenario $SCENE  "1-FD=1,2-FD=2,5-FD=1,6-FD=2,8-FD=3,14-FD=1,15-FD=2,17-FD=3,23-FD=1,24-FD=2,26-FD=3,32-FD=1,33-FD=2,35-FD=3,"
echo

SCENE=fd1-2
prepareScenario $SCENE
processScnario $SCENE FD 1 12 " 2  3 "
checkScenario $SCENE  "1-FD=1,4-FD=1,5-FD=2,7-FD=3,"
echo

SCENE=fd3
prepareScenario $SCENE
processScnario $SCENE FD 1 18 " 2 "
checkScenario $SCENE  "1-FD=1,3-FD=1,4-FD=2,6-FD=3,12-FD=1,13-FD=2,15-FD=3,"
echo

SCENE=fd4
prepareScenario $SCENE
processScnario $SCENE FD 1 12 " 2 3 4 5 "
checkScenario $SCENE  "1-FD=1,10-FD=1,11-FD=2,13-FD=3,"
echo

SCENE=fd5
prepareScenario $SCENE
processScnario $SCENE FD 1 15 " 2 3 4 5 6 7 8 9 "
checkScenario $SCENE  "1-FD=1,6-FD=1,7-FD=2,9-FD=3,"
echo

SCENE=fd6
prepareScenario $SCENE
processScnario $SCENE FD 1 12 " "
checkScenario $SCENE  "1-FD=1,2-FD=2,4-FD=3,10-FD=1,11-FD=2,"
echo

SCENE=ru1-1
prepareScenario $SCENE
processScnario $SCENE RU 1 6 " "
checkScenario $SCENE 1-RU=1,


SCENE=ru1-1
prepareScenario $SCENE
processScnario $SCENE RU 1 20 " "
checkScenario $SCENE 1-RU=1,7-RU=2,19-RU=3,
}




SCENE=rum1
prepareScenario $SCENE
processScnario $SCENE RU 1 11 " 2 3 4 5 6 7 8 9 10 "
checkScenario $SCENE 1-RU=1,11-RU=2,




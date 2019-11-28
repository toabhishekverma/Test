DIFF_LAST_MONTH=2
LAST_CODE="FD=2"
if [ "$LAST_CODE" = "FD=1" ] && [ $DIFF_LAST_MONTH -eq 1 ] ; then
		sendFD $SCF $MON "FD=2"			
	elif [ $DIFF_LAST_MONTH -eq 2 ] && [ "$LAST_CODE" = "FD=2" ] ; then
        	sendFD $SCF $MON "FD=3"
        elif [ $DIFF_LAST_MONTH -eq 6 ] && [ "$LAST_CODE" = "FD=3" ] ; then
		sendFD $SCF $MON "FD=1"
	#else	
fi

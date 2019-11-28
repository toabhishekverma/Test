CUR_MON=$1
if [ -p /dev/stdin ] ; then
       while IFS= read LINE; do
       PRE_MON=$(echo $LINE|cut -d, -f1)
       DIFF=$((CUR_MON-PRE_MON))
       echo $LINE,$DIFF
       done
else
    echo $LINE
fi

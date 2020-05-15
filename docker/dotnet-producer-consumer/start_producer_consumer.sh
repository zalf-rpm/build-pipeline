#!/bin/sh
env
mkdir -p /out
python3 -u $MONICA_HOME/Examples/Hohenfinow2/python/run-consumer.py server=${LINKED_MONICA_SERVICE} leave_after_finished_run=True out=$MONICA_HOME/testing/ &
sleep 5
python3 -u $MONICA_HOME/Examples/Hohenfinow2/python/run-producer.py server=${LINKED_MONICA_SERVICE} climate.csv=/monica_data/climate-data/climate-min.csv writenv=True
sleep 5
cp $MONICA_HOME/testing/1.csv /out
$MONICA_HOME/testing/CoreConsoleParser -ref $MONICA_HOME/testing/testreference.csv -totest $MONICA_HOME/testing/1.csv
return $?



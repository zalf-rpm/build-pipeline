#!/bin/sh
env
python -u $MONICA_HOME/Examples/Hohenfinow2/python/run-consumer.py server=${LINKED_MONICA_SERVICE} leave_after_finished_run=True out=/$MONICA_HOME/testing/ &
sleep 5
python -u $MONICA_HOME/Examples/Hohenfinow2/python/run-producer.py server=${LINKED_MONICA_SERVICE}
sleep 5
ls -al $MONICA_HOME/testing/CoreConsoleParser
$MONICA_HOME/testing/CoreConsoleParser -ref /$MONICA_HOME/testing/testreference.csv -totest /$MONICA_HOME/testing/1.csv
sleep 5
#!/bin/sh
env
sleep 10
python -u $MONICA_HOME/Examples/Hohenfinow2/python/run-consumer.py server=${LINKED_MONICA_SERVICE} leave_after_finished_run=True &
python -u $MONICA_HOME/Examples/Hohenfinow2/python/run-producer.py server=${LINKED_MONICA_SERVICE}
sleep 10
./$MONICA_HOME/testing/CoreConsoleParser -ref /$MONICA_HOME/testing/testreference.csv -totest /$MONICA_HOME/testing/consumer-out.csv
sleep 15
#!/bin/sh
env
python -u $MONICA_HOME/Examples/Hohenfinow2/python/run-consumer.py server=${LINKED_MONICA_SERVICE} leave_after_finished_run=True &
python -u $MONICA_HOME/Examples/Hohenfinow2/python/run-producer.py server=${LINKED_MONICA_SERVICE}
sleep 15

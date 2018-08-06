#!/bin/sh
python $MONICA_HOME/Examples/Hohenfinow2/pythonrun-consumer.py &
python $MONICA_HOME/Examples/Hohenfinow2/pythonrun-producer.py 
sleep 15

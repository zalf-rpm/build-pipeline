#!/bin/bash
cd ${HERMES_HOME} 
ls -al
xvfb-run -a wine $@
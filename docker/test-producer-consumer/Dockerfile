#Download base image debian 9.5
FROM debian:9.5

ENV DEBIAN_FRONTED noninteractive
# Update Ubuntu Software repository
RUN apt-get update
# install monica prerequisites
RUN apt-get install -y apt-utils
RUN apt-get install -y libboost-all-dev
ENV MONICA_RUN /run/monica
ENV MONICA_HOME /home/monica
ENV MONICA_PARAMETERS ${MONICA_HOME}/monica-parameters
ENV PATH "${MONICA_RUN}:${PATH}"
ENV PYTHONPATH ${MONICA_RUN}
ENV MONICA_RESOURCE ../../../monica
ENV MONICA_PARAMETER_RESOURCE ../../../monica-parameters
ENV UTIL_RESOURCE ../../../util
ENV EXE_RESOURCE ${MONICA_RESOURCE}/_cmake_linux


RUN mkdir -p ${MONICA_RUN}/sqlite-db
RUN mkdir -p ${MONICA_HOME}
RUN mkdir -p ${MONICA_PARAMETERS}
RUN mkdir -p ${MONICA_HOME}/monica-ini-to-json
RUN mkdir -p ${MONICA_HOME}/Examples/Hohenfinow2
RUN mkdir -p ${MONICA_HOME}/Examples/Hohenfinow2/python

# copy executables 
COPY ${EXE_RESOURCE}/monica ${MONICA_RUN}
COPY ${EXE_RESOURCE}/monica-run ${MONICA_RUN}
COPY ${EXE_RESOURCE}/monica-zmq-control-send ${MONICA_RUN}
COPY ${EXE_RESOURCE}/monica-zmq-run ${MONICA_RUN}
COPY ${EXE_RESOURCE}/monica_python.so ${MONICA_RUN}
COPY ${EXE_RESOURCE}/monica-zmq-control ${MONICA_RUN}
COPY ${EXE_RESOURCE}/monica-zmq-proxy ${MONICA_RUN}
COPY ${EXE_RESOURCE}/monica-zmq-server ${MONICA_RUN}

COPY ${MONICA_RESOURCE}/src/python/monica_io.py ${MONICA_RUN}
COPY ${MONICA_RESOURCE}/src/python/ascii_io.py ${MONICA_RUN}
COPY ${UTIL_RESOURCE}/soil/soil_io.py ${MONICA_RUN}

COPY sqlite-db/ka5-soil-data.sqlite ${MONICA_RUN}/sqlite-db/
COPY sqlite-db/carbiocial.sqlite ${MONICA_RUN}/sqlite-db/
COPY sqlite-db/monica.sqlite ${MONICA_RUN}/sqlite-db/

COPY db-connections-install.ini ${MONICA_RUN}/db-connections.ini

COPY ${MONICA_RESOURCE}/src/python/monica-ini-to-json/monica-ini-to-json.py ${MONICA_HOME}/monica-ini-to-json/
COPY ${MONICA_RESOURCE}/src/python/monica-ini-to-json/conversion-template-sim.json ${MONICA_HOME}/monica-ini-to-json/
COPY ${MONICA_RESOURCE}/src/python/monica-ini-to-json/conversion-template-site.json ${MONICA_HOME}/monica-ini-to-json/
COPY ${MONICA_RESOURCE}/src/python/monica-ini-to-json/conversion-template-crop.json ${MONICA_HOME}/monica-ini-to-json/

COPY ${MONICA_PARAMETER_RESOURCE}/crop-residues ${MONICA_PARAMETERS}/
COPY ${MONICA_PARAMETER_RESOURCE}/crops ${MONICA_PARAMETERS}/
COPY ${MONICA_PARAMETER_RESOURCE}/mineral-fertilisers ${MONICA_PARAMETERS}/
COPY ${MONICA_PARAMETER_RESOURCE}/organic-fertilisers ${MONICA_PARAMETERS}/
COPY ${MONICA_PARAMETER_RESOURCE}/general ${MONICA_PARAMETERS}/

COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/crop-min.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/site-min.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/sim-min.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/climate-min.csv ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/crop.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/site.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/sim.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/crop+.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/site+.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/sim+.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/climate.csv ${MONICA_HOME}/Examples/Hohenfinow2/

COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/python ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/pythoncarbiocial.sqlite ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/pythondb-connections.ini ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/pythonrun-monica.py ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/pythonrun-consumer.py ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/pythonrun-producer.py ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_PARAMETER_RESOURCE}/Examples/Hohenfinow2/pythonsite-soil-profile-from-db.json ${MONICA_HOME}/Examples/Hohenfinow2/python/
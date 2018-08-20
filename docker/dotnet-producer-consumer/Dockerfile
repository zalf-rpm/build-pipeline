#build test programm with + dotnet
FROM microsoft/dotnet:2.1-sdk AS build-env
WORKDIR /CoreConsoleParser
# Copy csproj and restore as distinct layers
COPY /build-pipeline/testtools/CoreConsoleParser/CoreConsoleParser/*.csproj ./
RUN dotnet restore

# Copy everything else and build
COPY /build-pipeline/testtools/CoreConsoleParser/CoreConsoleParser/ ./
RUN dotnet publish -c Release -o out -r debian.9-x64

FROM debian:9.5

# Update Ubuntu Software repository
RUN apt-get update
# install monica prerequisites
RUN apt-get install -y apt-utils
RUN apt-get install -y libboost-all-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python-pip python-dev build-essential

ARG EXECUTABLE_SOURCE=monica/_cmake_linux
ENV MONICA_RUN /run/monica
ENV MONICA_HOME /home/monica
ENV MONICA_PARAMETERS ${MONICA_HOME}/monica-parameters
ENV PATH "${MONICA_RUN}:${PATH}"
ENV PYTHONPATH ${MONICA_RUN}
ENV MONICA_RESOURCE monica
ENV MONICA_PARAMETER_RESOURCE monica-parameters
ENV UTIL_RESOURCE util
ENV LINKED_MONICA_SERVICE "localhost"

RUN mkdir -p ${MONICA_RUN}/sqlite-db
RUN mkdir -p ${MONICA_HOME}
RUN mkdir -p ${MONICA_PARAMETERS}
RUN mkdir -p ${MONICA_HOME}/monica-ini-to-json
RUN mkdir -p ${MONICA_HOME}/Examples/Hohenfinow2
RUN mkdir -p ${MONICA_HOME}/Examples/Hohenfinow2/python
RUN mkdir -p ${MONICA_PARAMETERS}/crop-residues
RUN mkdir -p ${MONICA_PARAMETERS}/crops
RUN mkdir -p ${MONICA_PARAMETERS}/mineral-fertilisers
RUN mkdir -p ${MONICA_PARAMETERS}/organic-fertilisers
RUN mkdir -p ${MONICA_PARAMETERS}/general
RUN mkdir -p ${MONICA_HOME}/testing

# copy test programm
COPY --from=build-env /CoreConsoleParser/out ${MONICA_HOME}/testing/
COPY ${MONICA_RESOURCE}/installer/testing/testreference.csv ${MONICA_HOME}/testing/

# copy executables 
COPY ${EXECUTABLE_SOURCE}/monica ${MONICA_RUN}
COPY ${EXECUTABLE_SOURCE}/monica-run ${MONICA_RUN}
COPY ${EXECUTABLE_SOURCE}/monica-zmq-control-send ${MONICA_RUN}
COPY ${EXECUTABLE_SOURCE}/monica-zmq-run ${MONICA_RUN}
COPY ${EXECUTABLE_SOURCE}/monica_python.so ${MONICA_RUN}
COPY ${EXECUTABLE_SOURCE}/monica-zmq-control ${MONICA_RUN}
COPY ${EXECUTABLE_SOURCE}/monica-zmq-proxy ${MONICA_RUN}
COPY ${EXECUTABLE_SOURCE}/monica-zmq-server ${MONICA_RUN}

COPY ${MONICA_RESOURCE}/src/python/monica_io.py ${MONICA_RUN}
COPY ${MONICA_RESOURCE}/src/python/ascii_io.py ${MONICA_RUN}
COPY ${UTIL_RESOURCE}/soil/soil_io.py ${MONICA_RUN}

COPY ${MONICA_RESOURCE}/sqlite-db/ka5-soil-data.sqlite ${MONICA_RUN}/sqlite-db/
COPY ${MONICA_RESOURCE}/sqlite-db/carbiocial.sqlite ${MONICA_RUN}/sqlite-db/
COPY ${MONICA_RESOURCE}/sqlite-db/monica.sqlite ${MONICA_RUN}/sqlite-db/

COPY ${MONICA_RESOURCE}/db-connections-install.ini ${MONICA_RUN}/db-connections.ini

COPY ${MONICA_RESOURCE}/src/python/monica-ini-to-json/monica-ini-to-json.py ${MONICA_HOME}/monica-ini-to-json/
COPY ${MONICA_RESOURCE}/src/python/monica-ini-to-json/conversion-template-sim.json ${MONICA_HOME}/monica-ini-to-json/
COPY ${MONICA_RESOURCE}/src/python/monica-ini-to-json/conversion-template-site.json ${MONICA_HOME}/monica-ini-to-json/
COPY ${MONICA_RESOURCE}/src/python/monica-ini-to-json/conversion-template-crop.json ${MONICA_HOME}/monica-ini-to-json/

COPY ${MONICA_PARAMETER_RESOURCE}/crop-residues/ ${MONICA_PARAMETERS}/crop-residues/
COPY ${MONICA_PARAMETER_RESOURCE}/crops/ ${MONICA_PARAMETERS}/crops/
COPY ${MONICA_PARAMETER_RESOURCE}/mineral-fertilisers/ ${MONICA_PARAMETERS}/mineral-fertilisers/
COPY ${MONICA_PARAMETER_RESOURCE}/organic-fertilisers/ ${MONICA_PARAMETERS}/organic-fertilisers/
COPY ${MONICA_PARAMETER_RESOURCE}/general/ ${MONICA_PARAMETERS}/general/

RUN ls -la /${MONICA_PARAMETERS}/*

COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/crop-min.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/site-min.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/sim-min.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/climate-min.csv ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/crop.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/site.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/sim.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/crop+.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/site+.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/sim+.json ${MONICA_HOME}/Examples/Hohenfinow2/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/climate.csv ${MONICA_HOME}/Examples/Hohenfinow2/

COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/python ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/python/carbiocial.sqlite ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/python/db-connections.ini ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/python/run-monica.py ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/python/run-consumer.py ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/python/run-producer.py ${MONICA_HOME}/Examples/Hohenfinow2/python/
COPY ${MONICA_RESOURCE}/installer/Hohenfinow2/python/site-soil-profile-from-db.json ${MONICA_HOME}/Examples/Hohenfinow2/python/

RUN pip install zmq

COPY ./build-pipeline/docker/test-producer-consumer/start_producer_consumer.sh /start.sh

CMD ["./start.sh"]
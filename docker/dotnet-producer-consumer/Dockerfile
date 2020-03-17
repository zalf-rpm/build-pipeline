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
#RUN apt-get install -y apt-utils
#RUN apt-get install -y libboost-all-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y git python-pip python-dev build-essential

RUN mkdir /checkout
 
ENV MONICA_RESOURCE /checkout/monica
ENV MONICA_PARAMETER_RESOURCE /checkout/monica-parameters
ENV UTIL_RESOURCE /checkout/util

WORKDIR /checkout

RUN git clone https://github.com/zalf-rpm/monica.git
RUN git clone https://github.com/zalf-rpm/util.git
RUN git clone https://github.com/zalf-rpm/monica-parameters.git

WORKDIR /

ENV MONICA_RUN /run/monica
ENV MONICA_HOME /home/monica
ENV MONICA_PARAMETERS ${MONICA_HOME}/monica-parameters
ENV PATH "${MONICA_RUN}:${PATH}"
ENV PYTHONPATH ${MONICA_RUN}

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
RUN chmod a+x ${MONICA_HOME}/testing/CoreConsoleParser
RUN cp ${MONICA_RESOURCE}/installer/testing/testreference.csv ${MONICA_HOME}/testing/
RUN touch ${MONICA_HOME}/testing/1.csv
RUN chmod a+w ${MONICA_HOME}/testing/1.csv

RUN cp ${MONICA_RESOURCE}/src/python/monica_io.py ${MONICA_RUN}
RUN cp ${MONICA_RESOURCE}/src/python/ascii_io.py ${MONICA_RUN}
RUN cp ${UTIL_RESOURCE}/soil/soil_io.py ${MONICA_RUN}

RUN cp ${MONICA_RESOURCE}/sqlite-db/ka5-soil-data.sqlite ${MONICA_RUN}/sqlite-db/
RUN cp ${MONICA_RESOURCE}/sqlite-db/carbiocial.sqlite ${MONICA_RUN}/sqlite-db/
RUN cp ${MONICA_RESOURCE}/sqlite-db/monica.sqlite ${MONICA_RUN}/sqlite-db/

RUN cp ${MONICA_RESOURCE}/db-connections-install.ini ${MONICA_RUN}/db-connections.ini

RUN cp ${MONICA_RESOURCE}/src/python/monica-ini-to-json/monica-ini-to-json.py ${MONICA_HOME}/monica-ini-to-json/
RUN cp ${MONICA_RESOURCE}/src/python/monica-ini-to-json/conversion-template-sim.json ${MONICA_HOME}/monica-ini-to-json/
RUN cp ${MONICA_RESOURCE}/src/python/monica-ini-to-json/conversion-template-site.json ${MONICA_HOME}/monica-ini-to-json/
RUN cp ${MONICA_RESOURCE}/src/python/monica-ini-to-json/conversion-template-crop.json ${MONICA_HOME}/monica-ini-to-json/

RUN cp -r ${MONICA_PARAMETER_RESOURCE}/crop-residues/ ${MONICA_PARAMETERS}
RUN cp -r ${MONICA_PARAMETER_RESOURCE}/crops/ ${MONICA_PARAMETERS}
RUN cp -r ${MONICA_PARAMETER_RESOURCE}/mineral-fertilisers/ ${MONICA_PARAMETERS}
RUN cp -r ${MONICA_PARAMETER_RESOURCE}/organic-fertilisers/ ${MONICA_PARAMETERS}
RUN cp -r ${MONICA_PARAMETER_RESOURCE}/general/ ${MONICA_PARAMETERS}

RUN ls -la /${MONICA_PARAMETERS}/*

RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/crop-min.json ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/site-min.json ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/sim-min.json ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/climate-min.csv ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/crop.json ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/site.json ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/sim.json ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/crop+.json ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/site+.json ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/sim+.json ${MONICA_HOME}/Examples/Hohenfinow2/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/climate.csv ${MONICA_HOME}/Examples/Hohenfinow2/

RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/python/carbiocial.sqlite ${MONICA_HOME}/Examples/Hohenfinow2/python/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/python/db-connections.ini ${MONICA_HOME}/Examples/Hohenfinow2/python/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/python/run-monica.py ${MONICA_HOME}/Examples/Hohenfinow2/python/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/python/run-consumer.py ${MONICA_HOME}/Examples/Hohenfinow2/python/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/python/run-producer.py ${MONICA_HOME}/Examples/Hohenfinow2/python/
RUN cp ${MONICA_RESOURCE}/installer/Hohenfinow2/python/site-soil-profile-from-db.json ${MONICA_HOME}/Examples/Hohenfinow2/python/

RUN pip install zmq

COPY ./build-pipeline/docker/dotnet-producer-consumer/start_producer_consumer.sh /start.sh

CMD ["./start.sh"]
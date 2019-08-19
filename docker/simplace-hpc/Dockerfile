#Download base image alpine 3.10
FROM golang:1.11.13-alpine3.10 AS build-env

RUN apk update && apk add --no-cache binutils git curl unzip tar

WORKDIR /go/src/zalf-rpm
RUN git clone https://github.com/zalf-rpm/build-pipeline.git

WORKDIR /go/src/zalf-rpm/build-pipeline/hpc/simplace/splitsimplaceproj
RUN go build -v 
WORKDIR /go/src/zalf-rpm/build-pipeline/hpc/simplace/accumulate_output
RUN go build -v -o accumulate_output

FROM amd64/openjdk:8u181-jre-alpine

ARG EXECUTABLE_SOURCE="/simplace_exe"

RUN apk update && apk add --no-cache binutils bash

RUN mkdir -p /splitsimplaceproj
COPY --from=build-env /go/src/zalf-rpm/build-pipeline/hpc/simplace/splitsimplaceproj/splitsimplaceproj /splitsimplaceproj/
COPY --from=build-env /go/src/zalf-rpm/build-pipeline/hpc/simplace/accumulate_output/accumulate_output /accumulate_output/
RUN chmod -R 555 /splitsimplaceproj
RUN chmod -R 555 /accumulate_output

ENV SIMPLACE_DIR=/simplace

#mountpoints
ENV SIMPLACE_WORKDIR=/simplace/SIMPLACE_WORK
ENV OUTDIR=/outputs
ENV DATADIR=/data
ENV PROJECTDIR=/projects 

RUN mkdir -p /simplace/SIMPLACE_WORK
RUN mkdir -p /outputs
RUN mkdir -p /data
RUN mkdir -p /projects

COPY ${EXECUTABLE_SOURCE} ${SIMPLACE_DIR}
RUN chmod -R 777 ${SIMPLACE_DIR}
RUN find ${SIMPLACE_DIR} -type f -exec chmod 555 {} +

COPY ./build-pipeline/docker/simplace-hpc/simplace_start.sh /simplace_start.sh
RUN chmod -R 555 /simplace_start.sh

RUN addgroup -S mygroup && adduser -S myuser -G mygroup
USER myuser

RUN ls -alR /simplace
RUN ls -alR /splitsimplaceproj

#ENTRYPOINT ["/simplace_start.sh"]
CMD ["/bin/bash"]

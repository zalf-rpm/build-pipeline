# build helper tools for simplace on HPC
# to split and merge big simplace project batch files 
#Download base image alpine 3.10
FROM golang:1.19.1-alpine3.16 AS build-env

RUN apk update && apk add --no-cache binutils git curl unzip tar

# zalf helper tools
WORKDIR /go/src/zalf-rpm
RUN git clone https://github.com/zalf-rpm/build-pipeline.git

WORKDIR /go/src/zalf-rpm/build-pipeline
# get version info from git
RUN git describe --always --long > /version.txt

# build tool to split up big project files
WORKDIR /go/src/zalf-rpm/build-pipeline/hpc/simplace/splitsimplaceproj
RUN go mod init
RUN go mod tidy
RUN VERSION=$(cat /version.txt) && go build -v -ldflags "-X main.version=${VERSION}"

# build tool to merge output files from different folders into one
WORKDIR /go/src/zalf-rpm/build-pipeline/hpc/simplace/accumulate_output
RUN go mod init
RUN go mod tidy
RUN VERSION=$(cat /version.txt) && go build -v -ldflags "-X main.version=${VERSION}" -o accumulate_output

#TODO: would be nice to compile simplace under linux here


# build image with OpenJDK and simplace
FROM alpine:3.16

# OpenJDK with mircosoft libs

ENV JAVA_HOME=/usr/lib/jdk
ENV PATH=${PATH}:${JAVA_HOME}/bin

# Default to UTF-8 file.encoding
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

# (Optional) Add extra packages for fontconfig and ttf-dejavu to support server-side image generation
RUN apk add --no-cache fontconfig libretls musl-locales musl-locales-lang ttf-dejavu tzdata zlib \
    && rm -rf /var/cache/apk/*

# Download and extract JDK 17
RUN wget -nv -O jdk.tar.gz https://aka.ms/download-jdk/microsoft-jdk-17-alpine-x64.tar.gz && \
    mkdir $JAVA_HOME && \
    tar xf jdk.tar.gz -C $JAVA_HOME --strip-components 1 --no-same-owner \
    && rm jdk.tar.gz

# read command line argument where to find precompiled simplace
ARG EXECUTABLE_SOURCE="simplace_exe"

RUN apk update && apk add --no-cache binutils bash

# copy helper tools 
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

# create folders to mount run data for simplace
RUN mkdir -p /simplace/SIMPLACE_WORK
RUN mkdir -p /data
RUN mkdir -p /projects
RUN mkdir -p /outputs

# copy pre-build executable
COPY ${EXECUTABLE_SOURCE} ${SIMPLACE_DIR}
RUN chmod -R 777 ${SIMPLACE_DIR}
RUN find ${SIMPLACE_DIR} -type f -exec chmod 555 {} +

# use more memory 
WORKDIR ${SIMPLACE_DIR}
RUN sed -i 's/-Xmx10g/-Xmx30g/g' simplace

# copy start script
WORKDIR /
COPY ./simplace_start.sh /simplace_start.sh
RUN chmod -R 555 /simplace_start.sh

RUN addgroup -S mygroup && adduser -S myuser -G mygroup
USER myuser

# list installed files
RUN ls -alR /simplace
RUN ls -alR /splitsimplaceproj

#ENTRYPOINT ["/simplace_start.sh"]
CMD ["/bin/bash"]

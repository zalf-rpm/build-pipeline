#Download base image alpine 3.10
FROM golang:1.19.1-alpine3.16 AS build-env

RUN apk update && apk add --no-cache binutils git curl unzip tar

WORKDIR /go/src/zalf-rpm
RUN git clone https://github.com/zalf-rpm/build-pipeline.git

WORKDIR /go/src/zalf-rpm/build-pipeline
RUN git describe --always --long > /version.txt
WORKDIR /go/src/zalf-rpm/build-pipeline/hpc/simplace/splitsimplaceproj
RUN go mod init
RUN go mod tidy
RUN VERSION=$(cat /version.txt) && go build -v -ldflags "-X main.version=${VERSION}"
WORKDIR /go/src/zalf-rpm/build-pipeline/hpc/simplace/accumulate_output
RUN go mod init
RUN go mod tidy
RUN VERSION=$(cat /version.txt) && go build -v -ldflags "-X main.version=${VERSION}" -o accumulate_output


FROM alpine:3.16

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
    tar xf jdk.tar.gz -C $JAVA_HOME --strip-components 1 --no-same-owner


ARG EXECUTABLE_SOURCE="simplace_exe"

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

COPY ./simplace_start.sh /simplace_start.sh
RUN chmod -R 555 /simplace_start.sh

RUN addgroup -S mygroup && adduser -S myuser -G mygroup
USER myuser

RUN ls -alR /simplace
RUN ls -alR /splitsimplaceproj

#ENTRYPOINT ["/simplace_start.sh"]
CMD ["/bin/bash"]

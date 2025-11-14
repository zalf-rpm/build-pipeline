FROM golang:1.25.4-alpine3.22 AS build-env

RUN apk update && apk add --no-cache git

WORKDIR /usr/src

RUN git clone https://github.com/zalf-rpm/build-pipeline.git
WORKDIR /usr/src/build-pipeline/rundeck/varservice

RUN go mod download && go mod verify

RUN go build -v -o varservice 

FROM alpine:3.22

COPY --from=build-env /usr/src/build-pipeline/rundeck/varservice/varservice /usr/bin/

WORKDIR /usr/bin

EXPOSE 6080

CMD ["varservice"]
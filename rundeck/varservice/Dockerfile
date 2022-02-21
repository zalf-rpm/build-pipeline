FROM golang:1.17-alpine3.14 AS build-env

RUN apk update && apk add --no-cache git

WORKDIR /usr/src

RUN git clone https://github.com/zalf-rpm/build-pipeline.git
WORKDIR /usr/src/rundeck/varservice

RUN go mod download && go mod verify

RUN go build -v -o varservice 

FROM alpine3.14

COPY --from=build-env /usr/src/rundeck/varservice/varservice /usr/bin/

WORKDIR /usr/bin

EXPOSE 6080

CMD ["varservice"]
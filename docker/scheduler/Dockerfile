FROM golang:stretch

WORKDIR /go/src/sim_schedule
COPY rundeck/sim_schedule .

RUN go get -d -v 
RUN go install -v 


ENV EXECDIR /simulation
RUN chmod -R 777 ${EXECDIR}

CMD ["sim_schedule"]
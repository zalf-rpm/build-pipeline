FROM golang:stretch

RUN apt-get update 
RUN apt-get install -y apt-utils
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common 

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN apt-key fingerprint 0EBFCD88

RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian stretch stable"
   
RUN apt-get update 
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install docker-ce docker-ce-cli containerd.io
RUN rm -rf /var/lib/apt/lists/*

WORKDIR /go/src/sim_schedule
COPY rundeck/sim_schedule .

RUN go get -d -v 
RUN go install -v 

ENV USERID 0
ENV GROUPID 0

RUN docker --version

ENV SIMDIR /simulation/run
ENV EXECDIR ${SIMDIR}/project
RUN mkdir -p ${SIMDIR}
RUN chmod -R 777 /simulation

COPY ./docker/scheduler/start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]

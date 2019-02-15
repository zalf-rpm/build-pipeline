FROM golang:stretch

WORKDIR /go/src/sim_schedule
COPY rundeck/sim_schedule .

RUN go get -d -v 
RUN go install -v 

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

RUN docker --version

ENV EXECDIR /simulation
RUN mkdir ${EXECDIR}
RUN chmod -R 777 ${EXECDIR}

CMD ["sim_schedule"]
FROM debian:9.5

ENV DEBIAN_FRONTEND noninteractive

# Install some tools required for creating the image
RUN apt-get update \
	&& apt-get install -y --no-install-recommends curl unzip ca-certificates

# Install wine with 32 support, because HERMES is a 32 bit application
RUN dpkg --add-architecture i386 \
		&& apt-get update \
		&& apt-get install -y --no-install-recommends wine wine32 

# Install display redirect
RUN apt-get install -y xvfb 
RUN rm -rf /var/lib/apt/lists/*

ENV HERMES_HOME hermes/run

RUN mkdir -p ${HERMES_HOME}
RUN chmod -R 777 ${HERMES_HOME}

COPY ./docker/hermes-cluster/start_hermes.sh /start.sh
RUN chmod +x ./start.sh

CMD ["./start.sh"]

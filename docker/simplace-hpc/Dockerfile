FROM amd64/openjdk:8u181-jre-slim

ARG EXECUTABLE_SOURCE="/simplace_exe"

ENV SIMPLACE_DIR=/simplace

#mountpoints
ENV SIMPLACE_WORKDIR=/simplace/SIMPLACE_WORK
ENV OUTDIR=/output
ENV DATADIR=/data
ENV PROJECTDIR=/projects 

RUN mkdir -p /simplace/SIMPLACE_WORK
RUN mkdir -p /output
RUN mkdir -p /data
RUN mkdir -p /projects

COPY ${EXECUTABLE_SOURCE} ${SIMPLACE_DIR}
RUN chmod -R 777 ${SIMPLACE_DIR}
RUN find ${SIMPLACE_DIR} -type f -exec chmod 555 {} +

COPY ./build-pipeline/docker/simplace-hpc/simplace_start.sh /simplace_start.sh
RUN chmod -R 555 /simplace_start.sh

RUN useradd -ms /bin/bash myuser
USER myuser

RUN ls -alR /simplace

ENTRYPOINT ["/simplace_start.sh"]
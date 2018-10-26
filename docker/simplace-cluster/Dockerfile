FROM amd64/openjdk:8u181-jre

ARG EXECSOURCE="/simplace_exe"
ENV EXECDIR /simplace
ENV WORKDIR /simplace/SIMPLACE_WORK
ENV OUTPUTDIR /output
ENV DATADIR /data 
ENV PROJECT "path/to/projectfile.proj.xml"
ENV SOLUTION "path/to/solution.sol.xml"
ENV LINE_START 1
ENV LINE_END 1
ENV TESTRUN "false"

COPY ${EXECSOURCE} ${EXECDIR}

RUN chmod +x ${EXECDIR}/simplace
COPY ./docker/simplace-cluster/simplace_start.sh /start.sh

RUN ls -al /simplace/*

CMD ["./start.sh"]
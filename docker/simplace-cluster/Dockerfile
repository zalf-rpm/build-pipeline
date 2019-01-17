FROM amd64/openjdk:8u181-jre-stretch

ARG EXECSOURCE="/simplace_exe"
ENV EXECDIR /simplace
ENV WORKDIR $EXECDIR/SIMPLACE_WORK
ENV OUTPUTDIR $EXECDIR/output
ENV DATADIR $EXECDIR/data
ENV PROJECTDIR $EXECDIR/projects 

ENV PROJECT "path/to/projectfile.proj.xml"
ENV SOLUTION "path/to/solution.sol.xml"
ENV LINE_START 1
ENV LINE_END 1
ENV TESTRUN "false"
ENV DEBUG "false"

COPY ${EXECSOURCE} ${EXECDIR}

RUN rm -rf $EXECDIR/simplace.exe
RUN rm -rf $EXECDIR/SIMPLACE_WORK

RUN chmod -R 777 ${EXECDIR}

COPY ./docker/simplace-cluster/simplace_start.sh /start.sh

RUN ls -alR /simplace

CMD ["./start.sh"]
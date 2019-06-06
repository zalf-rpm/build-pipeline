FROM amd64/openjdk:8u181-jre-stretch

RUN apt-get update && apt-get install -y subversion \
    && rm -rf /var/lib/apt/lists/*

ARG EXECSOURCE="/simplace_exe"

ENV EXECDIR /simplace
#mountpoints
ENV SIMPLACE_WORKDIR $EXECDIR/SIMPLACE_WORK
ENV OUTPUTDIR $EXECDIR/output
ENV ZIP_OUTPUTDIR $EXECDIR/output_final
ENV DATADIR $EXECDIR/data
ENV PROJECTDIR $EXECDIR/projects 

#execution parameters
ENV DO_ZIP=true
ENV PROJECT "path/to/projectfile.proj.xml"
ENV SOLUTION "path/to/solution.sol.xml"
ENV LINE_START 1
ENV LINE_END 1
ENV TESTRUN "false"
ENV DEBUG "false"
ENV FINAL_OUT_NAME "none"

RUN mkdir -p ${EXECDIR}
COPY ${EXECSOURCE} ${EXECDIR}
RUN rm -rf $EXECDIR/simplace.exe
RUN rm -rf $EXECDIR/SIMPLACE_WORK

RUN mkdir -p ${SIMPLACE_WORKDIR}
RUN mkdir -p ${OUTPUTDIR}
RUN mkdir -p ${ZIP_OUTPUTDIR}
RUN mkdir -p ${DATADIR}
RUN mkdir -p ${PROJECTDIR}

RUN chmod -R 777 ${EXECDIR}
RUN find ${EXECDIR} -type f -exec chmod 555 {} +

COPY ./docker/simplace-hpc/simplace_start.sh /start.sh

RUN ls -alR /simplace

ENTRYPOINT ["/start.sh"]
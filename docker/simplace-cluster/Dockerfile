FROM amd64/openjdk:8u181-jre-stretch

RUN apt-get update && apt-get install -y subversion \
    && rm -rf /var/lib/apt/lists/*

ARG EXECSOURCE="/simplace_exe"
ENV EXECDIR /simplace
ENV SIMPLACE_SOURCEDIR $EXECDIR/source
ENV SIMPLACE_WORKDIR $EXECDIR/SIMPLACE_WORK
ENV OUTPUTDIR $EXECDIR/output
ENV FINAL_OUTPUTDIR $EXECDIR/output_final
ENV FINAL_OUT_NAME "none"
ENV DATADIR $EXECDIR/data
ENV PROJECTDIR $EXECDIR/projects 
ENV SVN_CHECKOUT_PATH "none"
ENV SVN_USER "none"
ENV SVN_PASSWORD "none"


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
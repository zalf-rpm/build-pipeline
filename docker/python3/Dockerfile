FROM continuumio/miniconda3:4.10.3-alpine

ENV CONDA_DIR="/opt/conda"
ENV PATH="$CONDA_DIR/bin:$PATH"
RUN conda update -n base -c defaults conda
RUN $CONDA_DIR/bin/conda install -c conda-forge cartopy=0.20.3
RUN $CONDA_DIR/bin/conda install -c conda-forge netcdf4
RUN $CONDA_DIR/bin/conda install -c conda-forge pyzmq
RUN $CONDA_DIR/bin/conda install -c conda-forge nco
RUN $CONDA_DIR/bin/conda clean -y --all

# add git
RUN apk add git && \
    apk add gcc && \
    apk add wget && \
    rm -rf /var/cache/apk/* 

COPY ./python_version.sh /start.sh

CMD ["./start.sh"]
FROM continuumio/miniconda3:23.5.2-0-alpine

ENV CONDA_DIR="/opt/conda"
ENV PATH="$CONDA_DIR/bin:$PATH"
RUN conda update -n base -c defaults conda
RUN $CONDA_DIR/bin/conda install -c conda-forge cartopy
RUN $CONDA_DIR/bin/conda install -c conda-forge netcdf4
RUN $CONDA_DIR/bin/conda install -c conda-forge pyzmq
RUN $CONDA_DIR/bin/conda install -c conda-forge nco
RUN $CONDA_DIR/bin/conda clean -y --index-cache
RUN $CONDA_DIR/bin/conda install --solver=classic conda-forge::conda-libmamba-solver conda-forge::libmamba conda-forge::libmambapy conda-forge::libarchive
RUN $CONDA_DIR/bin/conda install -c conda-forge seaborn
RUN $CONDA_DIR/bin/conda clean -y --all

# add git
RUN apk add git && \
    apk add gcc && \
    apk add wget && \
    rm -rf /var/cache/apk/* 

COPY ./python_version.sh /start.sh

CMD ["./start.sh"]
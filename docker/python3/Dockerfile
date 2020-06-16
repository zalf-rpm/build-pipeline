FROM continuumio/miniconda3:4.7.12-alpine

ENV CONDA_DIR="/opt/conda"
ENV PATH="$CONDA_DIR/bin:$PATH"
RUN $CONDA_DIR/bin/conda install -c conda-forge cartopy
RUN $CONDA_DIR/bin/conda install -c conda-forge netcdf4
RUN $CONDA_DIR/bin/conda install -c conda-forge pyzmq
RUN $CONDA_DIR/bin/conda install -c conda-forge nco

COPY ./python_version.sh /start.sh

CMD ["./start.sh"]
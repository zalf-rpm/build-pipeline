FROM r-base:3.6.3

RUN R -e 'install.packages("chron")'
RUN R -e 'install.packages("RColorBrewer")'
RUN R -e 'install.packages("lattice")'
RUN R -e 'install.packages("ncdf4")'

CMD ["R", "--version"]
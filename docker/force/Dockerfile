FROM davidfrantz/force:3.7.12
RUN id -un
USER root

RUN mkdir -p /var/cache/apt/archives/partial

RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && apt-get update -y && apt-get install google-cloud-sdk -y
 
USER docker

WORKDIR /home/docker

CMD ["force"]
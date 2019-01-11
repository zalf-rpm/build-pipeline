FROM python:3.6-stretch

# install dependencies 
RUN pip install selenium
RUN pip install nose
RUN pip install splinter==0.7.7

RUN apt-get update
RUN apt-get install -y apt-utils 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils 

# install chromium
ARG CHROME_VERSION="google-chrome-stable"
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
  && apt-get update -qqy \
  && apt-get -qqy install \
    ${CHROME_VERSION:-google-chrome-stable} \
  && rm /etc/apt/sources.list.d/google-chrome.list \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*
  
RUN mkdir -p /browserdriver
ARG CHROME_DRIVER_VERSION="latest"
RUN CD_VERSION=$(if [ ${CHROME_DRIVER_VERSION:-latest} = "latest" ]; then echo $(wget -qO- https://chromedriver.storage.googleapis.com/LATEST_RELEASE); else echo $CHROME_DRIVER_VERSION; fi) \
  && echo "Using chromedriver version: "$CD_VERSION \
  && wget --no-verbose -O /tmp/chromedriver_linux64.zip https://chromedriver.storage.googleapis.com/$CD_VERSION/chromedriver_linux64.zip \
  && rm -rf /browserdriver/chromedriver \
  && unzip /tmp/chromedriver_linux64.zip -d /browserdriver \
  && rm /tmp/chromedriver_linux64.zip \
  && mv /browserdriver/chromedriver /browserdriver/chromedriver-$CD_VERSION \
  && chmod 755 /browserdriver/chromedriver-$CD_VERSION \
  && ln -fs /browserdriver/chromedriver-$CD_VERSION /usr/bin/chromedriver

# copy the web test
RUN mkdir web_test
COPY bonares_portal web_test/bonares_portal
COPY datacentre_site web_test/datacentre_site
COPY dataportal web_test/dataportal
COPY src web_test/src
COPY test_data web_test/test_data
COPY tools web_test/tools
COPY run_dataportal_availability_tests.py web_test
COPY run_tests.py web_test
COPY __init__.py web_test

WORKDIR /web_test

RUN ls -al 
RUN echo $PATH

# run web test
CMD [ "python", "./run_tests.py" ]
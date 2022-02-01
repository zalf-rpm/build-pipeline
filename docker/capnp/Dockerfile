FROM debian:bullseye

RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y build-essential
RUN gcc --version

ENV TEMP_DIR="/tmp/capnproto"
# download
ARG VERSION="0.9.1"
ENV URL="https://capnproto.org/capnproto-c++-$VERSION.tar.gz"
RUN echo "Downloading Cap'n Proto form $URL ..."; \
	mkdir -p "$TEMP_DIR" \
	&& curl "$URL" \
	| tar -xz -C "$TEMP_DIR"
WORKDIR $TEMP_DIR/capnproto-c++-$VERSION

# configure
ARG CONFIGURE_CMD="./configure "
RUN echo "Configuring Cap'n Proto source ($CONFIGURE_CMD)..." \
	&& eval "$CONFIGURE_CMD"
# make check
ARG BUILD_CMD="make -j6 check"
RUN echo "Building Cap'n Proto ($BUILD_CMD)..." \
	&& eval "$BUILD_CMD"
# make install
ARG INSTALL_CMD="make install"
RUN echo "Installing Cap'n Proto ($INSTALL_CMD)..." \
	&& eval "$INSTALL_CMD"

WORKDIR /
# cleanup
RUN echo "Cleaning up after Cap'n Proto installation..." \
	&& rm -rf "$TEMP_DIR"

RUN useradd -ms /bin/bash myuser
USER myuser

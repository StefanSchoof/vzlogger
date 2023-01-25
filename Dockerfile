############################
# STEP 1 build executable binary
############################

FROM alpine:latest as builder

RUN apt-get update && apt-get install -y \
    build-essential \
    git-core \
    cmake \
    pkg-config \
    libcurl4-openssl-dev \
    libgnutls28-dev \
    libsasl2-dev \
    uuid-dev \
    libtool \
    libgcrypt-dev \
    libmicrohttpd-dev \
    json-c-dev \
    mosquitto-dev \
    libunistring-dev \
    automake \
    autoconf

WORKDIR /vzlogger

RUN git clone https://github.com/volkszaehler/libsml.git --depth 1 \
    && make install -C libsml/sml

RUN git clone https://github.com/rscada/libmbus.git --depth 1 \
    && cd libmbus \
    && ./build.sh \
    && make install

COPY . /vzlogger

ARG build_test=off
RUN cmake -DBUILD_TEST=${build_test} \
    && make \
    && make install \
    && if [ "$build_test" = "on" ]; then make test; fi


#############################
## STEP 2 build a small image
#############################

FROM alpine:latest

LABEL Description="vzlogger"

RUN apt-get update && apt-get install -y \
    libcurl4 \
    libgnutls30 \
    libsasl2-2  \
    libuuid1 \
    libssl1.1 \
    libgcrypt20  \
    libmicrohttpd12 \
    libltdl7 \
    libatomic1 \
    libjson-c3 \
    liblept5 \
    libmosquitto1 \
    libunistring2 \
    && rm -rf /var/lib/apt/lists/*

# libsml is linked statically => no need to copy
COPY --from=builder /usr/local/bin/vzlogger /usr/local/bin/vzlogger
COPY --from=builder /usr/local/lib/libmbus.so* /usr/local/lib/

# without running a user context, no exec is possible and without the dialout group no access to usb ir reader possible
RUN adduser -S vz -G dialout

RUN vzlogger --version

USER vz
CMD ["vzlogger", "--foreground"]

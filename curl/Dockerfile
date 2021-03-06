# Multi-stage build: First the full builder image:

# define the ip adress of the server being tested. this is needed to add the server ip and server name ("testserver") to /etc/hosts.
ARG TESTSERVER_IP=192.168.0.10
ARG TESTSERVER_NAME=testserver

# define the Curl version to be baked in
ARG CURL_VERSION=7.69.1

# Default location where all binaries wind up:
ARG INSTALLDIR=/opt/oqssa

# liboqs build defines (https://github.com/open-quantum-safe/liboqs/wiki/Customizing-liboqs)
ARG LIBOQS_BUILD_DEFINES="-DOQS_ENABLE_KEM_BIKE=OFF -DOQS_ENABLE_KEM_FRODOKEM=OFF -DOQS_ENABLE_KEM_SIKE=OFF -DOQS_ENABLE_KEM_SIDH=OFF -DOQS_ENABLE_SIG_PICNIC=OFF -DOQS_ENABLE_KEM_CLASSIC_MCELIECE=ON -DOQS_ENABLE_KEM_HQC=OFF -DOQS_ENABLE_KEM_KYBER=ON -DOQS_ENABLE_KEM_NTRU=ON -DOQS_ENABLE_KEM_SABER=ON -DOQS_ENABLE_SIG_DILITHIUM=ON -DOQS_ENABLE_SIG_FALCON=ON -DOQS_ENABLE_SIG_RAINBOW=ON -DOQS_ENABLE_SIG_SPHINCS=OFF"

# openssl build defines (https://github.com/open-quantum-safe/openssl#build-options)
ARG OPENSSL_BUILD_DEFINES="-DOQS_DEFAULT_GROUPS=X25519:kyber512:kyber768:kyber1024:kyber90s512:kyber90s768:kyber90s1024:lightsaber:saber:firesaber:ntru_hps2048509:ntru_hps2048677:ntru_hps4096821:ntru_hrss701"

# Default root CA signature algorithm; can be set to any listed at https://github.com/open-quantum-safe/openssl#authentication
ARG SIG_ALG="dilithium2"

# Define the degree of parallelism when building the image; leave the number away only if you know what you are doing
ARG MAKE_DEFINES="-j 2"


FROM alpine:3.11 as intermediate
# Take in all global args
ARG CURL_VERSION
ARG INSTALLDIR
ARG LIBOQS_BUILD_DEFINES
ARG OPENSSL_BUILD_DEFINES
ARG SIG_ALG
ARG MAKE_DEFINES
ARG TESTSERVER_IP
ARG TESTSERVER_NAME

LABEL version="2"

ENV DEBIAN_FRONTEND noninteractive

RUN apk update && apk upgrade

# Get all software packages required for builing all components:
RUN apk add build-base linux-headers \
            libtool automake autoconf cmake ninja \
            make \
            openssl openssl-dev \
            git docker wget

# get all sources
WORKDIR /opt
RUN git clone --depth 1 --branch main https://github.com/open-quantum-safe/liboqs && \
    git clone --depth 1 --branch OQS-OpenSSL_1_1_1-stable https://github.com/open-quantum-safe/openssl ossl-src && \
    wget https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz && tar -zxvf curl-${CURL_VERSION}.tar.gz;

# Add curl patchfile
ADD patch-${CURL_VERSION}.oqs.txt /opt/patch-${CURL_VERSION}.oqs.txt

# build liboqs shared and static
WORKDIR /opt/liboqs
RUN mkdir build && cd build && cmake -G"Ninja" .. ${LIBOQS_BUILD_DEFINES} -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/opt/ossl-src/oqs && ninja install
RUN mkdir build-static && cd build-static && cmake -G"Ninja" .. -DCMAKE_BUILD_TYPE=${LIBOQS_BUILD_TYPE} -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/opt/ossl-src/oqs && ninja install

# build OQS-OpenSSL
WORKDIR /opt/ossl-src
# curl looks for shared libraries
# at ./configure time
RUN LDFLAGS="-Wl,-rpath -Wl,${INSTALLDIR}/lib" ./config shared ${OPENSSL_BUILD_DEFINES} --prefix=${INSTALLDIR} && \
    make ${MAKE_DEFINES} && make install;

# set path to use 'new' openssl & curl. Dyn libs have been properly linked in to match
ENV PATH="${INSTALLDIR}/bin:${PATH}"

# generate certificates for openssl s_server, which is what we will test curl against
ENV OPENSSL=${INSTALLDIR}/bin/openssl
ENV OPENSSL_CNF=${INSTALLDIR}/ssl/openssl.cnf

WORKDIR ${INSTALLDIR}/bin
# generate CA key and cert
RUN set -x && \
    ${OPENSSL} req -x509 -new -newkey ${SIG_ALG} -keyout CA.key -out CA.crt -nodes -subj "/CN=oqstest CA" -days 365 -config ${OPENSSL_CNF}

#instead of generating key and cert, copy the already existing 
#COPY CA.crt ${INSTALLDIR}/bin
#COPY CA.key ${INSTALLDIR}/bin

# build curl - injecting OQS CA generated above into root store
WORKDIR /opt/curl-${CURL_VERSION}
RUN patch -p1 < /opt/patch-${CURL_VERSION}.oqs.txt

# Download and integrate LetsEncrypt Root CA to CA bundle
RUN wget https://letsencrypt.org/certs/letsencryptauthorityx3.pem.txt && cat ${INSTALLDIR}/bin/CA.crt >> letsencryptauthorityx3.pem.txt 

# For curl debugging enable it by adding the line below to the configure command:
#                    --enable-debug \

RUN env CPPFLAGS="-I/opt/ossl-src/oqs/include" \
        LDFLAGS=-Wl,-R${INSTALLDIR}/lib  \
        ./configure --prefix=${INSTALLDIR} \
                    --with-ca-bundle=${INSTALLDIR}/oqs-bundle.pem \
                    --with-ssl=${INSTALLDIR} && \
    make ${MAKE_DEFINES} && make install && mv letsencryptauthorityx3.pem.txt ${INSTALLDIR}/oqs-bundle.pem;

# Download current test.openquantumsafe.org test CA cert
WORKDIR ${INSTALLDIR}
#RUN wget https://test.openquantumsafe.org/CA.crt && mv CA.crt oqs-testca.pem

WORKDIR /

COPY serverstart.sh ${INSTALLDIR}/bin

CMD ["serverstart.sh"]

## second stage: Only create minimal image without build tooling and intermediate build results generated above:
FROM alpine:3.11 as dev
# Take in all global args
ARG INSTALLDIR
ARG SIG_ALG
ARG TESTSERVER_IP
ARG TESTSERVER_NAME

# Only retain the ${INSTALLDIR} contents in the final image
COPY --from=intermediate ${INSTALLDIR} ${INSTALLDIR}

# set path to use 'new' openssl & curl. Dyn libs have been properly linked in to match
ENV PATH="${INSTALLDIR}/bin:${PATH}"

# generate certificates for openssl s_server, which is what we will test curl against
ENV OPENSSL=${INSTALLDIR}/bin/openssl
ENV OPENSSL_CNF=${INSTALLDIR}/ssl/openssl.cnf

WORKDIR ${INSTALLDIR}/bin

# generate server CSR using pre-set CA.key and cert
# and generate server cert
RUN set -x && mkdir /opt/test; \
    ${OPENSSL} req -new -newkey ${SIG_ALG} -keyout /opt/test/server.key -out /opt/test/server.csr -nodes -subj "/CN=localhost" -config ${OPENSSL_CNF}; \
    ${OPENSSL} x509 -req -in /opt/test/server.csr -out /opt/test/server.crt -CA CA.crt -CAkey CA.key -CAcreateserial -days 365;

COPY serverstart.sh ${INSTALLDIR}/bin
COPY perftest.sh ${INSTALLDIR}/bin

WORKDIR ${INSTALLDIR}

FROM dev
ARG INSTALLDIR
ARG TESTSERVER_IP
ARG TESTSERVER_NAME

WORKDIR /
#ADD cacert ${INSTALLDIR}/cacert
ADD cacert /cacert
# Add the IP Adress and the name of the server to /etc/hosts. This is necessary because of hostname verification (when using curl).
#RUN cp /etc/hosts ~/hosts.new
#RUN sed -i -c -e '$a'"${TESTSERVER_IP} ${TESTSERVER_NAME}" /etc/hosts

# Enable a normal user to create new server keys off set CA
RUN addgroup -g 1000 -S oqs && adduser --uid 1000 -S oqs -G oqs && chown -R oqs.oqs /opt/test && chmod go+r ${INSTALLDIR}/bin/CA.key && chmod go+w ${INSTALLDIR}/bin/CA.srl

USER oqs
#ENTRYPOINT ["/bin/sh", "-c", "sed -i -e '$a''${TESTSERVER_IP} ${TESTSERVER_NAME}' /etc/hosts"]
CMD ["serverstart.sh"]
STOPSIGNAL SIGTERM

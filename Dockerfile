FROM gcr.io/distroless/cc-debian13:debug
LABEL org.opencontainers.image.description="root filesystem"
COPY ./init.sh /sbin/init
COPY ./target/helloworld /bin/

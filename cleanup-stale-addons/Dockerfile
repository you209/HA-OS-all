FROM alpine:3.20

RUN apk add --no-cache bash grep coreutils findutils

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]

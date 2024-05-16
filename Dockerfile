FROM alpine:latest

COPY src /src

RUN chmod -R +x /src

RUN apk --no-cache add bash postgresql-client
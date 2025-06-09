FROM openjdk:11-slim

RUN apt-get update && \
    apt-get install -y openssl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY generate-certs.sh /app/generate-certs.sh
RUN chmod +x generate-certs.sh

CMD ["/app/generate-certs.sh"]

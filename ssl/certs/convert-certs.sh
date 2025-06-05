#!/bin/bash

# Ajuste a senha conforme a sua
STOREPASS="test123"

echo "Exportando certificado CA do truststore.jks..."
keytool -exportcert -alias CARoot -keystore kafka.truststore.jks -storepass $STOREPASS -rfc -file ca-cert.pem

echo "Convertendo kafka.keystore.jks para PKCS12..."
keytool -importkeystore \
  -srckeystore kafka.keystore.jks \
  -srcstorepass $STOREPASS \
  -destkeystore kafka.keystore.p12 \
  -deststoretype PKCS12 \
  -deststorepass $STOREPASS

echo "Extraindo certificado cliente do PKCS12..."
openssl pkcs12 -in kafka.keystore.p12 -passin pass:$STOREPASS -nokeys -out client-cert.pem

echo "Extraindo chave privada do PKCS12..."
openssl pkcs12 -in kafka.keystore.p12 -passin pass:$STOREPASS -nocerts -nodes -out client-key.pem

echo "Finalizado."

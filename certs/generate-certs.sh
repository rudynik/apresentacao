#!/bin/bash
# torne-o executável com chmod +x certs/generate-certs.sh




# CA (Certificate Authority)
echo "Generating CA key and certificate..."
openssl req -new -x509 -keyout ca.key -out ca.crt -days 365 -passin pass:confluent -passout pass:confluent -subj "/CN=ca.confluent.io/OU=confluent/O=confluent/L=London/C=GB"

# Kafka Broker
echo "Generating Kafka Broker key and certificate..."
keytool -genkeypair -noprompt \
    -dname "CN=kafka,OU=confluent,O=confluent,L=London,C=GB" \
    -alias kafka \
    -keystore kafka.keystore.jks \
    -keyalg RSA \
    -storepass confluent \
    -keypass confluent \
    -validity 3650

echo "Generating CSR for Kafka Broker..."
keytool -certreq -noprompt \
    -alias kafka \
    -keystore kafka.keystore.jks \
    -storepass confluent \
    -file kafka.csr

echo "Signing Kafka Broker certificate with CA..."
openssl x509 -req -CA ca.crt -CAkey ca.key \
    -in kafka.csr -out kafka.crt \
    -days 3650 -CAcreateserial \
    -passin pass:confluent

echo "Importing CA cert into Kafka Broker keystore..."
keytool -import -noprompt \
    -trustcacerts \
    -alias CARoot \
    -file ca.crt \
    -keystore kafka.keystore.jks \
    -storepass confluent

echo "Importing Kafka Broker signed cert into Kafka Broker keystore..."
keytool -import -noprompt \
    -trustcacerts \
    -alias kafka \
    -file kafka.crt \
    -keystore kafka.keystore.jks \
    -storepass confluent

# Kafka Broker Truststore (for Kafka to trust clients and Schema Registry)
echo "Creating Kafka Broker Truststore..."
keytool -import -noprompt \
    -trustcacerts \
    -alias CARoot \
    -file ca.crt \
    -keystore kafka.truststore.jks \
    -storepass confluent

# Schema Registry Client Keystore (for Schema Registry to connect to Kafka)
echo "Generating Schema Registry Client key and certificate..."
keytool -genkeypair -noprompt \
    -dname "CN=schemaregistry,OU=confluent,O=confluent,L=London,C=GB" \
    -alias schemaregistry \
    -keystore schemaregistry.keystore.jks \
    -keyalg RSA \
    -storepass confluent \
    -keypass confluent \
    -validity 3650

echo "Generating CSR for Schema Registry Client..."
keytool -certreq -noprompt \
    -alias schemaregistry \
    -keystore schemaregistry.keystore.jks \
    -storepass confluent \
    -file schemaregistry.csr

echo "Signing Schema Registry Client certificate with CA..."
openssl x509 -req -CA ca.crt -CAkey ca.key \
    -in schemaregistry.csr -out schemaregistry.crt \
    -days 3650 -CAcreateserial \
    -passin pass:confluent

echo "Importing CA cert into Schema Registry Client keystore..."
keytool -import -noprompt \
    -trustcacerts \
    -alias CARoot \
    -file ca.crt \
    -keystore schemaregistry.keystore.jks \
    -storepass confluent

echo "Importing Schema Registry Client signed cert into Schema Registry Client keystore..."
keytool -import -noprompt \
    -trustcacerts \
    -alias schemaregistry \
    -file schemaregistry.crt \
    -keystore schemaregistry.keystore.jks \
    -storepass confluent

# Schema Registry Truststore (for Schema Registry to trust Kafka)
echo "Creating Schema Registry Truststore..."
keytool -import -noprompt \
    -trustcacerts \
    -alias CARoot \
    -file ca.crt \
    -keystore schemaregistry.truststore.jks \
    -storepass confluent

echo "Certificates generated successfully!"
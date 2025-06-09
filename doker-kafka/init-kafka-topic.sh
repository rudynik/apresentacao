#!/bin/bash
set -e

echo "Aguardando Kafka estar pronto para aceitar conexões na porta 9093..."
while ! nc -z kafka 9093; do
  sleep 1
done
echo "Kafka está pronto. Criando tópico..."

PASSWORD=changeit

# Caminhos atualizados para arquivos temporários
TRUSTSTORE_PATH=/tmp/client.truststore.jks
KEYSTORE_PATH=/tmp/client.keystore.jks
P12_TEMP_PATH=/tmp/client.p12
SSL_PROPERTIES_FILE=/tmp/client_ssl.properties

echo "Criando truststore do cliente..."
keytool -import -alias CARoot -file /etc/kafka/secrets/ca-cert.pem \
  -keystore "$TRUSTSTORE_PATH" \
  -storepass "$PASSWORD" -noprompt

echo "Criando keystore do cliente..."
openssl pkcs12 -export \
  -in /etc/kafka/secrets/client-cert.pem \
  -inkey /etc/kafka/secrets/client-key.pem \
  -name client-cert \
  -passout pass:"$PASSWORD" \
  -out "$P12_TEMP_PATH"

keytool -importkeystore -srckeystore "$P12_TEMP_PATH" \
  -srcstoretype PKCS12 \
  -srcstorepass "$PASSWORD" \
  -destkeystore "$KEYSTORE_PATH" \
  -deststoretype JKS \
  -deststorepass "$PASSWORD" \
  -destkeypass "$PASSWORD" \
  -noprompt

# Remove o arquivo PKCS12 temporário
rm -f "$P12_TEMP_PATH"

echo "Criando arquivo de propriedades SSL temporário..."
cat <<EOF > "$SSL_PROPERTIES_FILE"
security.protocol=SSL
ssl.ca.location=/etc/kafka/secrets/ca-cert.pem
ssl.keystore.location=$KEYSTORE_PATH
ssl.keystore.password=$PASSWORD
ssl.key.password=$PASSWORD
ssl.truststore.location=$TRUSTSTORE_PATH
ssl.truststore.password=$PASSWORD
EOF

TOPIC_NAME=teste-ssl

echo "Criando tópico ${TOPIC_NAME}..."
kafka-topics --bootstrap-server kafka:9093 --create --topic "${TOPIC_NAME}" \
  --partitions 1 --replication-factor 1 \
  --command-config "$SSL_PROPERTIES_FILE" || true

echo "Verificando se o tópico ${TOPIC_NAME} foi criado..."
if kafka-topics --bootstrap-server kafka:9093 --list \
  --command-config "$SSL_PROPERTIES_FILE" | grep -q "$TOPIC_NAME"; then
  echo "Tópico ${TOPIC_NAME} criado com sucesso."
else
  echo "❌ Falha ao criar o tópico ${TOPIC_NAME}."
fi

# Limpa o arquivo de propriedades temporário
rm -f "$SSL_PROPERTIES_FILE"

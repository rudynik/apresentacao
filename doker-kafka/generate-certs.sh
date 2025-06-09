#!/bin/bash

set -e

# --- Variáveis de Configuração ---
# Caminho para onde os certificados serão gerados DENTRO do container
CERTS_DIR="/app/certs"
# Senha para os keystores e truststores. Mude para algo seguro em produção!
PASSWORD="changeit"
# Nome comum (Common Name) para o broker Kafka.
# É importante que seja o nome do host ou do serviço que o cliente usará para se conectar.
# Se o broker estiver no Docker Compose com nome de serviço 'kafka', use 'kafka'.
BROKER_CN="kafka" # Alterado de 'broker' para 'kafka' (nome comum para o serviço Kafka)
# Nome comum para o cliente. Pode ser genérico.
CLIENT_CN="client"

# --- Criação do Diretório de Certificados ---
echo "📁 Criando diretório de certificados em $CERTS_DIR..."
mkdir -p "$CERTS_DIR"

# --- 1. Gerando a Autoridade Certificadora (CA) ---
echo "🔐 1. Gerando CA (Autoridade Certificadora)..."
openssl req -x509 -newkey rsa:2048 -days 3650 -nodes \
  -keyout "$CERTS_DIR/ca-key.pem" \
  -out "$CERTS_DIR/ca-cert.pem" \
  -subj "/C=BR/ST=SP/L=Maua/O=MyOrg/OU=KafkaCA/CN=MyKafkaCA" \
  -passout pass:"$PASSWORD" # CA key não precisa de senha se 'nodes' for usado

# --- 2. Gerando Certificados para o Broker Kafka ---

echo "🔐 2. Gerando keystore do broker e CSR (Certificate Signing Request)..."
# Gerar a chave privada e o certificado auto-assinado no keystore
keytool -genkeypair -alias kafka-server \
  -keyalg RSA -keysize 2048 -validity 365 \
  -dname "CN=$BROKER_CN, OU=KafkaBroker, O=MyOrg, L=Maua, ST=SP, C=BR" \
  -keystore "$CERTS_DIR/kafka.server.keystore.jks" \
  -storepass "$PASSWORD" -keypass "$PASSWORD"

# Gerar o CSR (Certificate Signing Request) a partir do keystore
keytool -certreq -alias kafka-server \
  -file "$CERTS_DIR/kafka-server.csr" \
  -keystore "$CERTS_DIR/kafka.server.keystore.jks" \
  -storepass "$PASSWORD"

echo "🔐 2.1. Assinando certificado do broker com a CA..."
# Assinar o CSR do broker com a CA
openssl x509 -req -CA "$CERTS_DIR/ca-cert.pem" -CAkey "$CERTS_DIR/ca-key.pem" \
  -in "$CERTS_DIR/kafka-server.csr" -out "$CERTS_DIR/kafka-server-signed.cer" \
  -days 365 -CAcreateserial \
  -passin pass:"$PASSWORD" # Se a CA key tivesse senha

echo "📥 2.2. Importando CA e certificado assinado no keystore do broker..."
# Importar o certificado da CA no keystore do broker (confiança na CA)
keytool -import -alias CARoot \
  -file "$CERTS_DIR/ca-cert.pem" \
  -keystore "$CERTS_DIR/kafka.server.keystore.jks" \
  -storepass "$PASSWORD" -noprompt

# Importar o certificado assinado do broker de volta no keystore
keytool -import -alias kafka-server \
  -file "$CERTS_DIR/kafka-server-signed.cer" \
  -keystore "$CERTS_DIR/kafka.server.keystore.jks" \
  -storepass "$PASSWORD" -noprompt

echo "🔐 2.3. Criando truststore do broker e importando a CA..."
# Criar o truststore do broker e importar o certificado da CA
keytool -import -alias CARoot \
  -file "$CERTS_DIR/ca-cert.pem" \
  -keystore "$CERTS_DIR/kafka.server.truststore.jks" \
  -storepass "$PASSWORD" -noprompt

# Opcional: Arquivos de credenciais para facilitar a configuração do Kafka
echo "$PASSWORD" > "$CERTS_DIR/kafka.server.keystore-creds"
echo "$PASSWORD" > "$CERTS_DIR/kafka.server.truststore-creds"
echo "$PASSWORD" > "$CERTS_DIR/kafka.server.key-creds"

# --- 3. Gerando Certificados para o Cliente Kafka (Produtor Python) ---

echo "🔐 3. Gerando chave privada e CSR para o cliente..."
openssl req -newkey rsa:2048 -nodes \
  -keyout "$CERTS_DIR/client-key.pem" \
  -out "$CERTS_DIR/client-csr.pem" \
  -subj "/C=BR/ST=SP/L=Maua/O=MyOrg/OU=KafkaClient/CN=$CLIENT_CN"

echo "🔐 3.1. Assinando certificado do cliente com a CA..."
openssl x509 -req -in "$CERTS_DIR/client-csr.pem" \
  -CA "$CERTS_DIR/ca-cert.pem" -CAkey "$CERTS_DIR/ca-key.pem" -CAcreateserial \
  -out "$CERTS_DIR/client-cert.pem" -days 365 \
  -passin pass:"$PASSWORD" # Se a CA key tivesse senha

echo "✅ Certificados gerados com sucesso em $CERTS_DIR!"

echo "🔧 Ajustando permissões dos arquivos gerados..."
chmod -R 755 "$CERTS_DIR"
chmod 644 "$CERTS_DIR"/*
chmod 644 "$CERTS_DIR"/kafka.*
chmod 644 "$CERTS_DIR"/*.pem
chmod 644 "$CERTS_DIR"/*.csr
chmod 644 "$CERTS_DIR"/*.cer
chmod 644 "$CERTS_DIR"/*.jks
# chmod 644 "$CERTS_DIR"/*.creds


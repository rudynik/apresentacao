#!/bin/bash

set -e

echo "🔐 Gerando CA..."

openssl req -new -x509 -nodes \
  -keyout ca-key.pem \
  -out ca.pem \
  -days 365 \
  -subj "//CN=Kafka-CA"

echo "📜 Gerando certificado para o broker..."

openssl req -newkey rsa:2048 -nodes \
  -keyout broker-key.pem \
  -out broker-req.pem \
  -subj "//CN=broker"

openssl x509 -req \
  -in broker-req.pem \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -CAcreateserial \
  -out broker-cert.pem \
  -days 365

echo "📜 Gerando certificado para o client..."

openssl req -newkey rsa:2048 -nodes \
  -keyout client-key.pem \
  -out client-req.pem \
  -subj "//CN=client"

openssl x509 -req \
  -in client-req.pem \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -CAcreateserial \
  -out client-cert.pem \
  -days 365

echo "🧹 Limpando arquivos temporários..."

rm -f broker-req.pem client-req.pem

echo "✅ Certificados gerados com sucesso!"

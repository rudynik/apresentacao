# apresentacao

├── certs/
│   └── generate-certs.sh
└── docker-compose.yml

Senhas: Todas as senhas neste exemplo são confluent para simplificar o desenvolvimento local. NÃO use isso em produção.

Portas:
2181: ZooKeeper
9092: Kafka SSL (para clientes externos)
29092: Kafka PLAINTEXT (para comunicação interna, como o Schema Registry se conectando ao Kafka)
8081: Confluent Schema Registry (HTTP)

Ótimo! Habilitar SSL no Kafka para desenvolvimento local e integrar com o Schema Registry é um pouco mais complexo, pois envolve a geração de certificados e a configuração de caminhos e senhas.

Vou te dar um docker-compose.yml completo e os passos necessários para gerar os certificados.

Requisitos:

Java Development Kit (JDK): Você precisará do keytool que vem com o JDK para gerar os keystores e truststores.
OpenSSL: Para criar a Certificate Authority (CA) e assinar os certificados.
Passo 1: Geração dos Certificados
Primeiro, você precisará criar uma estrutura de diretórios e scripts para gerar seus certificados.

Crie uma pasta chamada certs na mesma pasta onde estará seu docker-compose.yml.

Dentro da pasta certs, crie os seguintes arquivos:

certs/generate-certs.sh (torne-o executável com chmod +x certs/generate-certs.sh)

Bash

#!/bin/bash

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
Executando o script de geração de certificados:

Navegue até a pasta certs no seu terminal.
Execute o script: ./generate-certs.sh
Isso criará todos os arquivos .jks (Java KeyStore) e .crt necessários na pasta certs.

Passo 2: Arquivo docker-compose.yml
Agora, crie o arquivo docker-compose.yml na pasta raiz (junto com a pasta certs):

YAML

version: '3.8'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.3
    hostname: zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    restart: always

  kafka:
    image: confluentinc/cp-kafka:7.5.3
    hostname: kafka
    container_name: kafka
    ports:
      - "9092:9092" # Porta para clientes SSL externos
      - "29092:29092" # Porta para comunicação interna (e para Schema Registry)
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: 'PLAINTEXT:PLAINTEXT,SSL:SSL'
      KAFKA_ADVERTISED_LISTENERS: 'PLAINTEXT://kafka:29092,SSL://localhost:9092'
      KAFKA_INTER_BROKER_LISTENER_NAME: 'PLAINTEXT' # Para simplicidade, comunicação inter-broker em PLAINTEXT. Mude para SSL se quiser 100% SSL.
      KAFKA_SSL_TRUSTSTORE_LOCATION: '/etc/kafka/secrets/kafka.truststore.jks'
      KAFKA_SSL_TRUSTSTORE_PASSWORD: 'confluent'
      KAFKA_SSL_KEYSTORE_LOCATION: '/etc/kafka/secrets/kafka.keystore.jks'
      KAFKA_SSL_KEYSTORE_PASSWORD: 'confluent'
      KAFKA_SSL_KEY_PASSWORD: 'confluent'
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
    volumes:
      - ./certs:/etc/kafka/secrets # Monta a pasta de certificados no container
    depends_on:
      - zookeeper
    restart: always

  schema-registry:
    image: confluentinc/cp-schema-registry:7.5.3
    hostname: schema-registry
    container_name: schema-registry
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL: 'zookeeper:2181' # O Schema Registry se conecta ao ZooKeeper para descobrir os brokers Kafka
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: 'SSL://kafka:9092' # O Schema Registry se conecta ao Kafka via SSL
      SCHEMA_REGISTRY_LISTENERS: 'http://0.0.0.0:8081' # Você pode adicionar HTTPS aqui se quiser SSL para o Schema Registry também
      # Configurações SSL para Schema Registry se conectar ao Kafka
      SCHEMA_REGISTRY_KAFKASTORE_SSL_TRUSTSTORE_LOCATION: '/etc/schema-registry/secrets/schemaregistry.truststore.jks'
      SCHEMA_REGISTRY_KAFKASTORE_SSL_TRUSTSTORE_PASSWORD: 'confluent'
      SCHEMA_REGISTRY_KAFKASTORE_SSL_KEYSTORE_LOCATION: '/etc/schema-registry/secrets/schemaregistry.keystore.jks'
      SCHEMA_REGISTRY_KAFKASTORE_SSL_KEYSTORE_PASSWORD: 'confluent'
      SCHEMA_REGISTRY_KAFKASTORE_SSL_KEY_PASSWORD: 'confluent'
    volumes:
      - ./certs:/etc/schema-registry/secrets # Monta a pasta de certificados no container
    depends_on:
      - kafka
    restart: always
Como usar:
Estrutura de diretórios:

.
├── certs/
│   └── generate-certs.sh
└── docker-compose.yml
Gerar certificados:

Abra seu terminal.
Navegue até a pasta certs.
Torne o script executável: chmod +x generate-certs.sh
Execute o script: ./generate-certs.sh
Isso criará os arquivos .jks e .crt necessários dentro da pasta certs.
Iniciar os containers:

Navegue de volta para o diretório raiz (onde está docker-compose.yml).
Execute: docker-compose up -d
Isso subirá o ZooKeeper, Kafka (com SSL habilitado) e o Schema Registry.

Pontos importantes e considerações:
Senhas: Todas as senhas neste exemplo são confluent para simplificar o desenvolvimento local. NÃO use isso em produção.
Advertised Listeners:
PLAINTEXT://kafka:29092: Esta é a porta para comunicação interna entre os containers (Kafka e Schema Registry). É importante que o Schema Registry aponte para esta porta se você não quiser usar SSL para comunicação interna.
SSL://localhost:9092: Esta é a porta para clientes externos (do seu host local) se conectarem ao Kafka usando SSL.
Comunicação Interna Kafka: No exemplo, KAFKA_INTER_BROKER_LISTENER_NAME: 'PLAINTEXT' é usado para simplificar, significando que, se você tivesse múltiplos brokers Kafka, a comunicação entre eles seria em texto simples. Se você quiser que a comunicação inter-broker também seja SSL, a configuração se torna mais complexa e exigiria certificados adicionais para cada broker.
Schema Registry SSL: O Schema Registry está configurado para se conectar ao Kafka via SSL (SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: 'SSL://kafka:9092'). A porta 9092 no Kafka é a porta SSL que está sendo exposta.
Portas:
2181: ZooKeeper
9092: Kafka SSL (para clientes externos)
29092: Kafka PLAINTEXT (para comunicação interna, como o Schema Registry se conectando ao Kafka)
8081: Confluent Schema Registry (HTTP)
Teste Local: Para testar a conexão SSL, você precisaria configurar seu cliente Kafka (por exemplo, um produtor ou consumidor Java, Python, Node.js) para usar SSL e apontar para o kafka.truststore.jks e kafka.keystore.jks gerados, dependendo se você usa autenticação mútua. Para validação Avro, você conectaria seu cliente ao Schema Registry em http://localhost:8081.
Este setup oferece um ambiente robusto para desenvolvimento local com Kafka, ZooKeeper e Schema Registry, incluindo a configuração de SSL para o Kafka.
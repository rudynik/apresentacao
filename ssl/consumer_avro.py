from confluent_kafka import DeserializingConsumer
from confluent_kafka.serialization import StringDeserializer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer

# Configuração do Schema Registry
schema_registry_conf = {
    'url': 'http://localhost:8081'
}

# Inicializa o cliente do Schema Registry
schema_registry_client = SchemaRegistryClient(schema_registry_conf)

# Função para converter Avro em dicionário Python
def dict_to_user(obj, ctx):
    return obj

# Inicializa o deserializer AVRO
avro_deserializer = AvroDeserializer(
    schema_registry_client=schema_registry_client,
    schema_str=None,  # Será resolvido automaticamente
    from_dict=dict_to_user
)

# Configuração do consumer com SSL
consumer_conf = {
    'bootstrap.servers': 'localhost:9093',
    'key.deserializer': StringDeserializer('utf_8'),
    'value.deserializer': avro_deserializer,
    'group.id': 'grupo-consumidor-avro',
    'auto.offset.reset': 'earliest',
    'security.protocol': 'SSL',
    'ssl.ca.location': './certs/ca-cert.pem',
    'ssl.certificate.location': './certs/client-cert.pem',
    'ssl.key.location': './certs/client-key.pem',
    'ssl.key.password': 'test123'
}

# Cria o consumer
consumer = DeserializingConsumer(consumer_conf)

# Inscreve no tópico
consumer.subscribe(['meu-topico'])

print("Consumindo mensagens...\n")
try:
    while True:
        msg = consumer.poll(1.0)  # timeout de 1 segundo
        if msg is None:
            continue
        if msg.error():
            print("Erro:", msg.error())
            continue

        print(f"Mensagem recebida: key={msg.key()}, value={msg.value()}")

except KeyboardInterrupt:
    print("Encerrando o consumer.")

finally:
    consumer.close()

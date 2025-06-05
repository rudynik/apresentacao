from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka import SerializingProducer
from confluent_kafka.serialization import StringSerializer

# Configurações do schema registry e do broker
schema_registry_conf = {
    'url': 'http://localhost:8081',
}

kafka_conf = {
    'bootstrap.servers': 'localhost:9093',  # ou broker:29092 se estiver rodando dentro do container
    'key.serializer': StringSerializer('utf_8'),
    'value.serializer': None,
    'security.protocol': 'SSL',
    'ssl.ca.location': './certs/ca-cert.pem',
    'ssl.certificate.location': './certs/client-cert.pem',
    'ssl.key.location': './certs/client-key.pem',
    'ssl.key.password': 'test123',
}

# Schema AVRO (como string)
avro_schema_str = """
{
  "type": "record",
  "name": "User",
  "fields": [
    {"name": "nome", "type": "string"},
    {"name": "idade", "type": "int"}
  ]
}
"""

# Função para converter o objeto Python no formato Avro
def user_to_dict(obj, ctx):
    return obj

# Objeto a ser enviado
user = {
    "nome": "Juliana",
    "idade": 35
}

# Inicializa os clientes
schema_registry_client = SchemaRegistryClient(schema_registry_conf)
avro_serializer = AvroSerializer(schema_registry_client, avro_schema_str, user_to_dict)

# Atualiza o serializer na configuração do Kafka
kafka_conf['value.serializer'] = avro_serializer

# Cria o producer
producer = SerializingProducer(kafka_conf)

# Envia a mensagem
producer.produce(
    topic="meu-topico",
    value=user
)

print("Mensagem enviada com sucesso!")

producer.flush()

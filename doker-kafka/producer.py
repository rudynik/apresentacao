from confluent_kafka import Producer
import os
import sys

CLIENT_KEY_PASSWORD = 'changeit'

# Caminho para os certificados DENTRO do container (ABSOLUTO)
# A pasta 'certs' é copiada para /app/certs no Dockerfile.producer
CERTS_DIR = "/app/certs" # <-- Certifique-se de que é "/app/certs"

conf = {
    'bootstrap.servers': 'kafka:9093',
    'security.protocol': 'SSL',
    'ssl.ca.location': os.path.join(CERTS_DIR, 'ca-cert.pem'),
    'ssl.certificate.location': os.path.join(CERTS_DIR, 'client-cert.pem'),
    'ssl.key.location': os.path.join(CERTS_DIR, 'client-key.pem'),
    'ssl.key.password': CLIENT_KEY_PASSWORD,
    'debug': 'broker,topic,msg,security'
}

producer = None
def delivery_report(err, msg):
    if err is not None:
        print(f'❌ Erro na entrega: {err}')
    else:
        print(f'✅ Mensagem entregue: {msg.topic()} [{msg.partition()}] @ offset {msg.offset()}')

try:
    producer = Producer(conf)

    topic = "teste-ssl"
    message_value = "Mensagem enviada com SSL do container!"
    message_key = "chave1"

    print(f"Tentando produzir mensagem para o tópico: {topic} em {conf['bootstrap.servers']}")

    producer.produce(
        topic,
        key=message_key,
        value=message_value.encode('utf-8'),
        callback=delivery_report
    )

    print("Aguardando entrega de mensagens...")
    remaining_messages = producer.flush(timeout=10)
    if remaining_messages > 0:
        print(f"ATENÇÃO: {remaining_messages} mensagens não puderam ser entregues após o flush.")

except Exception as e:
    print(f"❗ Erro ao produzir: {e}")
    sys.exit(1)
finally:
    if producer:
        print("Produtor encerrado.")


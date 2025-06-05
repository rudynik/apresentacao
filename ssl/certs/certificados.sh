# Cria o keystore com o certificado e chave do broker
openssl pkcs12 -export \
  -in broker-cert.pem \
  -inkey broker-key.pem \
  -certfile ca.pem \
  -name broker \
  -out broker-keystore.p12 \
  -password pass:test123

# Cria o truststore com o certificado da CA
keytool -importcert \
  -alias CARoot \
  -file ca.pem \
  -keystore broker-truststore.p12 \
  -storepass test123 \
  -storetype PKCS12 \
  -noprompt

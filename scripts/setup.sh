#!/bin/bash
# 1. Instalar dependencias básicas
sudo apt update -y
sudo apt install -y python3-pip unzip sqlite3
pip3 install flask boto3 python-dotenv flask-cors awscli

# 2. Crear estructura de la app
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# 3. Crear archivo .env con el bucket de salida
echo 'BUCKET_SALIDA="output-bucket-covid-test"' > .env

# 4. Descargar data.json automáticamente desde S3 si no existe
if [ ! -f data.json ]; then
  BUCKET="output-bucket-covid-test"
  KEY="processed/DataCovid.json"
  aws s3 cp s3://$BUCKET/$KEY data.json || echo "[]" > data.json
fi

# 5. Validar y reparar data.json si está corrupto o vacío
if ! python3 -c "import json; json.load(open('data.json'))" 2>/dev/null; then
  echo "[]" > data.json
fi

# 6. Otorgar propiedad y permisos correctos
sudo chown ubuntu:ubuntu data.json
chmod 666 data.json

# 8. Detener cualquier backend Flask corriendo antes
sudo pkill -f app.py || true

# 9. Lanzar el backend Flask en segundo plano
nohup python3 app.py &

#!/bin/bash
sudo apt update -y
sudo apt install -y python3-pip unzip
pip3 install flask boto3 python-dotenv

mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

cat <<EOF > app.py
from flask import Flask, jsonify
import boto3
import os
from dotenv import load_dotenv
import sqlite3

load_dotenv()
app = Flask(__name__)
s3 = boto3.client('s3')
BUCKET_NAME = os.getenv("BUCKET_SALIDA")

# Inicializar base de datos
def init_db():
    conn = sqlite3.connect('/home/ubuntu/app/consultas.db')
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS historial (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            consulta TEXT,
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()

init_db()

@app.route('/data-json/<path:file_id>')
def get_json(file_id):
    file_name = f"{file_id}.json"
    # Guardar en la base de datos cada consulta
    conn = sqlite3.connect('/home/ubuntu/app/consultas.db')
    cursor = conn.cursor()
    cursor.execute("INSERT INTO historial (consulta) VALUES (?)", (file_name,))
    conn.commit()
    conn.close()
    try:
        response = s3.get_object(Bucket=BUCKET_NAME, Key=file_name)
        content = response['Body'].read().decode('utf-8')
        return content, 200, {'Content-Type': 'application/json'}
    except Exception as e:
        return jsonify({'error': str(e)}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF

# Variable de entorno para el bucket de salida
echo 'BUCKET_SALIDA="upeu-bucket-salida"' > .env

# Lanza el backend Flask en segundo plano
nohup python3 app.py &

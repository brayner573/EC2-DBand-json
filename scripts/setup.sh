#!/bin/bash

# 1. Instalar dependencias
sudo apt update -y
sudo apt install -y python3-pip unzip sqlite3
pip3 install flask boto3 python-dotenv

# 2. Crear estructura
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# 3. Crear archivo de entorno (.env)
echo 'BUCKET_SALIDA="upeu-bucket-salida"' > .env

# 4. Crear archivo JSON local si no existe o descargar de S3
if [ ! -f data.json ]; then
  # Instalar AWS CLI si no está presente
  if ! command -v aws >/dev/null 2>&1; then
    pip3 install awscli
  fi
  BUCKET="upeu-bucket-salida"
  KEY="data-202563003422.json"
  aws s3 cp s3://$BUCKET/$KEY data.json || echo "[]" > data.json
fi

# 5. Crear app Flask unificada
cat <<EOF > app.py
from flask import Flask, request, jsonify
import json
import os
import sqlite3
import boto3
from dotenv import load_dotenv

# Inicialización
app = Flask(__name__)
load_dotenv()

DATA_FILE = 'data.json'
DB_FILE = 'consultas.db'
BUCKET_NAME = os.getenv("BUCKET_SALIDA")
s3 = boto3.client('s3')

# --- BASE DE DATOS ---
def init_db():
    conn = sqlite3.connect(DB_FILE)
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

# --- CRUD LOCAL JSON ---
def load_data():
    if not os.path.exists(DATA_FILE):
        return []
    with open(DATA_FILE, 'r') as f:
        return json.load(f)

def save_data(data):
    with open(DATA_FILE, 'w') as f:
        json.dump(data, f, indent=2)

@app.route('/data', methods=['GET'])
def get_all():
    return jsonify(load_data())

@app.route('/data/<int:item_id>', methods=['GET'])
def get_by_id(item_id):
    data = load_data()
    item = next((d for d in data if d['id'] == item_id), None)
    return jsonify(item or {})

@app.route('/data', methods=['POST'])
def create_item():
    data = load_data()
    new_item = request.get_json()
    data.append(new_item)
    save_data(data)
    return jsonify({"message": "Item creado"}), 201

@app.route('/data/<int:item_id>', methods=['PUT'])
def update_item(item_id):
    data = load_data()
    updated = request.get_json()
    for i, d in enumerate(data):
        if d['id'] == item_id:
            data[i] = updated
            save_data(data)
            return jsonify({"message": "Actualizado"})
    return jsonify({"error": "No encontrado"}), 404

@app.route('/data/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    data = load_data()
    data = [d for d in data if d['id'] != item_id]
    save_data(data)
    return jsonify({"message": "Eliminado"})

# --- CONSULTA REMOTA DESDE S3 ---
@app.route('/data-json/<path:file_id>', methods=['GET'])
def get_json_from_s3(file_id):
    file_name = f"{file_id}.json"
    # registrar en base de datos
    conn = sqlite3.connect(DB_FILE)
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

# --- CONSULTAR HISTORIAL ---
@app.route('/historial', methods=['GET'])
def historial():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM historial ORDER BY fecha DESC")
    rows = cursor.fetchall()
    conn.close()
    return jsonify([
        {"id": row[0], "consulta": row[1], "fecha": row[2]} for row in rows
    ])

# --- INICIO APP ---
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF

# 6. Lanzar backend en segundo plano
nohup python3 app.py &

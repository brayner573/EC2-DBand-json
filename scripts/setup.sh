#!/bin/bash

# 1. Instalar dependencias básicas
sudo apt update -y
sudo apt install -y python3-pip unzip sqlite3
pip3 install flask boto3 python-dotenv flask-cors awscli

# 2. Crear estructura de la app
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# 3. Crear archivo .env con el bucket de salida
echo 'BUCKET_SALIDA="upeu-bucket-salida"' > .env

# 4. Descargar data.json automáticamente desde S3 si no existe
if [ ! -f data.json ]; then
  BUCKET="upeu-bucket-salida"
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

# 7. Crear backend Flask con CRUD, consulta S3, historial, recarga y CORS
cat <<EOF > app.py
from flask import Flask, request, jsonify
import os
import sqlite3
import boto3
from dotenv import load_dotenv
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
load_dotenv()

DB_FILE = 'consultas.db'
BUCKET_NAME = os.getenv("BUCKET_SALIDA")
S3_KEY = "processed/DataCovid.json"
s3 = boto3.client('s3')

# --- Inicializar base de datos SQLite (registros + historial) ---
def init_db():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS registros (
            id INTEGER PRIMARY KEY,
            ano INTEGER,
            semana INTEGER,
            clasificacion TEXT
        )
    """)
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

# --- CRUD sobre SQLite ---
@app.route('/data', methods=['GET'])
def get_all():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM registros")
    rows = cursor.fetchall()
    conn.close()
    registros = [
        {"id": row[0], "ano": row[1], "semana": row[2], "clasificacion": row[3]}
        for row in rows
    ]
    return jsonify(registros)

@app.route('/data/<int:item_id>', methods=['GET'])
def get_by_id(item_id):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM registros WHERE id = ?", (item_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        return jsonify({"id": row[0], "ano": row[1], "semana": row[2], "clasificacion": row[3]})
    else:
        return jsonify({}), 404

@app.route('/data', methods=['POST'])
def create_item():
    nuevo = request.get_json()
    try:
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO registros (id, ano, semana, clasificacion) VALUES (?, ?, ?, ?)",
                       (nuevo['id'], nuevo['ano'], nuevo['semana'], nuevo['clasificacion']))
        conn.commit()
        conn.close()
        return jsonify({"message": "Item creado"}), 201
    except sqlite3.IntegrityError:
        return jsonify({"error": "ID duplicado"}), 400

@app.route('/data/<int:item_id>', methods=['PUT'])
def update_item(item_id):
    actualizado = request.get_json()
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE registros SET ano=?, semana=?, clasificacion=? WHERE id=?",
        (actualizado['ano'], actualizado['semana'], actualizado['clasificacion'], item_id)
    )
    conn.commit()
    conn.close()
    if cursor.rowcount:
        return jsonify({"message": "Actualizado"})
    else:
        return jsonify({"error": "No encontrado"}), 404

@app.route('/data/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM registros WHERE id=?", (item_id,))
    conn.commit()
    conn.close()
    if cursor.rowcount:
        return jsonify({"message": "Eliminado"})
    else:
        return jsonify({"error": "No encontrado"}), 404

# --- CONSULTA REMOTA DESDE S3 ---
@app.route('/data-json/<path:file_id>', methods=['GET'])
def get_json_from_s3(file_id):
    file_name = f"{file_id}.json"
    # Registrar consulta en base de datos
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

# --- RECARGAR ARCHIVO DESDE S3 (esto sigue igual, es opcional) ---
@app.route('/recargar', methods=['POST'])
def recargar():
    try:
        response = s3.get_object(Bucket=BUCKET_NAME, Key=S3_KEY)
        content = response['Body'].read().decode('utf-8')
        # Opcionalmente, podrías migrar este JSON a la base si lo necesitas.
        return jsonify({"message": "Archivo descargado desde S3 (no insertado en DB)."})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF

# 8. Detener cualquier backend Flask corriendo antes
sudo pkill -f app.py || true

# 9. Lanzar el backend Flask en segundo plano
nohup python3 app.py &

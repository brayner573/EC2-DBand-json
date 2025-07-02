#!/bin/bash

# 1. Instalar dependencias
sudo apt update -y
sudo apt install -y python3-pip unzip sqlite3
pip3 install flask boto3 python-dotenv flask-cors awscli

# 2. Crear estructura
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# 3. Crear archivo .env para el bucket de salida
echo 'BUCKET_SALIDA="upeu-bucket-salida"' > .env

# 4. Descargar data.json desde S3 si no existe (o actualizarlo)
BUCKET="upeu-bucket-salida"
KEY="processed/DataCovid.json"
aws s3 cp s3://$BUCKET/$KEY data.json || echo "[]" > data.json

# 5. Validar y reparar data.json si está corrupto o vacío
if ! python3 -c "import json; json.load(open('data.json'))" 2>/dev/null; then
  echo "[]" > data.json
fi

# 6. Crear base de datos y tablas si no existen
python3 <<EOF
import sqlite3
conn = sqlite3.connect("consultas.db")
c = conn.cursor()
c.execute("""CREATE TABLE IF NOT EXISTS registros (
    id INTEGER PRIMARY KEY,
    ano INTEGER,
    semana INTEGER,
    clasificacion TEXT
)""")
c.execute("""CREATE TABLE IF NOT EXISTS historial (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    consulta TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)""")
conn.commit()
conn.close()
EOF

# 7. Importar registros de data.json a la tabla 'registros'
python3 <<EOF
import json
import sqlite3
try:
    with open("data.json") as f:
        registros = json.load(f)
except Exception:
    registros = []
conn = sqlite3.connect("consultas.db")
c = conn.cursor()
c.execute("DELETE FROM registros")
for reg in registros:
    c.execute("INSERT OR IGNORE INTO registros (id, ano, semana, clasificacion) VALUES (?, ?, ?, ?)", (
        reg.get("id"),
        reg.get("ano"),
        reg.get("semana"),
        reg.get("clasificacion")
    ))
conn.commit()
conn.close()
print(f"Importados {len(registros)} registros desde data.json a la base de datos.")
EOF

# 8. Otorgar permisos correctos
sudo chown ubuntu:ubuntu data.json consultas.db
chmod 666 data.json consultas.db

# 9. Crear backend Flask con todos los endpoints
cat <<PYTHON > app.py
from flask import Flask, request, jsonify
import os
import sqlite3
import boto3
from dotenv import load_dotenv
from flask_cors import CORS
import json

app = Flask(__name__)
CORS(app)
load_dotenv()

DB_FILE = 'consultas.db'
BUCKET_NAME = os.getenv("BUCKET_SALIDA")
S3_KEY = "processed/DataCovid.json"
s3 = boto3.client('s3')

# --- CRUD sobre SQLite ---
@app.route('/data', methods=['GET'])
def get_all():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT * FROM registros")
    rows = c.fetchall()
    conn.close()
    return jsonify([{"id": r[0], "ano": r[1], "semana": r[2], "clasificacion": r[3]} for r in rows])

@app.route('/data/<int:item_id>', methods=['GET'])
def get_by_id(item_id):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT * FROM registros WHERE id = ?", (item_id,))
    r = c.fetchone()
    conn.close()
    if r:
        return jsonify({"id": r[0], "ano": r[1], "semana": r[2], "clasificacion": r[3]})
    else:
        return jsonify({}), 404

@app.route('/data', methods=['POST'])
def create_item():
    nuevo = request.get_json()
    try:
        conn = sqlite3.connect(DB_FILE)
        c = conn.cursor()
        c.execute("INSERT INTO registros (id, ano, semana, clasificacion) VALUES (?, ?, ?, ?)",
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
    c = conn.cursor()
    c.execute(
        "UPDATE registros SET ano=?, semana=?, clasificacion=? WHERE id=?",
        (actualizado['ano'], actualizado['semana'], actualizado['clasificacion'], item_id)
    )
    conn.commit()
    conn.close()
    if c.rowcount:
        return jsonify({"message": "Actualizado"})
    else:
        return jsonify({"error": "No encontrado"}), 404

@app.route('/data/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("DELETE FROM registros WHERE id=?", (item_id,))
    conn.commit()
    conn.close()
    if c.rowcount:
        return jsonify({"message": "Eliminado"})
    else:
        return jsonify({"error": "No encontrado"}), 404

# --- CONSULTA REMOTA DESDE S3 ---
@app.route('/data-json/<path:file_id>', methods=['GET'])
def get_json_from_s3(file_id):
    file_name = f"{file_id}.json"
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("INSERT INTO historial (consulta) VALUES (?)", (file_name,))
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
    c = conn.cursor()
    c.execute("SELECT * FROM historial ORDER BY fecha DESC")
    rows = c.fetchall()
    conn.close()
    return jsonify([{"id": r[0], "consulta": r[1], "fecha": r[2]} for r in rows])

# --- RECARGAR ARCHIVO DESDE S3 E IMPORTARLO A LA BASE ---
@app.route('/recargar', methods=['POST'])
def recargar():
    try:
        response = s3.get_object(Bucket=BUCKET_NAME, Key=S3_KEY)
        content = response['Body'].read().decode('utf-8')
        registros = json.loads(content)
        conn = sqlite3.connect(DB_FILE)
        c = conn.cursor()
        c.execute("DELETE FROM registros")
        for reg in registros:
            c.execute(
                "INSERT OR IGNORE INTO registros (id, ano, semana, clasificacion) VALUES (?, ?, ?, ?)",
                (reg.get('id'), reg.get('ano'), reg.get('semana'), reg.get('clasificacion'))
            )
        conn.commit()
        conn.close()
        return jsonify({"message": f"{len(registros)} registros importados desde S3 a la base de datos"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
PYTHON

# 10. Detener cualquier backend Flask corriendo antes
sudo pkill -f app.py || true

# 11. Lanzar el backend Flask en segundo plano
nohup python3 app.py &


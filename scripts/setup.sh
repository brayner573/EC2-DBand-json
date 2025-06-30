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

load_dotenv()
app = Flask(__name__)
s3 = boto3.client('s3')
BUCKET_NAME = os.getenv("BUCKET_SALIDA")

@app.route('/data-json/<file_id>')
def get_json(file_id):
    file_name = f"{file_id}.json"
    try:
        response = s3.get_object(Bucket=BUCKET_NAME, Key=file_name)
        content = response['Body'].read().decode('utf-8')
        return content, 200, {'Content-Type': 'application/json'}
    except Exception as e:
        return jsonify({'error': str(e)}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF

echo 'BUCKET_SALIDA="upeu-bucket-salida"' > .env

nohup python3 app.py &
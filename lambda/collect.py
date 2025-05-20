import json
import os
import urllib.request
import boto3

def anonymize(data):
    for item in data:
        item.pop('mac', None)
        item.pop('ip', None)
    return data

def handler(event, context):
    key = os.environ['MERAKI_API_KEY']
    org = os.environ.get('MERAKI_ORG_ID', '')
    headers = {'X-Cisco-Meraki-API-Key': key}
    url = f"https://api.meraki.com/api/v1/organizations/{org}/devices"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
    anon = anonymize(data)
    s3 = boto3.client('s3')
    bucket = os.environ['BUCKET']
    s3.put_object(Bucket=bucket, Key='latest.json', Body=json.dumps(anon).encode())
    return {'statusCode': 200, 'body': 'stored'}

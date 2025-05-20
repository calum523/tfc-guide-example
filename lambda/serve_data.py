import json
import os
import boto3

def handler(event, context):
    s3 = boto3.client('s3')
    bucket = os.environ['BUCKET']
    try:
        obj = s3.get_object(Bucket=bucket, Key='latest.json')
        data = obj['Body'].read().decode()
        return {'statusCode': 200, 'body': data}
    except Exception as e:
        return {'statusCode': 500, 'body': str(e)}

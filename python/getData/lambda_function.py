import boto3
import json

BUCKET_NAME = "aj-bucket-lambda-outputs"
OBJECT_KEY = "data.json"

def lambda_handler(event, context):
    # Create an S3 client
    s3 = boto3.client('s3')

    try:
        # Get the object content from S3
        response = s3.get_object(Bucket=BUCKET_NAME, Key=OBJECT_KEY)
        
        # Read the content from the response as a string
        content = response['Body'].read().decode('utf-8')  # Assuming the content is in UTF-8 format

        # Load the JSON content
        json_content = json.loads(content)

        # Do something with the retrieved JSON content (e.g., print it)
        print(f'DEBUG: Retrieved {OBJECT_KEY} content: {json_content}')

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'JSON object retrieved successfully', 'content': json_content})
        }
    except Exception as e:
        print('Error retrieving object:', str(e))
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Error retrieving JSON object', 'error': str(e)})
        }
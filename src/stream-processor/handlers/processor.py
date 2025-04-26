import json
import os
import boto3
from typing import Any, Dict

# OpenSearch configuration from environment variables
OPENSEARCH_DOMAIN = os.getenv('OPENSEARCH_DOMAIN')
if not OPENSEARCH_DOMAIN:
    raise ValueError("OPENSEARCH_DOMAIN environment variable is not set")

# Initialize the boto3 client for OpenSearch (Elasticsearch service)
client = boto3.client('es', region_name=os.getenv('AWS_REGION'))

# Index name in OpenSearch
INDEX_NAME = 'example-index'  # Adjust the index name based on your use case

def handler(event: Dict[str, Any], context: Any):
    # Log the incoming event for debugging
    print("Received event:", json.dumps(event))

    # Process each record from the event
    for record in event.get('Records', []):
        try:
            # Extract 'NewImage' from DynamoDB Stream or process it according to your data format
            new_image = record.get('dynamodb', {}).get('NewImage', None)
            
            if new_image is None:
                print("No 'NewImage' found in record:", json.dumps(record))
                continue  # Skip this record

            # Serialize the data
            document = serialize_record(new_image)
            
            # Save to OpenSearch
            response = save_to_opensearch(document)
            
            # Log the response from OpenSearch
            print(f"Document saved to OpenSearch: {response}")

        except Exception as e:
            # Log any errors for debugging
            print(f"Error processing record: {str(e)}")
            continue  # Continue processing other records

    return {
        'statusCode': 200,
        'body': json.dumps('Processing completed.')
    }

def serialize_record(record: Dict[str, Any]) -> Dict[str, Any]:
    """
    This function will serialize the incoming record into a JSON-compatible format.
    Adjust this function based on your data structure.
    """
    # Example: Flatten the data, or change types as needed
    serialized = {
        'item_id': record.get('item_id', {}).get('S', None),
        'attribute': record.get('attribute', {}).get('S', None),
        # Add other necessary fields from 'record' here
    }

    return serialized

def save_to_opensearch(document: Dict[str, Any]) -> Dict[str, Any]:
    """
    This function will save the document to OpenSearch using the boto3 client.
    """
    try:
        # Use the boto3 OpenSearch client to index the document
        response = client.index(
            index=INDEX_NAME,
            body=document,
            id=document.get('item_id')  # Optionally set a document ID
        )
        return response
    except Exception as e:
        print(f"Error indexing document to OpenSearch: {str(e)}")
        raise

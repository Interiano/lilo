import json
import os
import boto3

#boto3 the aws sdk for python
#use the execution role to access dynamodb table
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"]) #table name comes for an env var, not hardcoded

def lambda_handler(event, context):
    #write an item - policy checked for lambda execution role - testing dynamodb access
    table.put_item(Item={
        "userId": "demo-user",
        "taskId": "task-001",
        "taskName": "Read 10 pages",
        "done": True
    })

    #read back the data
    result = table.get_item(Key={"userId": "demo-user", "taskId": "task-001"})

    return {
        "statusCode": 200,
        "body": json.dumps(result.get("Item", {}))
    }

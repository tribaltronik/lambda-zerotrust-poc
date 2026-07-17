import json
from aws_lambda_powertools import Logger, Tracer
from aws_lambda_powertools.event_handler import APIGatewayRestResolver

logger = Logger()
tracer = Tracer()

@logger.inject_lambda_context
@tracer.capture_lambda_handler
def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "create_item - not yet implemented"}),
    }

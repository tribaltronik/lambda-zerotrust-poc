"""Shared Lambda Powertools configuration.

All handlers import from this module to ensure consistent
logging, tracing, and metrics across all functions.
"""
import os
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.metrics import MetricUnit

SERVICE_NAME = os.environ.get("POWERTOOLS_SERVICE_NAME", "lambda-zerotrust-poc")
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
METRICS_NAMESPACE = os.environ.get("POWERTOOLS_METRICS_NAMESPACE", "LambdaZeroTrustPOC")

logger = Logger(service=SERVICE_NAME, log_level=LOG_LEVEL)
tracer = Tracer(service=SERVICE_NAME)
metrics = Metrics(namespace=METRICS_NAMESPACE, service=SERVICE_NAME)

__all__ = ["logger", "tracer", "metrics", "MetricUnit"]

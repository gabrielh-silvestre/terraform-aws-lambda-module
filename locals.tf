locals {
  #################################################
  # ------------- SQS Event Mapping ------------- #
  #################################################
  queue_name = var.sqs_event_mapping != null ? var.resources_prefix != null ? "${var.resources_prefix}__${var.sqs_event_mapping.queue_name}" : var.sqs_event_mapping.queue_name : null
  queue      = var.sqs_event_mapping != null ? data.aws_sqs_queue.this[local.queue_name] : null

  sqs_policy = var.sqs_event_mapping != null ? {
    effect    = "Allow"
    resources = [local.queue.arn]

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
  } : null

  sqs_trigger = local.queue != null ? {
    sqs = {
      principal  = "sqs.amazonaws.com"
      source_arn = local.queue.arn
    }
  } : {}

  ###########################################
  # ------------- API Gateway ------------- #
  ###########################################
  gtw_name = var.api_gateway != null ? var.api_gateway.name != null ? var.resources_prefix != null ? "${var.resources_prefix}__${var.api_gateway.name}" : var.api_gateway.name : null : null

  api_gtw_trigger = var.api_gateway != null ? {
    api_gateway = {
      principal  = "apigateway.amazonaws.com"
      source_arn = var.api_gateway.execution_arn != null ? "${var.api_gateway.execution_arn}/*/*/*" : "${data.aws_api_gateway_rest_api.this[local.gtw_name].execution_arn}/*/*/*"
    }
  } : {}

  ###############################################
  # ------------- Lambda Function ------------- #
  ###############################################
  function_name     = var.resources_prefix != null ? "${var.resources_prefix}__${var.lambda.name}" : var.lambda.name
  function_triggers = merge(local.sqs_trigger, local.api_gtw_trigger)

  lambda_policies   = var.lambda.policies != null ? var.lambda.policies : {}
  function_policies = local.sqs_policy != null ? merge(local.lambda_policies, { sqs = local.sqs_policy }) : local.lambda_policies

  #################################################
  # ------------- S3 Package Bucket ------------- #
  #################################################
  normalized_bucket_name = var.s3 != null ? var.resources_prefix != null ? replace("${var.resources_prefix}-${var.s3.bucket}", "__", "--") : replace(var.s3.bucket, "__", "--") : null
  bucket_name            = local.normalized_bucket_name != null ? local.normalized_bucket_name : null

  create_bucket = local.bucket_name != null ? var.s3.new : false
  s3_bucket     = local.create_bucket ? resource.aws_s3_bucket.this[local.bucket_name] : var.s3 != null ? data.aws_s3_bucket.this[local.bucket_name] : null
  s3_object     = local.bucket_name != null ? resource.aws_s3_object.this[local.bucket_name] : null

  ###########################################
  # ------------- ECR Package ------------- #
  ###########################################
  image_tag = var.ecr != null ? var.ecr.stage != null ? "${var.ecr.stage}-latest" : "latest" : null
}

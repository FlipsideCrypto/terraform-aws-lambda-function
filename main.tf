locals {
  enabled     = module.this.enabled
  account_id  = local.enabled ? data.aws_caller_identity.this[0].account_id : null
  partition   = local.enabled ? data.aws_partition.this[0].partition : null
  region_name = local.enabled ? data.aws_region.this[0].name : null

  ssm_parameter_policy_enabled = try((local.enabled && var.ssm_parameter_names != null && length(var.ssm_parameter_names) > 0), false)
}

data "aws_iam_policy_document" "ssm" {
  count = local.ssm_parameter_policy_enabled ? 1 : 0

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = formatlist("arn:${local.partition}:ssm:${local.region_name}:${local.account_id}:parameter%s", var.ssm_parameter_names)
  }
}

module "role" {
  source  = "cloudposse/iam-role/aws"
  version = "0.17.0"

  policy_description = "Managed by Terraform"
  role_description   = "Managed by Terraform"

  principals = {
    Service = concat(["lambda.amazonaws.com"], var.lambda_at_edge_enabled ? ["edgelambda.amazonaws.com"] : [])
  }

  managed_policy_arns = concat([
    "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    ], var.custom_iam_policy_arns, var.cloudwatch_lambda_insights_enabled ? [
    "arn:${local.partition}:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy",
    ] : [], var.vpc_config != null ? [
    "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    ] : [], var.tracing_config_mode != null ? [
    "arn:${local.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess",
  ] : [])

  policy_documents = data.aws_iam_policy_document.ssm.*.json

  policy_document_count = local.ssm_parameter_policy_enabled ? 1 : 0

  permissions_boundary = var.permissions_boundary

  attributes = ["lambda", var.function_name]
  context    = module.this.context
}

locals {
  role_arn  = module.role.arn
  role_name = module.role.name
}

module "cloudwatch_log_group" {
  source  = "cloudposse/cloudwatch-logs/aws"
  version = "0.6.6"

  iam_role_enabled  = false
  kms_key_arn       = var.cloudwatch_logs_kms_key_arn
  retention_in_days = var.cloudwatch_logs_retention_in_days
  attributes        = ["lambda", var.function_name]
  context           = module.this.context
}

resource "aws_lambda_function" "this" {
  count = module.this.enabled ? 1 : 0

  architectures                  = var.architectures
  description                    = var.description
  filename                       = var.filename
  function_name                  = var.function_name
  handler                        = var.handler
  image_uri                      = var.image_uri
  kms_key_arn                    = var.kms_key_arn
  layers                         = var.layers
  memory_size                    = var.memory_size
  package_type                   = var.package_type
  publish                        = var.publish
  reserved_concurrent_executions = var.reserved_concurrent_executions
  role                           = local.role_arn
  runtime                        = var.runtime
  s3_bucket                      = var.s3_bucket
  s3_key                         = var.s3_key
  s3_object_version              = var.s3_object_version
  source_code_hash               = var.source_code_hash
  tags                           = var.tags
  timeout                        = var.timeout

  dynamic "dead_letter_config" {
    for_each = try(length(var.dead_letter_config_target_arn), 0) > 0 ? [true] : []

    content {
      target_arn = var.dead_letter_config_target_arn
    }
  }

  dynamic "environment" {
    for_each = var.lambda_environment != null ? [var.lambda_environment] : []
    content {
      variables = environment.value.variables
    }
  }

  dynamic "image_config" {
    for_each = length(var.image_config) > 0 ? [true] : []
    content {
      command           = lookup(var.image_config, "command", null)
      entry_point       = lookup(var.image_config, "entry_point", null)
      working_directory = lookup(var.image_config, "working_directory", null)
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_config_mode != null ? [true] : []
    content {
      mode = var.tracing_config_mode
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      security_group_ids = vpc_config.value.security_group_ids
      subnet_ids         = vpc_config.value.subnet_ids
    }
  }

  depends_on = [module.cloudwatch_log_group]

  lifecycle {
    ignore_changes = [last_modified]
  }
}

data "aws_partition" "this" {
  count = local.enabled ? 1 : 0
}

data "aws_region" "this" {
  count = local.enabled ? 1 : 0
}

data "aws_caller_identity" "this" {
  count = local.enabled ? 1 : 0
}

output "arn" {
  description = "ARN of the lambda function"
  value       = try(local.lambda.arn, null)
}

output "invoke_arn" {
  description = "Invoke ARN of the lambda function"
  value       = try(local.lambda.invoke_arn, null)
}

output "qualified_arn" {
  description = "ARN identifying your Lambda Function Version (if versioning is enabled via publish = true)"
  value       = try(local.lambda.qualified_arn, null)
}

output "function_name" {
  description = "Lambda function name"
  value       = try(local.lambda.function_name, null)
}

output "role_name" {
  description = "Lambda IAM role name"
  value       = local.role_name
}

output "role_arn" {
  description = "Lambda IAM role ARN"
  value       = local.role_arn
}

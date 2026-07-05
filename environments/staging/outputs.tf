output "api_endpoint" {
  value = module.lambda_ingestor.api_endpoint
}

output "cloudfront_domain_name" {
  value = module.frontend.cloudfront_domain_name
}

output "lambda_function_name" {
  value = module.lambda_ingestor.lambda_function_name
}

output "lambda_alias_name" {
  value = module.lambda_ingestor.lambda_alias_name
}

output "codedeploy_app_name" {
  value = module.lambda_ingestor.codedeploy_app_name
}

output "deployment_group_name" {
  value = module.lambda_ingestor.deployment_group_name
}

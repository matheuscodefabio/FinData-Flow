output "api_endpoint" { value = aws_apigatewayv2_stage.default.invoke_url }
output "lambda_arn" { value = aws_lambda_function.ingestor.arn }
output "lambda_alias_arn" { value = local.stable_alias_arn }
output "lambda_function_name" { value = aws_lambda_function.ingestor.function_name }
output "lambda_alias_name" { value = local.stable_alias_name }
output "codedeploy_app_name" {
  value = var.enable_canary ? aws_codedeploy_app.lambda[0].name : null
}

output "deployment_group_name" {
  value = var.enable_canary ? aws_codedeploy_deployment_group.lambda[0].deployment_group_name : null
}

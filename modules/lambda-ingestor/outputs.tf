output "api_endpoint"       { value = aws_apigatewayv2_stage.default.invoke_url }
output "lambda_arn"         { value = aws_lambda_function.ingestor.arn }
output "lambda_alias_arn"   { value = aws_lambda_alias.stable.arn }
output "lambda_function_name" { value = aws_lambda_function.ingestor.function_name }
output "lambda_alias_name"    { value = aws_lambda_alias.stable.name }

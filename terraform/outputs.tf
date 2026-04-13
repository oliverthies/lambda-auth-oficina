output "api_gateway_url" {
  description = "URL do API Gateway para autenticação via CPF"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_gateway_auth_endpoint" {
  description = "Endpoint completo: POST <url>/auth com body {\"cpf\": \"12345678901\"}"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/auth"
}

output "lambda_function_name" {
  description = "Nome da Lambda function"
  value       = aws_lambda_function.auth.function_name
}

output "lambda_function_arn" {
  description = "ARN da Lambda function"
  value       = aws_lambda_function.auth.arn
}

output "lambda_security_group_id" {
  description = "ID do Security Group da Lambda"
  value       = aws_security_group.lambda.id
}

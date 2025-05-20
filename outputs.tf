output "bucket_name" {
  value = aws_s3_bucket.anonymised.bucket
}

output "api_base_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.deploy.stage_name}"
}

output "api_key" {
  value     = aws_api_gateway_api_key.user.value
  sensitive = true
}

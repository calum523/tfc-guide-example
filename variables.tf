variable "region" {
  description = "AWS region"
  default     = "us-west-1"
}

variable "meraki_api_key" {
  description = "Meraki API key"
  type        = string
  sensitive   = true
}

variable "meraki_org_id" {
  description = "Meraki organization ID"
  type        = string
}

variable "collect_lambda_name" {
  description = "Name of the lambda function that collects data"
  default     = "meraki-collect"
}

variable "serve_lambda_name" {
  description = "Name of the lambda that serves anonymised data"
  default     = "meraki-serve-data"
}

variable "api_stage_name" {
  description = "Stage name for API Gateway"
  default     = "prod"
}

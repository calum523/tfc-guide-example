# Meraki Anonymised Data API

This configuration builds a simple pipeline on AWS using Terraform. It exposes an API Gateway endpoint that triggers a Lambda function to query the Meraki API, anonymise the response and store the results in an S3 bucket. Another endpoint can be used by authorised users to retrieve the latest anonymised data.

## Requirements

* AWS credentials with permission to create Lambda, API Gateway and S3 resources.
* A Meraki API key and organisation ID.

## Usage

Provide your AWS credentials using environment variables or your chosen authentication method. Set `meraki_api_key` and `meraki_org_id` variables either via Terraform Cloud workspace variables or a `terraform.tfvars` file.

Run `terraform init` and `terraform apply` to deploy. The outputs will include the API base URL and an API key to access the `/data` endpoint.

The `/collect` endpoint does not require an API key and, when invoked, will fetch data from Meraki, anonymise it and save it to the S3 bucket. Use the `/data` endpoint with the provided API key to retrieve the stored anonymised JSON.

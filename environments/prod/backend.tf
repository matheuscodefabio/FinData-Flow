terraform {
  backend "s3" {
    bucket         = "findata-tfstate-prod-ACCOUNT_ID"
    key            = "findata/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "findata-tfstate-lock"
  }
}

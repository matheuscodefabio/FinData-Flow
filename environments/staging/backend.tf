terraform {
  backend "s3" {
    bucket         = "findata-tfstate-staging-ACCOUNT_ID"
    key            = "findata/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "findata-tfstate-lock"
  }
}

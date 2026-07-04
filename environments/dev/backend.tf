terraform {
  backend "s3" {
    bucket         = "findata-tfstate-dev-ACCOUNT_ID"
    key            = "findata/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "findata-tfstate-lock"
  }
}

# Bootstrap: cria os recursos necessários para o remote state
# Rodar UMA vez antes de qualquer ambiente: terraform init && terraform apply

resource "aws_s3_bucket" "tfstate" {
  for_each = toset(["dev", "staging", "prod"])
  bucket   = "findata-tfstate-${each.key}-${data.aws_caller_identity.current.account_id}"

  tags = {
    ManagedBy = "terraform-bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  for_each = aws_s3_bucket.tfstate
  bucket   = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  for_each = aws_s3_bucket.tfstate
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  for_each                = aws_s3_bucket.tfstate
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "findata-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    ManagedBy = "terraform-bootstrap"
  }
}

data "aws_caller_identity" "current" {}

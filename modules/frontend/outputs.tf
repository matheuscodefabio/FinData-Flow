output "s3_bucket_name" {
  value       = aws_s3_bucket.frontend.id
  description = "Nome do bucket S3 do frontend"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.frontend.domain_name
  description = "Domain name da distribuição CloudFront"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.frontend.id
  description = "ID da distribuição CloudFront para invalidação"
}

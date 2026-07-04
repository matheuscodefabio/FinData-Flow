variable "environment" {
  type        = string
  description = "Nome do ambiente (dev, staging, prod)"
}

variable "cloudfront_price_class" {
  type        = string
  description = "Classe de preço CloudFront (PriceClass_All, PriceClass_100, PriceClass_200)"
  default     = "PriceClass_100" # Apenas Americas + Europe
}

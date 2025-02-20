output "cloudfront_name" {
  value = aws_cloudfront_distribution.cloudfront.domain_name
}
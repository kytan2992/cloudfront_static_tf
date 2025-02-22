output "cloudfront_name" {
  value = aws_cloudfront_distribution.cloudfront.domain_name
}

output "route53_name" {
  value = aws_route53_record.dns_bucket.name
}

# output "files" {
#   value = fileset("./static-website-example", "**/*")
# }
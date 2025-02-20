terraform {
  backend "s3" {
    bucket = "ky-s3-terraform"
    key    = "ky-tf-cloudfront-tf.tfstate"
    region = "us-east-1"
  }
}

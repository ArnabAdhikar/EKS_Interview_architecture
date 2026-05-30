terraform {
  backend "s3" {
    bucket = "three-tier-interview"
    key    = "eks/terraform.tfstate"
    region = "us-west-2"
  }
}

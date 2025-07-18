
terraform {
  backend "s3" {
    bucket         = "my-terraform-proj-zizo"
    key            = ".terraform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}

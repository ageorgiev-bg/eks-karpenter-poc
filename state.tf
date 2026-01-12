terraform {
  backend "s3" {
    bucket       = "tf-backend-347264769219"
    key          = "dev/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}


# Remote state example
# data "terraform_remote_state" "network" {
#   backend = "s3"
#   config = {
#     bucket = "terraform-state-prod"
#     key    = "network/terraform.tfstate"
#     region = "us-east-1"
#   }
# }

terraform {
  required_version = "0.12.23"

  backend "local" {
    path = "iam.tfstate"
  }
}

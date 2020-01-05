terraform {
  required_version = "0.12.18"

  backend "local" {
    path = "iam.tfstate"
  }
}

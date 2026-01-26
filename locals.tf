locals {
  skip_validation = var.environment == "dev" ? true : false
}

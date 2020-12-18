provider "google" {
  region      = var.region
  project     = var.project_id
  credentials = file(var.google_account_file)
}

terraform {
  required_version = "~> 0.14.0"
  required_providers {
    acme = {
      source = "getstackhead/acme"
      version = "1.5.0-patched"
    }
  }
  backend "remote" {
    organization = "mycert"
    workspaces {
      name = "mycert-tf"
    }
  }
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The GCP region"
}
variable "google_account_file" {
  type        = string
  description = "The account file with google credentioals to use"
}
variable "project_id" {
  type        = string
  description = "Project ID"
}
variable "subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.128.0.0/28"
}
variable "default_machine_type" {
  type        = string
  description = "The machine type for the webserver"
  default     = "e2-micro"
}

variable "domain_user" {
  type        = string
  description = "Your domain's registrar account login"
  sensitive   = true
}
variable "domain_password" {
  type        = string
  description = "Your domain's registrar account password"
  sensitive   = true
}
variable "domainname" {
  type        = string
  description = "Your domain name"
}

variable "le_endpoint" {
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
  description = "The ACME provider endpoint. The default is testing endpoint of Let's encrypt"
}
variable "email_address" {
  type        = string
  description = "The email used for ACME registration. Let's encrypt wants a real one"
}

variable "ca_certs" {
  description = "These are the signing certificates that have to be added to the CA bundle"
  type = map(object({
    filename = string
    pemurl   = string
  }))
  default = {
    fakeleintermediatex1 = {
      filename = "fakeleintermediatex1.pem"
      pemurl   = "https://letsencrypt.org/certs/fakeleintermediatex1.pem"
    },
    fakelerootx1 = {
      filename = "fakelerootx1.pem"
      pemurl   = "https://letsencrypt.org/certs/fakelerootx1.pem"
    }
  }
}

provider "acme" {
  server_url = var.le_endpoint
}
resource "tls_private_key" "cert_private_key" {
  algorithm = "RSA"
}
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.email_address
}

resource "tls_cert_request" "req" {

  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.cert_private_key.private_key_pem
  subject {
    common_name = var.domainname
  }
  dns_names = [ "*.${var.domainname}" ]
}

resource "acme_certificate" "certificate" {

  account_key_pem         = acme_registration.reg.account_key_pem
  certificate_request_pem = tls_cert_request.req.cert_request_pem

  dns_challenge {
    provider = "gcloud"
    config = {
      GCE_PROJECT              = var.project_id
      GCE_SERVICE_ACCOUNT_FILE = var.google_account_file
      GCE_POLLING_INTERVAL     = 240
      GCE_PROPAGATION_TIMEOUT  = 600
    }
  }
}

resource "null_resource" "ca_certs" {
  for_each = var.ca_certs
  provisioner "local-exec" {
    command = "curl -o ${each.value.filename} ${each.value.pemurl}"
  }
}

resource "null_resource" "ca_certs_bundle" {
  depends_on = [
    null_resource.ca_certs
  ]
  count = length(var.ca_certs)
  provisioner "local-exec" {
    command = "cat ${join(" ", [for k, v in var.ca_certs : v.filename])} > ca_certs.pem"
  }
}

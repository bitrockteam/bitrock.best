resource "google_dns_managed_zone" "myzone" {
  project     = var.project_id
  name        = "${replace(var.domainname, "/[^A-z0-9]/", "")}-zone"
  dns_name    = "${var.domainname}."
  description = "DNS zone for ${var.domainname}"
}
locals {
  nameservers = google_dns_managed_zone.myzone.name_servers
}

data "google_compute_zones" "available" {
  project = var.project_id
}

resource "google_compute_network" "webservers" {
  project                 = var.project_id
  name                    = "webservers-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "webservers" {
  project                  = var.project_id
  name                     = "webservers-subnet"
  region                   = var.region
  network                  = google_compute_network.webservers.self_link
  ip_cidr_range            = var.subnet_prefix
  private_ip_google_access = true
}

resource "google_compute_firewall" "default" {
  project = var.project_id
  name    = "default-allow-http"
  network = google_compute_network.webservers.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

data "google_compute_image" "myimage" {
  # There is a downloadable "deployment zip file" here:
  # https://console.cloud.google.com/marketplace/product/click-to-deploy-images/nginx
  # which contains the json descriptor with image name mentioned
  name  = "nginx-v20200817"
  project = "click-to-deploy-images"
}

resource "google_compute_instance_template" "mytemplate" {
  machine_type = var.default_machine_type
  project      = var.project_id

  lifecycle {
    create_before_destroy = true
  }

  scheduling {
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
    preemptible         = true
  }

  disk {
    source_image = data.google_compute_image.myimage.self_link
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = google_compute_network.webservers.self_link
    subnetwork = google_compute_subnetwork.webservers.self_link
  }

  metadata_startup_script = templatefile("${path.module}/scripts/startup-script.sh", { project = var.project_id })
  
  tags = ["web-server"]
}
resource "google_compute_region_instance_group_manager" "webservers" {
  name                      = "web-servers"
  region                    = var.region
  distribution_policy_zones = data.google_compute_zones.available.names
  project                   = var.project_id

  base_instance_name = "web"
  target_size        = "3"

  version {
    instance_template = google_compute_instance_template.mytemplate.id
  }

  named_port {
    name = "http-ingress"
    port = "80"
  }
}
resource "google_compute_health_check" "healthcheck_tcp_ingress" {

  name               = "healthcheck-tcp-webserver"
  timeout_sec        = 2
  check_interval_sec = 30

  tcp_health_check {
    port_name          = "http-ingress"
    port_specification = "USE_NAMED_PORT"

  }
}
resource "google_compute_backend_service" "webservers" {

  depends_on = [
    google_compute_region_instance_group_manager.webservers
  ]

  name      = "webservers"
  project   = var.project_id
  port_name = "http-ingress"
  protocol  = "HTTP"

  health_checks = [
    google_compute_health_check.healthcheck_tcp_ingress.self_link
  ]

  backend {
    group                 = google_compute_region_instance_group_manager.webservers.instance_group
    balancing_mode        = "RATE"
    max_rate_per_instance = 100
  }
}

resource "google_compute_url_map" "url_map" {
  depends_on = [
    google_compute_backend_service.webservers
  ]

  name            = "load-balancer"
  project         = var.project_id
  default_service = google_compute_backend_service.webservers.self_link

}

resource "google_compute_ssl_policy" "modern_tls_1_2_ssl_policy" {
  name            = "modern-tls-1-2-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "default" {
  name    = "webservers-proxy"
  url_map = google_compute_url_map.url_map.id
  ssl_certificates = concat(google_compute_ssl_certificate.lb_certificate.*.self_link)
  ssl_policy       = google_compute_ssl_policy.modern_tls_1_2_ssl_policy.self_link
}

resource "google_compute_global_forwarding_rule" "global_forwarding_rule" {
  depends_on = [
    google_compute_target_https_proxy.default
  ]

  name       = "global-forwarding-rule"
  project    = var.project_id
  port_range = "443"
  target     = google_compute_target_https_proxy.default.self_link
}

resource "google_compute_ssl_certificate" "lb_certificate" {
  project     = var.project_id
  name_prefix = "certificate-webserver"

  private_key = tls_private_key.cert_private_key.private_key_pem
  certificate = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_dns_record_set" "a-record" {
  name         = "${var.domainname}."
  managed_zone = google_dns_managed_zone.myzone.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_forwarding_rule.global_forwarding_rule.ip_address]
}
resource "google_dns_record_set" "cname-record" {
  name         = "*.${var.domainname}."
  managed_zone = google_dns_managed_zone.myzone.name
  type         = "CNAME"
  ttl          = 300

  rrdatas = ["${var.domainname}."]
}
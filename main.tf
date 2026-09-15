locals {
  name = "vprofile"

  subnets = {
    public-01  = "172.20.1.0/24"
    public-02  = "172.20.2.0/24"
    private-01 = "172.20.3.0/24"
    private-02 = "172.20.4.0/24"
  }
}

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "dns.googleapis.com",
    "sqladmin.googleapis.com",
    "memcache.googleapis.com",
    "certificatemanager.googleapis.com",
    "servicenetworking.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnets" {
  for_each      = local.subnets
  name          = each.key
  ip_cidr_range = each.value
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_router" "router" {
  name    = "${local.name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${local.name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "ssh_bastion" {
  name    = "allow-ssh-internet"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction     = "INGRESS"
  source_ranges = [var.admin_cidr]
  target_tags   = ["bastion"]
}

resource "google_compute_firewall" "ssh_from_bastion" {
  name    = "allow-ssh-bastion"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction   = "INGRESS"
  source_tags = ["bastion"]
  target_tags = ["app"]
}

resource "google_compute_firewall" "load_balancer" {
  name    = "allow-lb-to-app"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  direction     = "INGRESS"
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["app"]
}

resource "google_compute_global_address" "sql_psa" {
  name          = "google-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_psa.name]
  deletion_policy         = "ABANDON"
  depends_on              = [google_project_service.apis]
}

resource "google_sql_database_instance" "db" {
  name             = "${local.name}-db"
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled       = false
      private_network    = google_compute_network.vpc.id
      allocated_ip_range = google_compute_global_address.sql_psa.name
    }
  }

  deletion_protection = false
  depends_on          = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "accounts" {
  name     = "accounts"
  instance = google_sql_database_instance.db.name
}

resource "google_sql_user" "root" {
  name     = "root"
  instance = google_sql_database_instance.db.name
  password = var.db_password
  host     = "%"
}

resource "google_memcache_instance" "memcache" {
  name               = "${local.name}-memcache"
  region             = var.region
  node_count         = 1
  authorized_network = google_compute_network.vpc.id

  node_config {
    cpu_count      = 2
    memory_size_mb = 2048
  }
}

resource "google_dns_managed_zone" "private" {
  name        = "${local.name}-private"
  dns_name    = "${var.private_dns_name}."
  description = "Private DNS for VProfile"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
}

resource "google_dns_record_set" "db" {
  name         = "vprodb.${var.private_dns_name}."
  managed_zone = google_dns_managed_zone.private.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_sql_database_instance.db.private_ip_address]
}

resource "google_dns_record_set" "memcache" {
  name         = "vpromc.${var.private_dns_name}."
  managed_zone = google_dns_managed_zone.private.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_memcache_instance.memcache.memcache_nodes[0].host]
}

resource "google_compute_instance" "bastion" {
  name         = "bastion"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["bastion"]

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnets["public-01"].id
    access_config {}
  }

  metadata_startup_script = templatefile("${path.module}/templates/bastion-startup.sh.tftpl", {
    ssh_public_key = var.ssh_public_key
  })
}

resource "google_compute_instance_template" "app" {
  name_prefix  = "${local.name}-template-"
  machine_type = var.app_machine_type
  tags         = ["app"]

  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnets["private-01"].id
  }

  metadata_startup_script = templatefile("${path.module}/templates/app-startup.sh.tftpl", {
    ssh_public_key = var.ssh_public_key
    db_password    = var.db_password
    app_repository = var.app_repository
    app_branch     = var.app_branch
  })

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "app" {
  name               = "${local.name}-mig"
  zone               = var.zone
  base_instance_name = "${local.name}-app"
  target_size        = var.initial_app_instances

  version {
    instance_template = google_compute_instance_template.app.self_link
  }

  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.app.id
    initial_delay_sec = 900
  }
}

resource "google_compute_autoscaler" "app" {
  name   = "${local.name}-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.app.id

  autoscaling_policy {
    min_replicas    = var.min_app_instances
    max_replicas    = var.max_app_instances
    cooldown_period = 300

    cpu_utilization {
      target = 0.6
    }
  }
}

resource "google_compute_health_check" "app" {
  name                = "${local.name}-hc"
  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 4

  http_health_check {
    port         = 8080
    request_path = "/"
  }
}

resource "google_compute_backend_service" "app" {
  name                  = "${local.name}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.app.id]

  backend {
    group           = google_compute_instance_group_manager.app.instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
  }
}

resource "google_compute_url_map" "app" {
  name            = "${local.name}-urlmap"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_target_http_proxy" "app" {
  name    = "${local.name}-http-proxy"
  url_map = google_compute_url_map.app.id
}

resource "google_compute_global_address" "load_balancer" {
  name = "${local.name}-lb-ip"
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${local.name}-http-lb"
  target                = google_compute_target_http_proxy.app.id
  port_range            = "80"
  ip_address            = google_compute_global_address.load_balancer.address
  load_balancing_scheme = "EXTERNAL"
}

resource "google_certificate_manager_dns_authorization" "app" {
  count       = var.enable_https ? 1 : 0
  name        = "auth-${var.subdomain}"
  domain      = var.domain
  description = "DNS authorization for VProfile managed certificate"
}

resource "google_certificate_manager_certificate" "app" {
  count = var.enable_https ? 1 : 0
  name  = "cert-${var.subdomain}"
  scope = "DEFAULT"
  managed {
    domains            = ["*.${var.domain}"]
    dns_authorizations = [google_certificate_manager_dns_authorization.app[0].id]
  }
}

resource "google_certificate_manager_certificate_map" "app" {
  count = var.enable_https ? 1 : 0
  name  = "map-${var.subdomain}"
}

resource "google_certificate_manager_certificate_map_entry" "app" {
  count        = var.enable_https ? 1 : 0
  name         = "entry-${var.subdomain}"
  map          = google_certificate_manager_certificate_map.app[0].name
  certificates = [google_certificate_manager_certificate.app[0].id]
  hostname     = "*.${var.domain}"
}

resource "google_compute_target_https_proxy" "app" {
  count           = var.enable_https ? 1 : 0
  name            = "${local.name}-https-proxy"
  url_map         = google_compute_url_map.app.id
  certificate_map = "//certificatemanager.googleapis.com/projects/${var.project_id}/locations/global/certificateMaps/${google_certificate_manager_certificate_map.app[0].name}"
}

resource "google_compute_global_forwarding_rule" "https" {
  count                 = var.enable_https ? 1 : 0
  name                  = "${local.name}-https-lb"
  target                = google_compute_target_https_proxy.app[0].id
  port_range            = "443"
  ip_address            = google_compute_global_address.load_balancer.address
  load_balancing_scheme = "EXTERNAL"
}
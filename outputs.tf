output "load_balancer_ip" {
  description = "Global IP for the HTTP and HTTPS load balancers"
  value       = google_compute_global_address.load_balancer.address
}

output "application_url" {
  description = "Application URL"
  value       = var.enable_https ? "https://${var.subdomain}.${var.domain}" : "http://${var.subdomain}.${var.domain}"
}

output "bastion_ip" {
  description = "Public IP of the bastion host"
  value       = google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip
}

output "certificate_dns_record" {
  description = "CNAME record that must be created at the external DNS registrar"
  value = var.enable_https ? {
    name = google_certificate_manager_dns_authorization.app[0].dns_resource_record[0].name
    type = google_certificate_manager_dns_authorization.app[0].dns_resource_record[0].type
    data = google_certificate_manager_dns_authorization.app[0].dns_resource_record[0].data
  } : null
}

output "cloud_sql_private_ip" {
  description = "Private IP of Cloud SQL"
  value       = google_sql_database_instance.db.private_ip_address
}
variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP zone for the zonal MIG and bastion"
  default     = "us-central1-a"
}

variable "domain" {
  type        = string
  description = "Registered DNS domain used by the managed certificate"
}

variable "subdomain" {
  type        = string
  description = "Application subdomain label used in resource names"
  default     = "vprogcp"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to SSH to the bastion, normally your public IP with /32"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key installed for the devops user"
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "Cloud SQL root password"
  sensitive   = true
}

variable "app_repository" {
  type        = string
  description = "Git repository cloned by app instances"
  default     = "https://github.com/hkhcoder/vprofile-project.git"
}

variable "app_branch" {
  type        = string
  description = "Git branch built by app instances"
  default     = "gcp"
}

variable "app_machine_type" {
  type        = string
  description = "Machine type for each application instance"
  default     = "e2-small"
}

variable "initial_app_instances" {
  type        = number
  description = "Initial number of application instances"
  default     = 2
}

variable "min_app_instances" {
  type        = number
  description = "Minimum autoscaled application instances"
  default     = 2
}

variable "max_app_instances" {
  type        = number
  description = "Maximum autoscaled application instances"
  default     = 4
}

variable "enable_https" {
  type        = bool
  description = "Create Certificate Manager resources and HTTPS forwarding"
  default     = true
}

variable "private_dns_name" {
  type        = string
  description = "Private DNS suffix used by the application"
  default     = "vprofile.internal"
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to supported resources"
  default = {
    application = "vprofile"
    managed-by  = "terraform"
  }
}
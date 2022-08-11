terraform {
  required_version = "1.2.6"
  required_providers {
    google = {
      # see https://registry.terraform.io/providers/hashicorp/google
      source = "hashicorp/google"
      version = "4.31.0"
    }
  }
}

provider "google" {
  project = var.project
  region = var.region
}

variable "project" {
}

variable "region" {
}

output "ca" {
  value = google_sql_database_instance.example.server_ca_cert.0.cert
}

output "ip_address" {
  value = google_sql_database_instance.example.public_ip_address
}

output "password" {
  value = google_sql_user.postgres.password
  sensitive = true
}

output "key" {
  value = google_sql_ssl_cert.postgres.private_key
  sensitive = true
}

output "crt" {
  value = google_sql_ssl_cert.postgres.cert
}

resource "random_password" "postgres" {
  length = 16
}

# TODO enable automated backups.
# TODO enable point-in-time recovery.
resource "google_sql_database_instance" "example" {
  name = "example"
  database_version = "POSTGRES_14"
  deletion_protection = true
  settings {
    tier = "db-f1-micro"
    ip_configuration  {
      ipv4_enabled = true
      require_ssl = true
      authorized_networks {
        name = "all"
        value = "0.0.0.0/0"
      }
    }
  }
}

resource "google_sql_ssl_cert" "postgres" {
  common_name = "postgres"
  instance = google_sql_database_instance.example.name
}

resource "google_sql_user" "postgres" {
  name = "postgres"
  password = random_password.postgres.result
  instance = google_sql_database_instance.example.name
}

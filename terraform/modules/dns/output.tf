output "public_dns_zone" {
  value = google_dns_managed_zone.public_zone
}

output "private_dns_zone" {
  value = google_dns_managed_zone.private_zone
}
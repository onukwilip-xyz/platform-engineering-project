resource "netbird_group" "routing_peers" {
  name = var.netbird_routing_peer_group_name
}

data "netbird_group" "all" {
  name = "All"
}
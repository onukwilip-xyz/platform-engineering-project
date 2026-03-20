resource "netbird_route" "vpc_subnet" {
  description = "Route VPC subnet traffic through routing peer"
  network_id  = "vpc-internal-route"    # Logical ID within Netbird
  enabled     = true

  # The CIDR you want VPN clients to reach via the routing peer
  network     = var.vpc_subnet_cidr

  # Masquerade = the peer NATs traffic so responses route back correctly
  masquerade  = true
  metric      = 9999

  peer_groups = [ netbird_group.routing_peers.id ]
  groups = [ data.netbird_group.all.id ]

  depends_on = [ netbird_group.routing_peers ]
}
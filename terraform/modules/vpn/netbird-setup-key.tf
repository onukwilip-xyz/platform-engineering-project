resource "netbird_setup_key" "routing_peer" {
  name        = var.netbird_routing_peer_setup_key_name
  type        = "reusable"
  usage_limit = 1                # Single-use
  auto_groups = [ netbird_group.routing_peers.id ]               # Assign groups here if needed
  expires_in  = 86400            # 24 hours — enough for first boot
  revoked     = false

  depends_on = [ netbird_group.routing_peers ]
}
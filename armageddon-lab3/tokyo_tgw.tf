# Explanation: Shinjuku Station is the hub—Tokyo is the data authority.
resource "aws_ec2_transit_gateway" "armageddon_shinjuku_tgw01" {
  description = "armageddon-shinjuku-tgw01 (Tokyo hub)"
  tags = { Name = "armageddon-shinjuku-tgw01" }
}

# Explanation: Shinjuku connects to the Tokyo VPC—this is the gate to the medical records vault.
resource "aws_ec2_transit_gateway_vpc_attachment" "armageddon_shinjuku_attach_tokyo_vpc01" {
  transit_gateway_id = aws_ec2_transit_gateway.armageddon_shinjuku_tgw01.id
  vpc_id             = aws_vpc.main_vpc.id
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "shinjuku-attach-tokyo-vpc01" }
}

# Explanation: Shinjuku opens a corridor request to Liberdade—compute may travel, data may not.
resource "aws_ec2_transit_gateway_peering_attachment" "armageddon_shinjuku_to_liberdade_peer01" {
  transit_gateway_id      = aws_ec2_transit_gateway.armageddon_shinjuku_tgw01.id
  peer_region             = "sa-east-1"
  peer_transit_gateway_id = aws_ec2_transit_gateway.armageddon_liberdade_tgw01.id # created in Sao Paulo module/state
  tags = { Name = "shinjuku-to-liberdade-peer01" }
}

resource "aws_ec2_transit_gateway_route" "shinjuku_to_sao" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway.armageddon_shinjuku_tgw01.association_default_route_table_id
  destination_cidr_block         = "10.80.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.armageddon_shinjuku_to_liberdade_peer01.id

    depends_on = [
    aws_ec2_transit_gateway_peering_attachment_accepter.armageddon_liberdade_accept_peer01]
}

resource "aws_route" "tokyo_ec2lab_to_sao" {
  route_table_id         = "rtb-042e90d2f8095db2e" # get current 
  destination_cidr_block = "10.80.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.armageddon_shinjuku_tgw01.id
}


# run this in CLI to get route_table_id
# aws ec2 describe-route-tables --region ap-northeast-1 \
#   --filters "Name=association.subnet-id,Values=<SUBNET ID>" \
#   --query "RouteTables[0].RouteTableId" --output text

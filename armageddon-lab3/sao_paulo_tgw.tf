# Explanation: Liberdade is São Paulo’s Japanese town—local doctors, local compute, remote data.
resource "aws_ec2_transit_gateway" "armageddon_liberdade_tgw01" {
  provider    = aws.saopaulo
  description = "armageddon-liberdade-tgw01 (Sao Paulo spoke)"
  tags = { Name = "armageddon-liberdade-tgw01" }
}

# Explanation: Liberdade accepts the corridor from Shinjuku—permissions are explicit, not assumed.
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "armageddon_liberdade_accept_peer01" {
  provider                      = aws.saopaulo
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.armageddon_shinjuku_to_liberdade_peer01.id
  tags = { Name = "armageddon-liberdade-accept-peer01" }
}

# Explanation: Liberdade attaches to its VPC—compute can now reach Tokyo legally, through the controlled corridor.
resource "aws_ec2_transit_gateway_vpc_attachment" "armageddon_liberdade_attach_sp_vpc01" {
  provider           = aws.saopaulo
  transit_gateway_id = aws_ec2_transit_gateway.armageddon_liberdade_tgw01.id
  vpc_id             = aws_vpc.sao_main_vpc.id
  subnet_ids         = [aws_subnet.sao_private[0].id, aws_subnet.sao_private[1].id]
  tags = { Name = "armageddon-liberdade-attach-sp-vpc01" }
}

resource "aws_ec2_transit_gateway_route" "liberdade_to_tokyo" {
  provider                       = aws.saopaulo
  transit_gateway_route_table_id = aws_ec2_transit_gateway.armageddon_liberdade_tgw01.association_default_route_table_id
  destination_cidr_block         = "10.30.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.armageddon_liberdade_accept_peer01.id
}

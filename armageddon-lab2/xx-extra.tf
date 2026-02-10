# resource "aws_subnet" "public_a" {
#   vpc_id     = aws_vpc.main_vpc.id
#   cidr_block = "10.30.1.0/24"
#   availability_zone = var.azs[0]
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "public-a"
#   }
# }

# resource "aws_subnet" "public_b" {
#   vpc_id     = aws_vpc.main_vpc.id
#   cidr_block = "10.30.2.0/24"
#   availability_zone = var.azs[1]
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "public-b"
#   }
# }

# resource "aws_subnet" "public_c" {
#   vpc_id     = aws_vpc.main_vpc.id
#   cidr_block = "10.30.3.0/24"
#   availability_zone = var.azs[2]
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "public-c"
#   }
# }

# resource "aws_subnet" "private_a" {
#   vpc_id     = aws_vpc.main_vpc.id
#   cidr_block = "10.30.11.0/24"
#   availability_zone = "us-east-2a"
#   map_public_ip_on_launch = false

#   tags = {
#     Name = "private-a"
#   }
# }

# resource "aws_subnet" "private_b" {
#   vpc_id     = aws_vpc.main_vpc.id
#   cidr_block = "10.30.12.0/24"
#   availability_zone = "us-east-2b"
#   map_public_ip_on_launch = false

#   tags = {
#     Name = "private-b"
#   }
# }

# resource "aws_subnet" "private_c" {
#   vpc_id     = aws_vpc.main_vpc.id
#   cidr_block = "10.30.13.0/24"
#   availability_zone = "us-east-2c"
#   map_public_ip_on_launch = false

#   tags = {
#     Name = "private-c"
#   }
# }

# resource "aws_route_table_association" "public_us_east_2a" {
#   subnet_id      = aws_subnet.public_a.id
#   route_table_id = aws_route_table.public_route.id
# }

# resource "aws_route_table_association" "public_us_east_2b" {
#   subnet_id      = aws_subnet.public_b.id
#   route_table_id = aws_route_table.public_route.id
# }

# resource "aws_route_table_association" "public_us_east_2c" {
#   subnet_id      = aws_subnet.public_c.id
#   route_table_id = aws_route_table.public_route.id
# }

# resource "aws_route_table_association" "private_us_east_2a" {
#   subnet_id      = aws_subnet.private_a.id
#   route_table_id = aws_route_table.private_route.id
# }

# resource "aws_route_table_association" "private_us_east_2b" {
#   subnet_id      = aws_subnet.private_b.id
#   route_table_id = aws_route_table.private_route.id
# }

# resource "aws_route_table_association" "private_us_east_2c" {
#   subnet_id      = aws_subnet.private_c.id
#   route_table_id = aws_route_table.private_route.id
# }

# resource "aws_route53_record" "armageddon_record" {
#   for_each = var.certificate_validation_method == "DNS" ? {
#     for dvo in aws_acm_certificate.armageddon_acm_cert01.domain_validation_options :
#     dvo.domain_name => {
#       name   = dvo.resource_record_name
#       type   = dvo.resource_record_type
#       record = dvo.resource_record_value
#     }
#   } : {}


#   zone_id = local.armageddon_zone_id
#   name    = each.value.name
#   type    = each.value.type
#   ttl     = 60
#   records = [each.value.record]
# }

# certificate_arn   = aws_acm_certificate_validation.armageddon_acm_validation01[0].certificate_arn
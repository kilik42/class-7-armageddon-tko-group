Building out an infrastructure with terraform, each lab build off the last. Build a complete system that mirrors a work environment  

VPC, with both public/private subnets, IGW, NAT, routing
EC2 with IAM role/profile
RDS(private), subnets, and SG 3306 inbound rule
Secret Manager and Parameter Store
CloudWatch Log Group
CloudWatch alarms
SNS topic and subscription

ALB, Listener, TG
Route 53, Apex zones, S3 buckets
WAF logs, Firehose

Building off LAB 1, we are now adding:
CLoudfront, origins, origin cloaking
Invalidation

Finally building off Labs 1/2
we add a satellite database 
using Tokyo as the main
and Sao Paulo as the satellite 
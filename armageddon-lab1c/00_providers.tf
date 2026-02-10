provider "aws" {
  region = var.region
}

# When wanting to use a different region us this: Ex. terraform apply -var="aws_region=us-west-2"

# Virginia = us-east-1 
# Ohio = us-east-2
# Oregon = us-west-2
# Thailand = ap-southeast-7
# Tokyo = ap-northeast-1
# Spain = eu-south-2
# Sao Paulo = sa-east-1 
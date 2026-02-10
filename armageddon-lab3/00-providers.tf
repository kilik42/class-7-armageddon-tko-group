provider "aws" {
  region = "ap-northeast-1"
}


provider "aws" {
  alias  = "saopaulo"
  region = "sa-east-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}



terraform {
  required_version = ">= 1.5"
  required_providers {
    aws    = { source = "hashicorp/aws",    version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" { region = var.aws_region }
 
resource "random_string" "suffix" { length=6; special=false; upper=false }
 
module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "5.1.2"
  name               = "payday-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["${var.aws_region}a","${var.aws_region}b"]
  private_subnets    = ["10.0.1.0/24","10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24","10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  tags               = { Project = "payday-devops" }
}
 
module "eks" {
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "20.8.5"
  cluster_name                   = var.cluster_name
  cluster_version                = "1.29"
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      instance_types = ["t3.medium"]
    }
  }
  tags = { Project = "payday-devops" }
}
 
resource "aws_ecr_repository" "repos" {
  for_each             = toset(["frontend","api","worker"])
  name                 = "payday/${each.key}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
 
resource "aws_s3_bucket" "velero" {
  bucket = "payday-velero-${random_string.suffix.result}"
  tags   = { Project = "payday-devops" }
}
resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id
  versioning_configuration { status = "Enabled" }
}
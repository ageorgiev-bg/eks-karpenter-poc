data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "eks_clu" {
  name = var.cluster_name

  depends_on = [
    aws_eks_cluster.eks_clu
  ]
}

provider "aws" {
  region = var.region
}

provider "aws" {
  region = "eu-west-1"
  alias  = "euw1"
}


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"
    }
  }
  required_version = "~> 1.13.2"
}


provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.eks_clu.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_clu.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_clu.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_clu.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"

  }
}
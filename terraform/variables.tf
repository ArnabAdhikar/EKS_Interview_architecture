variable "cluster_name" {
  type = string
  default = "my-eks-cluster"
}

variable "cluster_version" {
  type = string
  default = "1.31"
}

variable "region" {
  type = string
  default = "us-west-2"
}

variable "availability_zones" {
  type = list(string)
  default = ["us-west-2a", "us-west-2b"]
}



variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))

  default = [
    {
      name    = "kube-proxy"
      version = "v1.31.0-eksbuild.2"
    },
    {
      name    = "vpc-cni"
      version = "v1.18.3-eksbuild.1"
    },
    {
      name    = "coredns"
      version = "v1.11.3-eksbuild.1"
    },
    {
      name    = "aws-ebs-csi-driver"
      version = "v1.34.0-eksbuild.1"
    }
  ]
}
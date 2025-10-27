resource "helm_release" "karpenter" {
  name = "karpenter"

  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.2.1"
  namespace        = "karpenter"
  create_namespace = true
  force_update     = true
  lint             = true
  wait             = true

  # set {
  #   name  = "settings.interruptionQueue"
  #   value = var.cluster_name
  # }

  set = [
    {
      name  = "settings.clusterName"
      value = var.cluster_name
      }, {
      name  = "controller.resources.requests.cpu"
      value = 1
      }, {

      name  = "controller.resources.requests.memory"
      value = "1Gi"
      }, {

      name  = "controller.resources.limits.cpu"
      value = 1
      }, {

      name  = "controller.resources.limits.memory"
      value = "1Gi"
    }
  ]

  depends_on = [aws_eks_cluster.eks_clu, helm_release.metrics_server]
}

resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = var.cluster_name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller.arn
}

################

### EKS/Karpenter Worker node role

data "aws_iam_policy_document" "karpenter_nodes" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "karpenter_nodes" {
  name               = "KarpenterNodeRole-${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_nodes.json
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_nodes.name
}


resource "aws_iam_role_policy_attachment" "AWSSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_nodes.name
}

##### Karpenter Controller Role for Pod Identity

resource "aws_iam_role" "karpenter_controller" {
  name = "karpenter-controller-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_attachment" {
  policy_arn = aws_iam_policy.karpenter_controller.arn
  role       = aws_iam_role.karpenter_controller.name
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.cluster_name}-karpenter-controller"
  description = "Karpenter Controller Policy"

  policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowScopedEC2InstanceAccessActions",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:ec2:${var.region}::image/*",
                "arn:aws:ec2:${var.region}::snapshot/*",
                "arn:aws:ec2:${var.region}:*:security-group/*",
                "arn:aws:ec2:${var.region}:*:subnet/*"
            ],
            "Action": [
                "ec2:RunInstances",
                "ec2:CreateFleet"
            ]
        },
        {
            "Sid": "AllowScopedEC2LaunchTemplateAccessActions",
            "Effect": "Allow",
            "Resource": "arn:aws:ec2:${var.region}:*:launch-template/*",
            "Action": [
                "ec2:RunInstances",
                "ec2:CreateFleet"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}": "owned"
                },
                "StringLike": {
                    "aws:ResourceTag/karpenter.sh/nodepool": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedEC2InstanceActionsWithTags",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:ec2:${var.region}:*:fleet/*",
                "arn:aws:ec2:${var.region}:*:instance/*",
                "arn:aws:ec2:${var.region}:*:volume/*",
                "arn:aws:ec2:${var.region}:*:network-interface/*",
                "arn:aws:ec2:${var.region}:*:launch-template/*",
                "arn:aws:ec2:${var.region}:*:spot-instances-request/*"
            ],
            "Action": [
                "ec2:RunInstances",
                "ec2:CreateFleet",
                "ec2:CreateLaunchTemplate"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
                    "aws:RequestTag/eks:eks-cluster-name": "${var.cluster_name}"
                },
                "StringLike": {
                    "aws:RequestTag/karpenter.sh/nodepool": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedResourceCreationTagging",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:ec2:${var.region}:*:fleet/*",
                "arn:aws:ec2:${var.region}:*:instance/*",
                "arn:aws:ec2:${var.region}:*:volume/*",
                "arn:aws:ec2:${var.region}:*:network-interface/*",
                "arn:aws:ec2:${var.region}:*:launch-template/*",
                "arn:aws:ec2:${var.region}:*:spot-instances-request/*"
            ],
            "Action": "ec2:CreateTags",
            "Condition": {
                "StringEquals": {
                    "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
                    "aws:RequestTag/eks:eks-cluster-name": "${var.cluster_name}",
                    "ec2:CreateAction": [
                        "RunInstances",
                        "CreateFleet",
                        "CreateLaunchTemplate"
                    ]
                },
                "StringLike": {
                    "aws:RequestTag/karpenter.sh/nodepool": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedResourceTagging",
            "Effect": "Allow",
            "Resource": "arn:aws:ec2:${var.region}:*:instance/*",
            "Action": "ec2:CreateTags",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}": "owned"
                },
                "StringLike": {
                    "aws:ResourceTag/karpenter.sh/nodepool": "*"
                },
                "StringEqualsIfExists": {
                    "aws:RequestTag/eks:eks-cluster-name": "${var.cluster_name}"
                },
                "ForAllValues:StringEquals": {
                    "aws:TagKeys": [
                        "eks:eks-cluster-name",
                        "karpenter.sh/nodeclaim",
                        "Name"
                    ]
                }
            }
        },
        {
            "Sid": "AllowScopedDeletion",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:ec2:${var.region}:*:instance/*",
                "arn:aws:ec2:${var.region}:*:launch-template/*"
            ],
            "Action": [
                "ec2:TerminateInstances",
                "ec2:DeleteLaunchTemplate"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}": "owned"
                },
                "StringLike": {
                    "aws:ResourceTag/karpenter.sh/nodepool": "*"
                }
            }
        },
        {
            "Sid": "AllowRegionalReadActions",
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypeOfferings",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSpotPriceHistory",
                "ec2:DescribeSubnets"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:RequestedRegion": "${var.region}"
                }
            }
        },
        {
            "Sid": "AllowSSMReadActions",
            "Effect": "Allow",
            "Resource": "arn:aws:ssm:${var.region}::parameter/aws/service/*",
            "Action": "ssm:GetParameter"
        },
        {
            "Sid": "AllowPricingReadActions",
            "Effect": "Allow",
            "Resource": "*",
            "Action": "pricing:GetProducts"
        },
        {
            "Sid": "AllowInterruptionQueueActions",
            "Effect": "Allow",
            "Resource": "arn:aws:sqs:${var.region}:${local.account_id}:*",
            "Action": [
                "sqs:DeleteMessage",
                "sqs:GetQueueUrl",
                "sqs:ReceiveMessage"
            ]
        },
        {
            "Sid": "AllowPassingInstanceRole",
            "Effect": "Allow",
            "Resource": "arn:aws:iam::${local.account_id}:role/${aws_iam_role.karpenter_nodes.name}",
            "Action": "iam:PassRole",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": [
                        "ec2.amazonaws.com",
                        "ec2.amazonaws.com.cn"
                    ]
                }
            }
        },
        {
            "Sid": "AllowScopedInstanceProfileCreationActions",
            "Effect": "Allow",
            "Resource": "arn:aws:iam::${local.account_id}:instance-profile/*",
            "Action": [
                "iam:CreateInstanceProfile"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
                    "aws:RequestTag/eks:eks-cluster-name": "${var.cluster_name}",
                    "aws:RequestTag/topology.kubernetes.io/region": "${var.region}"
                },
                "StringLike": {
                    "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedInstanceProfileTagActions",
            "Effect": "Allow",
            "Resource": "arn:aws:iam::${local.account_id}:instance-profile/*",
            "Action": [
                "iam:TagInstanceProfile"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
                    "aws:ResourceTag/topology.kubernetes.io/region": "${var.region}",
                    "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
                    "aws:RequestTag/eks:eks-cluster-name": "${var.cluster_name}",
                    "aws:RequestTag/topology.kubernetes.io/region": "${var.region}"
                },
                "StringLike": {
                    "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*",
                    "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedInstanceProfileActions",
            "Effect": "Allow",
            "Resource": "arn:aws:iam::${local.account_id}:instance-profile/*",
            "Action": [
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeleteInstanceProfile"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
                    "aws:ResourceTag/topology.kubernetes.io/region": "${var.region}"
                },
                "StringLike": {
                    "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*"
                }
            }
        },
        {
            "Sid": "AllowInstanceProfileReadActions",
            "Effect": "Allow",
            "Resource": "arn:aws:iam::${local.account_id}:instance-profile/*",
            "Action": "iam:GetInstanceProfile"
        },
        {
            "Sid": "AllowAPIServerEndpointDiscovery",
            "Effect": "Allow",
            "Resource": "arn:aws:eks:${var.region}:${local.account_id}:cluster/${var.cluster_name}",
            "Action": "eks:DescribeCluster"
        }
    ]
}
EOT
}


# Manifests

resource "kubernetes_manifest" "karpenter_default_ec2_node_class" {
  count           = 0
  computed_fields = ["spec.requirements"]
  manifest = yamldecode(<<YAML
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: "${aws_iam_role.karpenter_nodes.name}"
  amiSelectorTerms: 
  - alias: bottlerocket@latest # must change for regions that are not us-east-1
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${var.cluster_name}
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${var.cluster_name}
  tags:
    IntentLabel: apps
    KarpenterNodePoolName: default
    # NodeType: default
    intent: apps
    karpenter.sh/discovery: ${var.cluster_name}
    project: karpenter-blueprints
YAML
  )
  depends_on = [
    aws_eks_cluster.eks_clu,
    helm_release.karpenter
  ]
}

resource "kubernetes_manifest" "karpenter_default_node_pool" {
  count = 0
  manifest = yamldecode(<<YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default 
spec: 
  template:
    metadata:
      name: default
      labels:
        intent: apps
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["2","4", "8", "16", "32", "48", "64"]
        - key: "karpenter.k8s.aws/instance-memory"
          operator: Gt
          values: ["2000"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r", "t"]
      nodeClassRef:
        name: default
        group: karpenter.k8s.aws
        kind: EC2NodeClass
  limits:
    cpu: 1000
    memory: 1000Gi 
  disruption:
    consolidationPolicy: WhenEmpty #OrUnderutilized
    consolidateAfter: 3m
    expireAfter: Never
YAML
  )
  depends_on = [
    aws_eks_cluster.eks_clu,
    helm_release.karpenter,
    kubernetes_manifest.karpenter_default_ec2_node_class,
  ]
}
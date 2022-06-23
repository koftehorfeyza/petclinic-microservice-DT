resource "aws_iam_policy" "policy_for_master_role" {
  name        = "policy_for_master_role"
  policy      = file("./modules/IAM/policy_for_master.json")
}

resource "aws_iam_policy" "policy_for_worker_role" {
  name        = "policy_for_worker_role"
  policy      = file("./modules/IAM/policy_for_worker.json")
}

resource "aws_iam_role" "role_for_master" {
  name = "role_master_k8s"

  # Terraform "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "role_for_master"
  }
}

resource "aws_iam_role" "role_for_worker" {
  name = "role_worker_k8s"

  # Terraform "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "role_for_worker"
  }
}

resource "aws_iam_policy_attachment" "attach_for_master" {
  name       = "attachment_for_master"
  roles      = [aws_iam_role.role_for_master.name]
  policy_arn = aws_iam_policy.policy_for_master_role.arn
}

resource "aws_iam_policy_attachment" "attach_for_worker" {
  name       = "attachment_for_worker"
  roles      = [aws_iam_role.role_for_worker.name]
  policy_arn = aws_iam_policy.policy_for_worker_role.arn
}

resource "aws_iam_instance_profile" "profile_for_master" {
  name  = "profile_for_master"
  role = aws_iam_role.role_for_master.name
}

resource "aws_iam_instance_profile" "profile_for_worker" {
  name  = "profile_for_worker"
  role = aws_iam_role.role_for_worker.name
}

output master_profile_name {
  value       = aws_iam_instance_profile.profile_for_master.name
}

output worker_profile_name {
  value       = aws_iam_instance_profile.profile_for_worker.name
}
```

- Prepare a terraform file for kubernetes Infrastructure consisting of 1 master, 2 Worker Nodes and save it as `main.tf` under the `infrastructure/dev-k8s-terraform`.

```go
provider "aws" {
  region  = "us-east-1"
}

module "iam" {
  source = "./modules/IAM"
}

resource "aws_security_group" "matt-kube-mutual-sg" {
  name = "kube-mutual-sec-group-for-matt"
}

resource "aws_security_group" "matt-kube-worker-sg" {
  name = "kube-worker-sec-group-for-matt"
  ingress {
    protocol = "tcp"
    from_port = 10250
    to_port = 10250
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 30000
    to_port = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "udp"
    from_port = 8472
    to_port = 8472
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  
  egress{
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "kube-worker-secgroup"
    "kubernetes.io/cluster/mattsCluster" = "owned"
  }
}

resource "aws_security_group" "matt-kube-master-sg" {
  name = "kube-master-sec-group-for-matt"

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol = "tcp"
    from_port = 6443
    to_port = 6443
    cidr_blocks = ["0.0.0.0/0"]
    #security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol = "tcp"
    from_port = 2380
    to_port = 2380
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 2379
    to_port = 2379
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 10250
    to_port = 10250
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 10251
    to_port = 10251
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 10252
    to_port = 10252
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 30000
    to_port = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol = "udp"
    from_port = 8472
    to_port = 8472
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "kube-master-secgroup"
  }
}

resource "aws_instance" "kube-master" {
    ami = "ami-013f17f36f8b1fefb"
    instance_type = "t2.medium"
    iam_instance_profile = module.iam.master_profile_name
    vpc_security_group_ids = [aws_security_group.matt-kube-master-sg.id, aws_security_group.matt-kube-mutual-sg.id]
    key_name = "mattkey"
    subnet_id = "subnet-c41ba589"  # select own subnet_id of us-east-1a
    availability_zone = "us-east-1a"
    tags = {
        Name = "kube-master"
        "kubernetes.io/cluster/mattsCluster" = "owned"
        Project = "tera-kube-ans"
        Role = "master"
        Id = "1"
        environment = "dev"
    }
}

resource "aws_instance" "worker-1" {
    ami = "ami-013f17f36f8b1fefb"
    instance_type = "t2.medium"
        iam_instance_profile = module.iam.worker_profile_name
    vpc_security_group_ids = [aws_security_group.matt-kube-worker-sg.id, aws_security_group.matt-kube-mutual-sg.id]
    key_name = "mattkey"
    subnet_id = "subnet-c41ba589"  # select own subnet_id of us-east-1a
    availability_zone = "us-east-1a"
    tags = {
        Name = "worker-1"
        "kubernetes.io/cluster/mattsCluster" = "owned"
        Project = "tera-kube-ans"
        Role = "worker"
        Id = "1"
        environment = "dev"
    }
}

resource "aws_instance" "worker-2" {
    ami = "ami-013f17f36f8b1fefb"
    instance_type = "t2.medium"
    iam_instance_profile = module.iam.worker_profile_name
    vpc_security_group_ids = [aws_security_group.matt-kube-worker-sg.id, aws_security_group.matt-kube-mutual-sg.id]
    key_name = "mattkey"
    subnet_id = "subnet-c41ba589"  # select own subnet_id of us-east-1a
    availability_zone = "us-east-1a"
    tags = {
        Name = "worker-2"
        "kubernetes.io/cluster/mattsCluster" = "owned"
        Project = "tera-kube-ans"
        Role = "worker"
        Id = "2"
        environment = "dev"
    }
}

output kube-master-ip {
  value       = aws_instance.kube-master.public_ip
  sensitive   = false
  description = "public ip of the kube-master"
}

output worker-1-ip {
  value       = aws_instance.worker-1.public_ip
  sensitive   = false
  description = "public ip of the worker-1"
}

output worker-2-ip {
  value       = aws_instance.worker-2.public_ip
  sensitive   = false
  description = "public ip of the worker-2"
}
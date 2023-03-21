terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      ENV = "TEST"
    }
  }
}

data "aws_region" "current" {}

resource "aws_key_pair" "keypair" {
  key_name = "keypair_for_terraform"
  # TODO: CHANGE KEYPAIR
  public_key = "ssh-rsa ABCDEF...."
}

resource "random_password" "crypto_isakmp_key" {
  length           = 18
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:" # Exclude question mark
}

resource "random_password" "conuser-password" {
  length  = 18
  special = true
}

output "output-conuser-password" {
  description = "EC2 Password"
  value       = nonsensitive(random_password.conuser-password.result)
}

resource "aws_iam_policy" "policy-for-c8000v" {
  name        = "policy-for-c8000v"
  description = "For C8000V"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "cloudwatch:",
          "s3:",
          "ec2:AssociateRouteTable",
          "ec2:CreateRoute",
          "ec2:CreateRouteTable",
          "ec2:DeleteRoute",
          "ec2:DeleteRouteTable",
          "ec2:DescribeRouteTables",
          "ec2:DescribeVpcs",
          "ec2:ReplaceRoute",
          "ec2:DescribeRegions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DisassociateRouteTable",
          "ec2:ReplaceRouteTableAssociation",
          "logs:CreateLogGroup",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "role-for-c8000v" {
  name = "role-for-c8000v"

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
}

resource "aws_iam_role_policy_attachment" "attachment-for-c8000v" {
  role       = aws_iam_role.role-for-c8000v.name
  policy_arn = aws_iam_policy.policy-for-c8000v.arn
}

resource "aws_iam_instance_profile" "instance-profile-for-c8000v" {
  name = "instance-profile-for-c8000v"
  role = aws_iam_role.role-for-c8000v.name
}

data "aws_ami" "c8000v" {
  #most_recent = true
  owners = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["Cisco-C8K-*"]
  }

  filter {
    name   = "description"
    values = ["Cisco-C8K-.17.09.01a"]
  }

  filter {
    name   = "product-code"
    values = ["3ycwqehancx46bkpb3xkifiz5"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ami" "recent_al2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }

  filter {
    name   = "description"
    values = ["Amazon Linux 2023 *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_vpc" "myvpc" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "myvpc"
  }
}

resource "aws_subnet" "subnet-public-1a" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "172.31.0.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-public-1a"
  }
}

resource "aws_subnet" "subnet-public-1c" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "172.31.1.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-public-1c"
  }
}

resource "aws_subnet" "subnet-private-1a" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "172.31.2.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "subnet-private-1a"
  }
}

resource "aws_subnet" "subnet-private-1c" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "172.31.3.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "subnet-private-1c"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "rt-public" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "rt-public"
  }
}

resource "aws_route_table" "rt-private" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.eni-c8000v01-gi2.id
  }
  route {
    cidr_block           = "8.8.8.8/32"
    network_interface_id = aws_network_interface.eni-c8000v02-gi2.id
  }
  route {
    cidr_block           = "8.8.4.4/32"
    network_interface_id = aws_network_interface.eni-c8000v02-gi2.id
  }
  tags = {
    Name = "rt-private"
  }
}

resource "aws_route_table_association" "rtassoc-public-1a" {
  subnet_id      = aws_subnet.subnet-public-1a.id
  route_table_id = aws_route_table.rt-public.id
}

resource "aws_route_table_association" "rtassoc-public-1c" {
  subnet_id      = aws_subnet.subnet-public-1c.id
  route_table_id = aws_route_table.rt-public.id
}

resource "aws_route_table_association" "rtassoc-private-1a" {
  subnet_id      = aws_subnet.subnet-private-1a.id
  route_table_id = aws_route_table.rt-private.id
}

resource "aws_route_table_association" "rtassoc-private-1c" {
  subnet_id      = aws_subnet.subnet-private-1c.id
  route_table_id = aws_route_table.rt-private.id
}


resource "aws_security_group" "secgrp-public" {
  name        = "secgrp-public"
  description = "For Public Subnet"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    description = "SSH"
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "IKE"
    from_port   = 0
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "NAT Traversal"
    from_port   = 0
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "secgrp-public"
  }
}

resource "aws_security_group" "secgrp-private" {
  name        = "secgrp-private"
  description = "For Private Subnet"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    description = "ICMP via Catalyst 8000V for Connectivity Test"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP via Catalyst 8000V for Connectivity Test"
    from_port   = 0
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS via Catalyst 8000V for Connectivity Test"
    from_port   = 0
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "secgrp-private"
  }
}

resource "aws_network_interface" "eni-c8000v01-gi1" {
  subnet_id         = aws_subnet.subnet-public-1a.id
  security_groups   = [aws_security_group.secgrp-public.id]
  source_dest_check = false
  tags = {
    Name = "eni-c8000v01-gi1"
  }
}

resource "aws_network_interface" "eni-c8000v01-gi2" {
  subnet_id         = aws_subnet.subnet-private-1a.id
  security_groups   = [aws_security_group.secgrp-private.id]
  source_dest_check = false
  tags = {
    Name = "eni-c8000v01-gi2"
  }
}

resource "aws_network_interface" "eni-c8000v02-gi1" {
  subnet_id         = aws_subnet.subnet-public-1c.id
  security_groups   = [aws_security_group.secgrp-public.id]
  source_dest_check = false
  tags = {
    Name = "eni-c8000v02-gi1"
  }
}

resource "aws_network_interface" "eni-c8000v02-gi2" {
  subnet_id         = aws_subnet.subnet-private-1c.id
  security_groups   = [aws_security_group.secgrp-private.id]
  source_dest_check = false
  tags = {
    Name = "eni-c8000v02-gi2"
  }
}

resource "aws_eip" "eip-c8000v01" {
  vpc               = true
  network_interface = aws_network_interface.eni-c8000v01-gi1.id
  depends_on        = [aws_internet_gateway.igw]
  tags = {
    Name = "eip-c8000v01"
  }
}

resource "aws_eip" "eip-c8000v02" {
  vpc               = true
  network_interface = aws_network_interface.eni-c8000v02-gi1.id
  depends_on        = [aws_internet_gateway.igw]
  tags = {
    Name = "eip-c8000v02"
  }
}

resource "aws_instance" "c8000v01" {
  ami                  = data.aws_ami.c8000v.image_id
  instance_type        = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.instance-profile-for-c8000v.id
  key_name             = aws_key_pair.keypair.id
  network_interface {
    network_interface_id = aws_network_interface.eni-c8000v01-gi1.id
    device_index         = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.eni-c8000v01-gi2.id
    device_index         = 1
  }
  user_data = <<EOF
Section: License
TechPackage:network-premier

Section: IOS configuration
hostname c8000v01

crypto isakmp policy 1
 encr aes 256
 authentication pre-share
 crypto isakmp key ${random_password.crypto_isakmp_key.result} address 0.0.0.0
!
crypto ipsec transform-set uni-perf esp-aes 256 esp-sha-hmac
 mode tunnel
!

crypto ipsec profile vti-1
 set security-association lifetime kilobytes disable
 set security-association lifetime seconds 86400
 set transform-set uni-perf
 set pfs group2
!

interface Tunnel1
 ip address 192.168.101.1 255.255.255.252
 load-interval 30
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination ${aws_eip.eip-c8000v02.public_ip}
 tunnel protection ipsec profile vti-1
 bfd interval 100 min_rx 100 multiplier 3
!

router eigrp 1
 network 192.168.101.0 0.0.0.255
 bfd all-interfaces
!

redundancy
 cloud-ha bfd peer 192.168.101.2
!

interface GigabitEthernet2
 ip address dhcp
 ip nat inside
 no shutdown
!

ip access-list extended SOURCE_NAT
 permit ip 172.31.2.0 0.0.0.255 any
 permit ip 172.31.3.0 0.0.0.255 any
!

ip nat inside source list SOURCE_NAT interface GigabitEthernet1 overload

Section: Python package
csr_aws_ha 3.1.0 {--user}

Section: Scripts
https://raw.githubusercontent.com/myhomenwlab/Sample_configuration_of_Cisco_Catalyst_8000V_HA_on_AWS/main/script.sh?v=dummy1 1 ${data.aws_region.current.name} ${aws_route_table.rt-private.id} ${aws_network_interface.eni-c8000v01-gi2.id} '0.0.0.0/0' primary
https://raw.githubusercontent.com/myhomenwlab/Sample_configuration_of_Cisco_Catalyst_8000V_HA_on_AWS/main/script.sh?v=dummy2 2 ${data.aws_region.current.name} ${aws_route_table.rt-private.id} ${aws_network_interface.eni-c8000v01-gi2.id} '8.8.8.8/32' secondary
https://raw.githubusercontent.com/myhomenwlab/Sample_configuration_of_Cisco_Catalyst_8000V_HA_on_AWS/main/script.sh?v=dummy3 3 ${data.aws_region.current.name} ${aws_route_table.rt-private.id} ${aws_network_interface.eni-c8000v01-gi2.id} '8.8.4.4/32' secondary
EOF
  tags = {
    Name = "c8000v01"
  }
}

resource "aws_instance" "c8000v02" {
  ami                  = data.aws_ami.c8000v.image_id
  instance_type        = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.instance-profile-for-c8000v.id
  key_name             = aws_key_pair.keypair.id
  network_interface {
    network_interface_id = aws_network_interface.eni-c8000v02-gi1.id
    device_index         = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.eni-c8000v02-gi2.id
    device_index         = 1
  }
  user_data = <<EOF
Section: License
TechPackage:network-premier

Section: IOS configuration
hostname c8000v02

crypto isakmp policy 1
 encr aes 256
 authentication pre-share
 crypto isakmp key ${random_password.crypto_isakmp_key.result} address 0.0.0.0
!
crypto ipsec transform-set uni-perf esp-aes 256 esp-sha-hmac
 mode tunnel
!

crypto ipsec profile vti-1
 set security-association lifetime kilobytes disable
 set security-association lifetime seconds 86400
 set transform-set uni-perf
 set pfs group2
!

interface Tunnel1
 ip address 192.168.101.2 255.255.255.252
 load-interval 30
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination ${aws_eip.eip-c8000v01.public_ip}
  tunnel protection ipsec profile vti-1
 bfd interval 100 min_rx 100 multiplier 3
!

router eigrp 1
 network 192.168.101.0 0.0.0.255
 bfd all-interfaces
!

redundancy
 cloud-ha bfd peer 192.168.101.1
!

interface GigabitEthernet2
 ip address dhcp
 ip nat inside
 no shutdown
!

ip access-list extended SOURCE_NAT
 permit ip 172.31.2.0 0.0.0.255 any
 permit ip 172.31.3.0 0.0.0.255 any
!

ip nat inside source list SOURCE_NAT interface GigabitEthernet1 overload

Section: Python package
csr_aws_ha 3.1.0 {--user}

Section: Scripts
https://raw.githubusercontent.com/myhomenwlab/Sample_configuration_of_Cisco_Catalyst_8000V_HA_on_AWS/main/script.sh?v=dummy1 1 ${data.aws_region.current.name} ${aws_route_table.rt-private.id} ${aws_network_interface.eni-c8000v02-gi2.id} '0.0.0.0/0' secondary
https://raw.githubusercontent.com/myhomenwlab/Sample_configuration_of_Cisco_Catalyst_8000V_HA_on_AWS/main/script.sh?v=dummy2 2 ${data.aws_region.current.name} ${aws_route_table.rt-private.id} ${aws_network_interface.eni-c8000v02-gi2.id} '8.8.8.8/32' primary
https://raw.githubusercontent.com/myhomenwlab/Sample_configuration_of_Cisco_Catalyst_8000V_HA_on_AWS/main/script.sh?v=dummy3 3 ${data.aws_region.current.name} ${aws_route_table.rt-private.id} ${aws_network_interface.eni-c8000v02-gi2.id} '8.8.4.4/32' primary
EOF
  tags = {
    Name = "c8000v02"
  }
}

resource "aws_network_interface" "eni-al2023-01" {
  subnet_id       = aws_subnet.subnet-private-1a.id
  security_groups = [aws_security_group.secgrp-private.id]
  tags = {
    Name = "eni-al2023-01"
  }
}

resource "aws_instance" "al2023-01" {
  ami           = data.aws_ami.recent_al2023.image_id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.keypair.id
  network_interface {
    network_interface_id = aws_network_interface.eni-al2023-01.id
    device_index         = 0
  }
  user_data = <<EOF
#!/bin/bash
useradd conuser
echo '${random_password.conuser-password.result}' | sudo passwd --stdin conuser
EOF
  tags = {
    Name = "al2023-01"
  }
}

resource "aws_network_interface" "eni-al2023-02" {
  subnet_id       = aws_subnet.subnet-private-1c.id
  security_groups = [aws_security_group.secgrp-private.id]
  tags = {
    Name = "eni-al2023-02"
  }
}

resource "aws_instance" "al2023-02" {
  ami           = data.aws_ami.recent_al2023.image_id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.keypair.id
  network_interface {
    network_interface_id = aws_network_interface.eni-al2023-02.id
    device_index         = 0
  }
  user_data = <<EOF
#!/bin/bash
useradd conuser
echo '${random_password.conuser-password.result}' | sudo passwd --stdin conuser
EOF
  tags = {
    Name = "al2023-02"
  }
}

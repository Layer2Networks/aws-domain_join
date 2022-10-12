# ----------------------------------------------------------------------------------------------------
# Terraform Backend  - required
# 
# ----------------------------------------------------------------------------------------------------
# required
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

locals {
    tags = merge({
        project     = var.project_name
        environment = var.environment
        Name        = "test-windows-instance"
    })
}

###################################################
# resources
###################################################
resource "aws_key_pair" "windows" {
  key_name   = "windows-${var.windows_version}-key"
  public_key = ""
}

resource "aws_ssm_document" "ad_join_domain" {
  name          = "adjoin-domain-ssm_doc"
  document_type = "Command"
  content = jsonencode(
    {
      "schemaVersion" = "2.2"
      "description"   = "aws:domainJoin"
      "mainSteps" = [
        {
          "action" = "aws:domainJoin",
          "name"   = "domainJoin",
          "inputs" = {
            "directoryId"    = "d-12345f5678e90",
            "directoryName"  = "yourdomain.com",
            "dnsIpAddresses" = [
                "12.23.34.56",  # replace IPs  used in your AD Directory services
                "45.56.67.78"
            ]
          }
        }
      ]
    }
  )
}

resource "aws_ssm_association" "windows_server" {
  name = aws_ssm_document.ad_join_domain.name
  targets {
    key    = "tag:adjoin"
    values = ["true"]
  }
}

resource "aws_iam_role" "ad_autojoin" {
  name = "ad-autojoin"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Principal" = {
          "Service" = "ec2.amazonaws.com"
        },
        "Action" = "sts:AssumeRole"
      }
    ]
  })
}

# ssm policy attachment
resource "aws_iam_role_policy_attachment" "ssm-instance" {
  role       = aws_iam_role.ad_autojoin.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_role_policy_attachment" "ssm-ad" {
  role       = aws_iam_role.ad_autojoin.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_instance_profile" "ad_autojoin" {
  name = "ad-autojoin"
  role = aws_iam_role.ad_autojoin.name
}

#Instance deployment
data "aws_ami" "win2019server" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base*"]
  }

  filter {
    name   = "platform"
    values = ["windows"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
##-------------------------------------------------------------------------------------------
#####Remove once you have tested  this ec2 instance launch is only to test your SSM script
##-------------------------------------------------------------------------------------------
module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.2.0"

  ami           = data.aws_ami.win2019server.id
  instance_type = "t3.large"
  key_name      = var.key-pair
  cpu_credits   = "unlimited"
  associate_public_ip_address = true
  subnet_id     = var.subnet_id

##-------------------------------------------------------------------------------------------
## DOMAIN AUTO_JOIN!! the machine should join the domain by using tags
## this is where the magic happens  
## when creating a new instace just add the tags adjoin = true
##-------------------------------------------------------------------------------------------

  iam_instance_profile = aws_iam_instance_profile.ad_autojoin.name
  tags                 = merge({ "adjoin" = "true" }, local.tags)

  root_block_device = [{
    volume_size = 65
  }]
}

provider "aws" {
  region = "eu-central-1"
}

# Create tfstate file
terraform {
  backend "s3" {
    bucket         = "tf_state_kackap"
    key            = "vending_machine/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-lock-state"
    encrypt        = true
  }
}

# Create DynamoDB table
resource "aws_dynamodb_table" "menu_list" {
  name           = "menu_list"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  ttl {
    attribute_name = ""
    enabled        = false
  }
}

# Create Item in DynamoDB table
resource "ws_dynamodb_table_item" "item0" {
  table_name = aws_dynamodb_table.menu_list.name
  hash_key   = aws_dynamodb_table.menu_list.hash_key

  item = <<ITEM
  {
  "id": {
    "S": "ua3dXFyQwMSMzvzEC"
  },
  "items": {
    "M": {
      "chocolate": {
        "M": {
          "amount": {
            "N": "10"
          },
          "price": {
            "N": "8"
          }
        }
      },
      "coffee": {
        "M": {
          "amount": {
            "N": "50"
          },
          "price": {
            "N": "15"
          }
        }
      },
      "tea": {
        "M": {
          "amount": {
            "N": "50"
          },
          "price": {
            "N": "5"
          }
        }
      },
      "water": {
        "M": {
          "amount": {
            "N": "999"
          },
          "price": {
            "N": "3"
          }
        }
      }
    }
  }


ITEM
}

# Run vending machine on EC2
resource "aws_instance" "vending_machine_ec2" {
  ami           = "ami-0dfa284c9d7b2adad"
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_dynamodb.name
  security_groups      = [aws_security_group.allow_streamlit.name]
  tags = {
    Name = "tf_vending_machine"
  }

  user_data = <<EOF
#!/bin/bash

# Update yum
sudo yum update -y
sudo yum install -y git python3-pip

# Change into ec2-user directory
cd /home/ec2-user

# Setup requirements
sudo -u ec2-user git clone https://github.com/kaperekk/vending_machine.git
cd vending_machine
sudo -u ec2-user pip3 install -r requirements.txt

# Copy systemd service file 
sudo cp scripts/streamlit_app.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

sudo systemctl start streamlit_app
sudo systemctl enable streamlit_app
EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Setup IAM role for EC2 to get/write to dynamodb
data "aws_iam_policy_document" "instance_rp" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_dynamodb" {
  name               = "tf_ec2_dynamodb_vmm"
  assume_role_policy = data.aws_iam_policy_document.instance_rp.json

  inline_policy {
    name = "read_write_dynamodb_table_tf_menu_list"

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {

          "Sid" : "Stmt1703145729575",
          "Action" : [
            "dynamodb:GetItem",
            "dynamodb:UpdateItem"
          ], 
          "Effect" : "Allow",
          "Resource" : "${aws_dynamodb_table.menu_list.arn}"
        }
      ]
    })
  }
}

resource "aws_iam_instance_profile" "ec2_dynamodb" {
  name = "tf_ec2_dynamodb"
  role = aws_iam_role.ec2_dynamodb.name
}

# Allow access on port 8501
resource "aws_security_group" "allow_streamlit" {
  name        = "sg_allow_streamlit_http"
  description = "Allow streamlit inbound traffic"
}

resource "aws_security_group_rule" "outbound_all" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.allow_streamlit.id
}
resource "aws_security_group_rule" "inbound_8501" {
  type                     = "ingress"
  to_port                  = 8501
  protocol                 = "tcp"
  from_port                = 8501
  source_security_group_id = aws_security_group.sg_alb.id
  security_group_id        = aws_security_group.allow_streamlit.id
}
resource "aws_security_group_rule" "inbound_22" {
  type              = "ingress"
  to_port           = 22
  protocol          = "tcp"
  from_port         = 22
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_streamlit.id
}

# LB to EC2
resource "aws_lb" "alb_vmm" {
  name               = "alb-vmm"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = data.aws_subnets.default_vpc_subnet.ids
}

data "aws_subnets" "default_vpc_subnet" {
  filter {
    name   = "vpc-id"
    values = ["vpc-021a9ff8a3e82e66a"]
  }
}
resource "aws_lb_target_group" "alb_vmm" {
  name     = "alb-vmm-tg"
  port     = 8501
  protocol = "HTTP"
  vpc_id   = "vpc-021a9ff8a3e82e66a"

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_target_group_attachment" "alb_vmm" {
  target_group_arn = aws_lb_target_group.alb_vmm.arn
  target_id        = aws_instance.vending_machine_ec2.id
  port             = 8501

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_listener" "alb_vmm" {
  load_balancer_arn = aws_lb.alb_vmm.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_vmm.arn
  }
}

resource "aws_security_group" "sg_alb" {
  name        = "sg_alb_http"
  description = "Allow alb inbound traffic"
}
resource "aws_security_group_rule" "alb_outbound_all" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.sg_alb.id
}

resource "aws_security_group_rule" "inbound_443" {
  type              = "ingress"
  to_port           = 443
  protocol          = "tcp"
  from_port         = 443
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_alb.id
}

data "aws_route53_zone" "my_domain" {
  name = "vending_machine_kaperekk"
}
resource "aws_route53_record" "tfr53_domain" {
  zone_id = data.aws_route53_zone.my_domain.zone_id
  name    = "vmm.${data.aws_route53_zone.my_domain.name}"
  type    = "A"

  alias {
    name                   = aws_lb.alb_vmm.dns_name
    zone_id                = aws_lb.alb_vmm.zone_id
    evaluate_target_health = true
  }
}

# Request SSL certificate
resource "aws_acm_certificate" "cert" {
  domain_name       = aws_route53_record.tfr53_domain.name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.my_domain.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

output "instance_name" {
  value = aws_instance.vending_machine_ec2.tags["Name"]
}

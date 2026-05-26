module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name               = "${var.project}-${var.environment}-alb"
  load_balancer_type = "application"
  internal           = false

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ecs"
      }
    }
  }

  target_groups = {
    ecs = {
      name              = "${var.project}-${var.environment}-tg"
      protocol          = "HTTP"
      port              = var.container_port
      target_type       = "ip"
      create_attachment = false

      health_check = {
        enabled             = true
        path                = var.health_check_path
        matcher             = var.health_check_matcher
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }
  }

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

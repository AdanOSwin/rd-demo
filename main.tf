provider "aws"{
    profile = "default"
    region  =  "us-east-2"
}
 
module "vpc-demo" {
  source = "terraform-aws-modules/vpc/aws"
 
  name = "vpc-demo-chila"
  cidr = "192.168.0.0/16"
 
  azs             = ["us-east-2a", "us-east-2b"]
 
  public_subnets  = ["192.168.16.0/24", "192.168.17.0/24"]
  private_subnets = ["192.168.5.0/24", "192.168.6.0/24", "192.168.7.0/24", "192.168.8.0/24"]
 
  enable_vpn_gateway = true
 
  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true
  map_public_ip_on_launch = true
  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
 
module "lb_security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~>4.0"
 
  name        = "loadBalancer-demo"
  description = "Security group for loadbalancer."
  vpc_id      = module.vpc-demo.vpc_id
 
  ingress_with_cidr_blocks = [
    {
      rule        = "http-80-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  
  egress_with_cidr_blocks = [ 
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  
  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
 
module "security-group-app" {
  source = "terraform-aws-modules/security-group/aws"
 
  name        = "demo_security_group_app"
  description = "Security group for application-level instances."
  vpc_id      = module.vpc-demo.vpc_id
 
  computed_ingress_with_source_security_group_id = [
    {
      rule        = "http-80-tcp"
      source_security_group_id = module.lb_security_group.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
  
  /*ingress_with_cidr_blocks = [
    {
        rule        = "ssh-tcp"
        cidr_blocks = "0.0.0.0/0"
    }
  ]*/

  egress_with_cidr_blocks = [ 
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  
  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
 
module "security_group_db" {
  source = "terraform-aws-modules/security-group/aws"
 
  name        = "db-security-group-demo"
  description = "Security group for database-level instances."
  vpc_id      = module.vpc-demo.vpc_id
 
  computed_ingress_with_source_security_group_id = [
    {
      rule        = "mysql-tcp"
      source_security_group_id = module.security-group-app.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
 
  
  egress_with_cidr_blocks = [ 
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  
  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"
 
  name = "demo-load-balancer"
 
  load_balancer_type = "application"
 
  vpc_id             = module.vpc-demo.vpc_id
  subnets            = [module.vpc-demo.public_subnets[0], module.vpc-demo.public_subnets[1]]
  security_groups    = [module.lb_security_group.security_group_id]
 
  target_groups = [
    {
      name_prefix      = "demo-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]
 
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
 
  tags = {
    Environment = "Test"
  }
}

resource "aws_iam_service_linked_role" "autoscaling" {

  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = "demo-2222"
  
  # Sometimes good sleep is required to have some IAM resources created before they can be used
  provisioner "local-exec" {
    command = "sleep 10"
  }

  #provisioner "local-exec" {
  #  command = "start-sleep 10"
  #  interpreter = ["PowerShell", "-Command"]
  #}
}



resource "aws_iam_instance_profile" "ssm" {

  name = "demo-ssm-cloudwatch"

  role = aws_iam_role.ssm.name

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

resource "aws_iam_role" "ssm" {
  name = "demo-role"
  tags = {
    Owner       = "user"
    Environment = "dev"
  }



  assume_role_policy = <<-EOT
  {

    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOT
}

# Launch template webserver

/*module "lt_webserver" {
  source = "terraform-aws-modules/autoscaling/aws"

  # Autoscaling group
  name = "lt_webserver"

  vpc_zone_identifier = module.vpc-demo.private_subnets
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn


  # Launch template
  use_lt    = true
  create_lt = true

  image_id      = "ami-0724aae182815ee48"
  instance_type = "t2.micro"
  #user_data_base64  = base64encode(local.user_data)

  security_groups = [module.security-group-app.security_group_id]
  iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn
  target_group_arns = module.alb.target_group_arns

}*/

/*module "lt_db" {
  source = "terraform-aws-modules/autoscaling/aws"

  # Autoscaling group
  name = "lt_webserver"

  vpc_zone_identifier = module.vpc-demo.private_subnets
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn


  # Launch template
  use_lt    = true
  create_lt = true

  image_id      = "ami-094ab50c842d05719"
  instance_type = "t2.micro"
  #user_data_base64  = base64encode(local.user_data)

  security_groups = [module.security_group_db.security_group_id]
  iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn
  target_group_arns = module.alb.target_group_arns

}*/
 
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 4.0"
 
  # Autoscaling group
  name = "demo-asg"
 
  min_size                  = 2
  max_size                  = 3
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = [module.vpc-demo.private_subnets[0] , module.vpc-demo.private_subnets[1]]
 
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }
 
  iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn
  target_group_arns=module.alb.target_group_arns

  # Launch template
  lt_name                = "lt-demo"
  description            = "Launch template example"
  update_default_version = true

  use_lt    = true
  create_lt = true

  image_id          = "ami-0724aae182815ee48"
  instance_type     = "t3.micro"
  ebs_optimized     = true
  enable_monitoring = true






  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 32
  }

  placement = {
    availability_zone = "us-east-2b"
  }

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { WhatAmI = "Instance" }
    },
    {
      resource_type = "volume"
      tags          = { WhatAmI = "Volume" }
    },
    {
      resource_type = "spot-instances-request"
      tags          = { WhatAmI = "SpotInstanceRequest" }
    }
  ]

  tags = [
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "megasecret"
      propagate_at_launch = true
    },
  ]

  tags_as_map = {
    extra_tag1 = "extra_value1"
    extra_tag2 = "extra_value2"
  }
}


module "asg-db" {
    source = "terraform-aws-modules/autoscaling/aws"
    version = "~> 4.0"

    ##db autoscaling group
    name = "demo-asg"

    min_size                  = 2
    max_size                  = 3
    desired_capacity          = 2
    wait_for_capacity_timeout = 0
    health_check_type         = "EC2"
    vpc_zone_identifier = [module.vpc-demo.private_subnets[2], module.vpc-demo.private_subnets[3]]

    instance_refresh = {
        strategy = "Rolling"
        preferences = {
            min_healthy_percentage = 50
        }
        triggers = ["tag"]
    }

    iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn
    service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn
    target_group_arns=module.alb.target_group_arns

    # Launch template
  lt_name                = "lt-db-demo"
  description            = "Launch template example"
  update_default_version = true

  use_lt    = true
  create_lt = true

  image_id          = "ami-094ab50c842d05719"
  instance_type     = "t3.micro"
  ebs_optimized     = true
  enable_monitoring = true



  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 32
  }

  placement = {
    availability_zone = "us-east-2b"
  }

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { WhatAmI = "Instance" }
    },
    {
      resource_type = "volume"
      tags          = { WhatAmI = "Volume" }
    },
    {
      resource_type = "spot-instances-request"
      tags          = { WhatAmI = "SpotInstanceRequest" }
    }
  ]

  tags = [
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "megasecret"
      propagate_at_launch = true
    },
  ]

  tags_as_map = {
    extra_tag1 = "extra_value1"
    extra_tag2 = "extra_value2"
  }

}

resource "aws_sns_topic" "user_updates" {

  name = "demo-updates"
}

module "metric_alarm_scale_out" {

  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"

  version = "~> 2.0"

  alarm_name          = "demo-scale-out"
  alarm_description   = "Scaling out alarm for scaling group "
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 70
  period              = 60
  unit                = "Count"

  namespace   = "AWS/EC2"

  metric_name = "CPUUtilization"

  statistic   = "Average"

  dimensions = {
      AutoscalingGroupName = module.asg.autoscaling_group_name
  }

  alarm_actions = [aws_sns_topic.user_updates.arn, aws_autoscaling_policy.scale-out-policy.arn]

}

module "metric_alarm_scale_in" {

  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"

  version = "~> 2.0"


  alarm_name          = "demo-scale-in"
  alarm_description   = "Autoscaling alarm when Scaling-In"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 20
  period              = 60
  unit                = "Count"


  namespace   = "AWS/EC2"

  metric_name = "CPUUtilization"

  statistic   = "Average"

  dimensions = {
      AutoscalingGroupName = module.asg.autoscaling_group_name
  }

  alarm_actions = [aws_sns_topic.user_updates.arn, aws_autoscaling_policy.scale-in-policy.arn]

}

resource "aws_sns_topic_subscription" "user_updates_sqs_target" {

  topic_arn = aws_sns_topic.user_updates.arn
  protocol  = "email"
  endpoint  = "scopbly_213@hotmail.com"

}

resource "aws_sns_topic_subscription" "user_updates_sqs_target_2" {

  topic_arn = aws_sns_topic.user_updates.arn
  protocol  = "email"
  endpoint  = "mariost1995@hotmail.com"

}


resource "aws_autoscaling_policy" "scale-in-policy" {

  name                   = "scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = module.asg.autoscaling_group_name

}

resource "aws_autoscaling_policy" "scale-out-policy" {

  name                   = "scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = module.asg.autoscaling_group_name

}
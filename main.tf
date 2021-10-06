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
 
  # Launch template
  use_lt    = true
  launch_template = "demo-template-2-ultimate"
  #update_default_version = true

  /*network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = module.security-group-app.security_group_id
    }
  ]*/
 
  target_group_arns=module.alb.target_group_arns
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

    ##DB launch template
    use_lt = true
    launch_template = "db-template"
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

  namespace   = "MyApplication"

  metric_name = "CPU Maxout"

  statistic   = "Maximum"

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


  namespace   = "MyApplication"
  metric_name = "CPU Minimum"
  statistic   = "Minimum"

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
resource "aws_lb" "main" {
  for_each = var.applications

  name               = "${var.project}-${var.environment}-${each.key}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[each.key].id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-alb"
  }
}

resource "aws_lb_target_group" "main" {
  for_each = var.applications

  name     = "${var.project}-${var.environment}-${each.key}-tg"
  port     = each.value.port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-tg"
  }
}

resource "aws_lb_listener" "main" {
  for_each = var.applications

  load_balancer_arn = aws_lb.main[each.key].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[each.key].arn
  }

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-listener"
  }
}

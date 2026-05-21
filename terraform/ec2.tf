# IAM Role — allows EC2 to use SSM + read Secrets Manager
resource "aws_iam_role" "ec2_role" {
  name        = "${local.name_prefix}-ec2-role"
  description = "EC2 role: SSM access + Secrets Manager read"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Name = "${local.name_prefix}-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "ec2_secrets" {
  name = "${local.name_prefix}-ec2-secrets-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = aws_secretsmanager_secret.db_credentials.arn
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
  tags = { Name = "${local.name_prefix}-ec2-instance-profile" }
}

# EC2 App Server — private subnet, access via SSM only (no key_name, no port 22)
resource "aws_instance" "app" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private_app.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.app.id]

  # No key_name — SSH disabled; use SSM Session Manager for shell access

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ec2_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {
    aws_region = var.aws_region
    secret_arn = aws_secretsmanager_secret.db_credentials.arn
    db_endpoint = aws_db_instance.main.address
    db_name     = var.db_name
  }))

  depends_on = [aws_db_instance.main]

  tags = { Name = "${local.name_prefix}-ec2-app", Role = "application-server" }
}

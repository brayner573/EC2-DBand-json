provider "aws" {
  region = var.region
}

resource "aws_security_group" "consumer_sg_BANNER" {
  name        = "consumer-sg-BANNER"
  description = "Permite acceso HTTP y SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2_consumer_role_BANNER" {
  name = "EC2ConsumerS3ReadOnlyRoleBANNER"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read_BANNER" {
  role       = aws_iam_role.ec2_consumer_role_BANNER.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile_BANNER" {
  name = "EC2ConsumerProfileBANNER"
  role = aws_iam_role.ec2_consumer_role_BANNER.name
}

resource "aws_instance" "consumer_BANNER" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.consumer_sg_BANNER.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile_BANNER.name
  user_data              = file("${path.module}/scripts/setup.sh")

  tags = { Name = "EC2-Consumer-BANNER" }
}

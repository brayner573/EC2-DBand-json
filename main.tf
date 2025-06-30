provider "aws" {
  region = "us-east-1" # Cambia a tu región si es diferente
}

resource "aws_security_group" "consumer_sg" {
  name        = "consumer-sg"
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

resource "aws_iam_role" "ec2_consumer_role" {
  name = "EC2ConsumerS3ReadOnlyRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.ec2_consumer_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2ConsumerProfile"
  role = aws_iam_role.ec2_consumer_role.name
}

resource "aws_instance" "consumer" {
  ami                    = "ami-000d841032e72b43c" # Ubuntu 22.04 LTS en us-east-1
  instance_type          = "t2.micro"
  key_name               = "mi-llave-ec2-grupo-final"
  vpc_security_group_ids = [aws_security_group.consumer_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = file("${path.module}/scripts/setup.sh")

  tags = { Name = "EC2-Consumer" }
}

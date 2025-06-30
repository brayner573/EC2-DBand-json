output "ec2_consumer_ip" {
  description = "IP Pública del servidor EC2 Consumer"
  value       = aws_instance.consumer.public_ip
}

output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer BANNER"
  value       = aws_instance.consumer_BANNER.public_ip
}

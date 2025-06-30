output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer v6"
  value       = aws_instance.consumer_v6.public_ip
}

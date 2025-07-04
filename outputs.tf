output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer CA"
  value       = aws_instance.consumer_CA.public_ip
}

output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer PRO"
  value       = aws_instance.consumer_PRO.public_ip
}

output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer V5"
  value       = aws_instance.consumer_v5.public_ip
}

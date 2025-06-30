output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer V3"
  value       = aws_instance.consumer_v3.public_ip
}

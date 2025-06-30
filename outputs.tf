output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer V4"
  value       = aws_instance.consumer_v4.public_ip
}

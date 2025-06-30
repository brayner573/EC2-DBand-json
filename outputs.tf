output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer"
  value       = aws_instance.consumer.public_ip
}

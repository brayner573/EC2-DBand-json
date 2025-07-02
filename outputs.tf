output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer enpoint"
  value       = aws_instance.consumer_enpoint.public_ip
}

output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer PR"
  value       = aws_instance.consumer_PR.public_ip
}

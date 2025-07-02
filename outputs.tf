output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer Fynal"
  value       = aws_instance.consumer_Fynal.public_ip
}

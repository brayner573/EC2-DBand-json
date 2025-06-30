output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer bra"
  value       = aws_instance.consumer_bra.public_ip
}

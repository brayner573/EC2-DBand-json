output "ec2_consumer_ip" {
  description = "IP pública de la instancia EC2 Consumer V2"
  value       = aws_instance.consumer_v2.public_ip
}

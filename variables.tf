variable "region"         { default = "us-east-1" }
variable "key_name"       { default = "mi-llave-ec2-grupo-final" }
variable "ami"            { default = "ami-000d841032e72b43c" }
variable "instance_type"  { default = "t2.micro" }
variable "bucket_salida"  { default = "output-bucket-covid-test" }
variable "bucket_entrada" { default = "input-bucket-covid-test" }

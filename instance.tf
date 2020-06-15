provider "aws" {
  region = "ap-south-1"
  profile = "default"
}

resource "tls_private_key" "webserver_key" {
    algorithm   =  "RSA"
    rsa_bits    =  4096
}
resource "local_file" "private_key" {
    content         =  tls_private_key.webserver_key.private_key_pem
    filename        =  "webserver.pem"
    file_permission =  0400
}
resource "aws_key_pair" "webserver_key" {
    key_name   = "webserver"
    public_key = tls_private_key.webserver_key.public_key_openssh
}

resource "aws_ebs_volume" "test_ebs" {
  depends_on = [
    aws_instance.myin
  ]
  availability_zone = aws_instance.myin.availability_zone
  size = 1
  tags = {
    Name = "testvolume"
  }
}


resource "aws_volume_attachment" "test_ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.test_ebs.id}"
  instance_id = "${aws_instance.myin.id}"
  force_detach = true
}

resource "aws_security_group" "testsg" {
  name        = "HTTP & SSH"
  description = "HTTP & SSH"
  vpc_id      = "vpc-d6e9f4be"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "HTTP & SSH"
  }
}


resource "aws_instance" "myin" {
  depends_on = [
    aws_key_pair.webserver_key
  ]
  ami           = "ami-0fe6c48156bfd54c8"
  instance_type = "t2.micro"
  key_name = "webserver"
  security_groups = [ "HTTP & SSH" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.webserver_key.private_key_pem
    host     = aws_instance.myin.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
   tags = {
    Name = "TestOS"
  }
}
resource "null_resource" "nulllocal1"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.myin.public_ip}"
  	}
}


resource "null_resource" "nullremote1"  {

depends_on = [
    aws_volume_attachment.test_ebs_att,
  ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.webserver_key.private_key_pem
    host     = aws_instance.myin.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Manali-Gorwani/cloud_task1.git /var/www/html/"
    ]
  }
}



resource "null_resource" "nulllocal2"  {
depends_on = [
    null_resource.nullremote1,
  ]
	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.myin.public_ip}"
  	}
}

output "myos_ip" {
  value = aws_instance.myin.public_ip
}
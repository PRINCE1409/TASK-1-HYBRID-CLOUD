provider "aws" {
  region  = "ap-south-1"
  profile = "gajju"
}

resource "aws_security_group" "SECURITY_GROUP1" {
	  name        = "SECURITY_KEY"
 ingress {
	    description = "SSH Protocol"
	    from_port   = 22
	    to_port     = 22
	    protocol    = "tcp"
	    cidr_blocks = [ "0.0.0.0/0" ]
	  }
	
 ingress {
	    description = "HTTP Protocol"
	    from_port   = 80
	    to_port     = 80
	    protocol    = "tcp"
	    cidr_blocks = [ "0.0.0.0/0" ]
	  }
	
egress {
	    from_port   = 0
	    to_port     = 0
	    protocol    = "-1"
	    cidr_blocks = ["0.0.0.0/0"]
	  }
	

tags = {
	    Name = "security_group"
	  }
}

resource "aws_instance" "my_ec2_instnace" {
  ami            = "ami-0447a12f28fddb066"
  instance_type  = "t2.micro"
  security_groups = ["SECURITY_KEY"]
  key_name       = "mykey111222"   
  
 connection {
    type     = "ssh"
    user     = "ec2-user"
   private_key = file("C:/Users/black/Downloads/aws-credentials/mykey111222.pem")
    host     = aws_instance.my_ec2_instnace.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd ",
      "sudo systemctl enable httpd "
    ]
  }

tags = {
    Name = "gajjuos1"
  }
}


resource "aws_ebs_volume" "my_ebs_volume" {
  availability_zone = aws_instance.my_ec2_instnace.availability_zone
  size              = 1

  tags = {
    Name = "gajjuebs1"
  }
}

resource "aws_volume_attachment" "ebs_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.my_ebs_volume.id
  instance_id = aws_instance.my_ec2_instnace.id
  force_detach = true
}

resource "null_resource" "local1"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.my_ec2_instnace.public_ip} >> publicip.txt"
  	}
}

resource "null_resource" "local2" {
 
depends_on = [
    aws_volume_attachment.ebs_attachment,
  ]

 connection {
    type     = "ssh"
    user     = "ec2-user"
   private_key = file("C:/Users/black/Downloads/aws-credentials/mykey111222.pem")
    host     = aws_instance.my_ec2_instnace.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh ",
      "sudo mount /dev/xvdh /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/PRINCE1409/TASK-1-HYBRID-CLOUD.git /var/www/html"
      
    ]
  }
}

resource "aws_s3_bucket" "bucket1" {
  bucket = "gajjubucket1"
  acl    = "private"
  force_destroy = true

  tags = {
    Name        = "gajjubucket1"
  }
}
locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_s3_bucket_object" "uploading_object" {
  bucket = aws_s3_bucket.bucket1.bucket
  key    = "task_img.png"
  acl = "public-read"
  force_destroy = true
  source = "C:/Users/black/Downloads/favicon.png"
  etag = filemd5("C:/Users/black/Downloads/favicon.png")
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket1.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

 

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

 

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

 
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "null_resource" "cloudfront_url"{
  depends_on = [aws_cloudfront_distribution.s3_distribution]
  connection {
    type     = "ssh"
    user     = "ec2-user"
   private_key = file("C:/Users/black/Downloads/aws-credentials/mykey111222.pem")
    host     = aws_instance.my_ec2_instnace.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/__url__1/http:\\/\\/${aws_cloudfront_distribution.s3_distribution.domain_name}\\/${aws_s3_bucket_object.uploading_object.key}/' /var/www/html/index.html"
    ]
  }
}






resource "null_resource" "local3"{
depends_on = [
    null_resource.cloudfront_url,
]
provisioner "local-exec" {
    command = "start chrome ${aws_instance.my_ec2_instnace.public_ip} "
  }
}
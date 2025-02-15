provider "aws" {
  region = "ap-southeast-1" # Ganti dengan region yang diinginkan
}

resource "aws_security_group" "dicoding_sg" {
  name        = "dicoding_security_group"
  description = "Allow SSH, HTTP, HTTPS, and custom ports"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 49000
    to_port     = 49000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3031
    to_port     = 3031
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9091
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2376
    to_port     = 2376
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "dicoding_terraform" {
  ami                    = "ami-0198a868663199764" # AMI Ubuntu 22.04 (update sesuai region)
  instance_type          = "t2.medium"
//   key_name               = "AKIAQ4J5YJFSRTAOHVLO" # Ganti dengan nama key pair Anda
  vpc_security_group_ids = [aws_security_group.dicoding_sg.id]

  root_block_device {
    volume_size = 15
  }

  user_data = <<-EOF
                #!/bin/bash
                apt update -y
                apt install -y ca-certificates curl docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                systemctl enable docker
                systemctl start docker
                usermod -aG docker ubuntu
                
                # Buat network Jenkins
                docker network create jenkins
                
                # Buat Dockerfile untuk Jenkins
                cat <<EOD > Dockerfile
                FROM jenkins/jenkins:2.426.2-jdk17
                USER root
                RUN apt-get update && apt-get install -y lsb-release
                RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \\
                    https://download.docker.com/linux/debian/gpg
                RUN echo "deb [arch=\$(dpkg --print-architecture) \\
                    signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \\
                    https://download.docker.com/linux/debian \\
                    \$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
                RUN apt-get update && apt-get install -y docker-ce-cli
                USER jenkins
                RUN jenkins-plugin-cli --plugins "blueocean:1.27.9 docker-workflow:572.v950f58993843"
                EOD

                # Build image Jenkins
                docker build -t myjenkins-blueocean:2.426.2-1 .

                # Jalankan Jenkins
                docker run --name jenkins-blueocean --detach --network jenkins --env DOCKER_HOST=tcp://docker:2376 --env DOCKER_CERT_PATH=/certs/client --env DOCKER_TLS_VERIFY=1 --publish 8080:8080 --publish 50000:50000 \
                    --volume jenkins-data:/var/jenkins_home --volume jenkins-docker-certs:/certs/client:ro --restart=on-failure --env JAVA_OPTS="-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" myjenkins-blueocean:2.426.2-1 

                # Jalankan Docker dind
                docker run --name jenkins-docker --detach --privileged --network jenkins --network-alias docker --env DOCKER_TLS_CERTDIR=/certs --volume jenkins-docker-certs:/certs/client \
                    --volume jenkins-data:/var/jenkins_home --publish 2376:2376 --restart always docker:dind --storage-driver overlay2
                
                # Jalankan Prometheus
                docker run -d -p 9091:9090 --name prometheus --restart=always prom/prometheus

                # Jalankan Grafana
                docker run -d --name grafana -p 3031:3031 -e "GF_SERVER_HTTP_PORT=3031" grafana/grafana
              EOF

  tags = {
    Name = "Dicoding-Terraform"
  }
}
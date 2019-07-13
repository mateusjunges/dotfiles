sudo apt-get install apt-transport-https ca-certificates
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
sudo sh -c 'echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" >> /etc/apt/sources.list.d/docker.list'
sudo apt-get update
sudo apt-get purge lxd-docker
apt-cache policy docker-engine
sudo apt-get install linux-image-extra-$(uname -r) linux-image-extra-virtual
sudo apt-get install docker-engine
sudo usermod -aG docker $USER
sudo servide docker start
sudo docker run hello-world
sudo systemctl enable docker

# Docker-compose
curl -L https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` > ~/docker-compose
chmod +x ~/docker-compose
sudo mv ~/docker-compose /usr/local/bin/docker-compose

# Docker-compose completition bash
curl -L htps://raw.githubusercontent.com/docker/compose/$(docker-compose version --shor)/contrib/completion/bash/docker-compose > ~/docker-compose
sudo mv ~/docker-compose /etc/bash_completion.d/docker-compose


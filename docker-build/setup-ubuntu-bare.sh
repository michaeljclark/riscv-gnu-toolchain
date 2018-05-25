#!/bin/bash

# apt https transport and ca certs
sudo apt-get update
sudo apt-get install -y \
     apt-transport-https \
     ca-certificates \
     curl \
     software-properties-common

# Get Docker CE for Ubuntu tells us to check the key
# It is fetched over https so we know the public key
# comes from the domain holder of docker.com even if
# the curl can return more than one public key, they
# should be from Docker, Inc.
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
exemplar=$(mktemp)
cat >${exemplar} <<EOF
pub   4096R/0EBFCD88 2017-02-22
      Key fingerprint = 9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid                  Docker Release (CE deb) <docker@docker.com>
sub   4096R/F273FCD8 2017-02-22

EOF

# check the repository key against the exemplar
local=$(mktemp)
sudo apt-key fingerprint 0EBFCD88 > ${local}
diff -u ${exemplar} ${local}
rc=$?
rm -f ${exemplar} ${local}
if [ $rc != 0 ]; then
    echo "*** error: bad repository key fingerprint"
    exit 1
fi
echo Docker repository key appears good

# add docker repository
sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# install docker-ce
sudo apt-get update
sudo apt-get install -y docker-ce

# Add the current user to the docker group
sudo usermod -aG docker $(whoami)

# Start Docker
sudo systemctl enable docker
sudo systemctl start docker

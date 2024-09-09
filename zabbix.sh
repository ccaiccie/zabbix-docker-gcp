PROJECT_ID=$(gcloud config get-value project)
ZONE=$(gcloud config get-value compute/zone)
UBUNTU_IMAGE=$(gcloud compute images list --project=ubuntu-os-cloud --filter="name~'ubuntu-2204-jammy' AND architecture='X86_64'" --sort-by="~creationTimestamp" --limit=1 --format="value(name)")
gcloud compute instances create zabbixvm \
 --machine-type=n2-standard-4 \
 --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
 --provisioning-model=STANDARD \
 --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
 --create-disk=auto-delete=yes,boot=yes,device-name=gns3,image=projects/ubuntu-os-cloud/global/images/$UBUNTU_IMAGE,mode=rw,size=20,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced \
 --no-shielded-secure-boot --shielded-vtpm \
 --tags zabbix \
 --zone $ZONE \
 --enable-nested-virtualization \
 --provisioning-model=SPOT \
 --instance-termination-action=stop \
 --can-ip-forward \
 --metadata serial-port-enable=TRUE,startup-script='#!/bin/bash

# Redirect stdout and stderr to the log file
exec > /var/log/startup-script.log 2>&1

if [ ! -f /opt/zabbix/startup-script-ran ]; then
    mkdir -p /opt/zabbix
    export DEBIAN_FRONTEND="noninteractive"
    echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections
    echo "APT::Get::Assume-Yes \"true\";" > /tmp/_tmp_apt.conf
    export APT_CONFIG=/tmp/_tmp_apt.conf
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin expect -y
    git clone https://github.com/zabbix/zabbix-docker.git
    cd zabbix-docker
    docker compose -f docker-compose_v3_ubuntu_mysql_latest.yaml up -d
    touch /opt/zabbix/startup-script-ran
fi
'

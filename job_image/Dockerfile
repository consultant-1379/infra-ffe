FROM ubuntu:20.04

LABEL maintainer="James Duffy (ejamduf)"

# Install tzdata package non-interactively for Ubuntu
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && apt-get install tzdata -qy && \
    ln -fs /usr/share/zoneinfo/Europe/Dublin /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    echo "Europe/Dublin" > /etc/timezone && \
    # Make sure the package repository is up to date
    apt-get -qy full-upgrade && \
    apt-get install -qy git && \
    # Install a basic SSH server for Jenkins docker plugin
    apt-get install -qy openssh-server && \
    sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd && \
    mkdir -p /var/run/sshd && \
    # Install JDK 8 for Jenkins docker plugin
    apt-get install -qy openjdk-11-jdk-headless && \
    # Install other tools
    apt-get install -qy python3-pip wget curl unzip tar gzip sshpass vim rsync rpm2cpio cpio ca-certificates qemu-utils && \
    # Install terraform
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt update && apt install terraform && \
    # Install YQ package
    curl -O -L https://github.com/mikefarah/yq/releases/download/3.3.0/yq_linux_amd64 && \
    chmod +x yq_linux_amd64 && \
    cp yq_linux_amd64 /usr/local/bin/yq && \
    rm yq_linux_amd64 && \
    # Cleanup old packages
    apt-get -qy autoremove && \
    # Add user lciadm100 to the image
    useradd -m -s /bin/bash lciadm100 && \
    # Set password for the lciadm100 user
    echo "lciadm100:ericsson123" | chpasswd

COPY .gitconfig /home/lciadm100/.gitconfig

COPY python3_modules.txt /root/python3_modules.txt

RUN /usr/bin/pip3 install -r /root/python3_modules.txt

# Copy files to set up ssh for gerrit
RUN mkdir /home/lciadm100/.ssh
COPY config /home/lciadm100/.ssh/config
COPY id_rsa /home/lciadm100/.ssh/id_rsa
COPY id_rsa.pub /home/lciadm100/.ssh/id_rsa.pub

# Create .ssh directory and set correct permissions
RUN chown -R lciadm100:lciadm100 /home/lciadm100/.ssh/ && \
    chmod 644 /home/lciadm100/.ssh/id_rsa.pub && \
    chmod 600 /home/lciadm100/.ssh/id_rsa && \
    chmod 700 /home/lciadm100/.ssh

# Install Meteo and Okta Root CA Certificates
COPY EGADRootCA_okta.crt /usr/local/share/ca-certificates/EGADRootCA_okta.crt
COPY EGADRootCA_meteo.crt /usr/local/share/ca-certificates/EGADRootCA_meteo.crt
RUN update-ca-certificates

# Install ansible community.crypto and community.general collections
# installing collections into /usr/share/ansible/collections makes them available for all users
RUN ansible-galaxy collection install community.crypto community.general openstack.cloud ansible.posix -p /usr/share/ansible/collections

USER root

# Standard SSH port
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]

#!/bin/bash

# Update yum
sudo yum update -y
sudo yum install -y git python3-pip

# Change into ec2-user directory
cd /home/ec2-user

# Setup requirements
sudo -u ec2-user git clone https://github.com/kaperekk/vending_machine.git
cd vending_machine
sudo -u ec2-user pip3 install -r requirements.txt

# Copy systemd service file 
sudo cp scripts/streamlit_app.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

sudo systemctl start streamlit_app
sudo systemctl enable streamlit_app
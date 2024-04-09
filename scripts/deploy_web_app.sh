#!/bin/bash

APP_FOLDER="vending_machine"
SERVICE_SCRIPT="scripts/streamlit_app.service"

if [ -d "$APP_FOLDER" ]; then
    # If the folder exists, run git pull and restart service
    cd "$APP_FOLDER" || exit
    git pull
    sudo systemctl restart streamlit_app
else
    # If the folder doesn't exist, run git clone and set up service
    git clone https://github.com/KhongPhaiDat/vending_machine_management_web.git
    cd "$APP_FOLDER" || exit

    # Copy service script to /etc/systemd/system/
    sudo cp "$SERVICE_SCRIPT" /etc/systemd/system/
    sudo systemctl enable "$SERVICE_SCRIPT"
    sudo systemctl start "$SERVICE_SCRIPT"
fi

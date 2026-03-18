#!/bin/bash

# readme: https://docs.ankiweb.net/platform/linux/installing.html

sudo apt install libxcb-xinerama0 libxcb-cursor0 libnss3

curl https://github.com/ankitects/anki/releases/download/25.09/anki-launcher-25.09-linux.tar.zst
tar xaf xaf anki-launcher*
cd anki-launcher*
sudo ./install.sh



#!/bin/bash

# http://docs.ceph.com/docs/jewel/install/get-packages/
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
sudo apt-add-repository 'deb http://download.ceph.com/debian-jewel/ xenial main'

sudo apt-get update
sudo apt-get install -y ceph ntp

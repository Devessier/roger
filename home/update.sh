#!/usr/bin/env sh

# The `-y` parameter permits to accept everything

apt-get update -y >> /var/log/update_script.log

apt-get upgrade -y >> /var/log/update_script.log

We use Debian.

# These are instructions to setup our Roger

## Follow instructions in the Debian installer

This is not really difficult, just create 2 partitions, of 4.2G and 4.4G respectively.

## Add the created user to sudoers group

We must install `sudo` command.
And then and the user to the sudoers group.

## Setup the static IP

- In the settings of the VM in VirtualBox, replace `NAT` by `Bridged Adaptater`
- Enable `enp0s3` in /etc/network/interfaces
- Configure the file `/etc/network/interfaces.d/enp0s3` :
```
iface enp0s3 inet static
	address 10.11.200.247
	netmask 255.255.255.252
	gateway 10.11.254.254
```
- Restart the network service with `sudo service networking restart`
- We should see our new IP using `ip addr show enp0s3` 🎉

There will be two `inet` addresses :
- One with /30 netmask which is the address in the VM
- Another with /16 netmask which permits to access the VM from the host

## Configure SSHD

The following operations have to be completed into `/etc/ssh/sshd_config` file :

1. Change the sshd port by modifying `Port 22` to `Port 2222`
2. Disallow root login by setting `PermitRootLogin` to `no`
3. Create a ssh key for `roger` user using `ssh-keygen`

We have some things to do to finish this part :

1. Save that key into the server which in our case is also the client (LOL) : `ssh-copy-id -i ~/.ssh/id_rsa.pub roger@10.11.200.247 -p 50000`
2. Now when we try to connect using SSH the passphrase will be asked and not anymore our password. The passphrase is `roger`.
3. Disable password authentication by returning into `/etc/ssh/sshd_config` to set the entry `PasswordAuthentication` to `no`

## Configure the Firewall

We will only accept HTTP, HTTPS and SSH using `ufw`.

Run :
```
# By default deny all incoming requests
sudo ufw default deny incoming
# By default allow all outcoming requests
sudo ufw default allow outcoming
# To accept SSH connections
sudo ufw allow 50000/tcp
# To accept HTTP connections
sudo ufw allow 80/tcp
# To accept HTTPS connections
sudo ufw allow 443/tcp
# Launch ufw on startup
sudo ufw enable
```

Allowing HTTP and HTTPS TCP connections is mandatory for the Web Server Bonus part.

## Add DOS protections

Install `fail2ban` and `nginx`.
We will use nginx in the first bonus part.

See `jail.local`.
Links :
- https://serverfault.com/questions/690820/fail2ban-filter-errors 

## Prevent port scanning

Install `portsentry` : `sudo apt install portsentry`.

Modify the file `/etc/default/portsentry` to enable automatic mode.

## Stop unused services

Run the following commands :

Here are our launched services (`ls -1 /etc/init.d`) :

```
apparmor
console-setup.sh
cron
dbus (utility to send messages accross applications)
fail2ban
hwclock.sh (hardware clock)
keyboard-setup.sh
kmod (Program to manage Linux Kernel modules)
networking
nginx
portsentry
procps (utilities for /proc directory)
rsyslog (forward log messages to an IP)
sendmail
ssh
sudo
udev (Dynamic device management)
ufw (our program to manage the firewall)
```

We will stop the following services :

```
console-setup.sh
keyboard-setup.sh
sendmail
```

Paste to a shell :

```
sudo /etc/init.d/console-setup.sh stop;
sudo /etc/init.d/keyboard-setup.sh stop;
sudo /etc/init.d/sendmail stop;
```

## Create a script to update packages

The script (update.sh) :

```
#!/usr/bin/env sh

# The `-y` parameter permits to accept everything

apt-get update -y >> /var/log/update_script.log

apt-get upgrade -y >> /var/log/update_script.log
```

Make this script executable :

```
chmod 755 ./update.sh
```

Execute the script every week at 4:00am and after reboot (put it in update.cron) :

```
@reboot /home/roger/update.sh
0 4 * * 1 /home/roger/update.sh
```

See [https://crontab.guru/](crontab guru) for more informations about cron expressions.

To setup the execution of this file using cron :

```
sudo crontab < update.cron
```

We can try the execution of the cron `@reboot` like that :

```
sudo rm /var/log/update_script.log

sudo reboot

# waiting for the system to reboot and then reconnect using ssh

ls /var/log/update_script.log
```

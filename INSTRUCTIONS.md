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

Look at the entries `http-get-dos` and `sshd`.

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
```

Paste to a shell :

```
sudo /etc/init.d/console-setup.sh stop;
sudo /etc/init.d/keyboard-setup.sh stop;
```

## Create a script to update packages

This script must be run on **sudo**.

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

See [crontab guru](https://crontab.guru/) for more informations about cron expressions.

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

## Monitor /etc/crontab changes

If this file is modified send an email to the root user.
The verification must occur each day at midnight.

Follow these instructions to setup email sending :

- Install `postfix`
- Select `Local Only` and take `example.com` as system mail name
- `Root and master mail recipien`t = `root@localhost`
- `Other destinations` = `example.org, debian.lan, localhost.lan, , localhost`
- Don't use `force synchronous updates on mail queue`
- Keep local networks defaults
- Don't use procmail
- Keep a mailbox size limit of `0`
- Keep the local address extension character
- Enable all internet protocols

We can use [mutt](https://doc.ubuntu-fr.org/mutt) to watch our emails :

```
sudo apt install mutt
```

Put the configuration of `mutt` on `/root` directory :

```
set mbox_type=Maildir
set folder="/root/mail"
set mask="!^\\.[^.]"
set mbox="/root/mail"
set record="+.Sent"
set postponed="+.Drafts"
set spoolfile="/root/mail"
```

We can launch `mutt` to watch our emails using just `mutt` :tada:!

To send emails we will use `bsd-mailx`:

```
sudo apt install bsd-mailx
```

This is the same command as on macOS.


We can send an email to the root account using :

```
echo "Email body" | sudo mail -s "Email subject" root@localhost
```

The script to monitor /etc/crontab file :

```
#!/usr/bin/env bash

readonly SUM_FILE="$HOME/.crontab.sum"

touch $SUM_FILE

oldsum=$(cat $SUM_FILE)
newsum=$(shasum /etc/crontab | awk '{ print $1 }')

echo $oldsum
echo $newsum

if [ "$oldsum" != "$newsum" ]
then
	# a modification occured, send an email to the root user
	echo $newsum > $SUM_FILE

	cat <<'EOF' | sudo mail -s "The file /etc/crontab has been modified" root@localhost
Go to /etc/crontab NOW !
Someone modified it !
EOF

fi
```

Create a file named `monitor.cron` containing the cron scheduling for `monitor.sh` file :

```
0 0 * * * ~/monitor.sh
``` 

To append this cron job to the previous ones inserted do :

```
sudo crontab -l | cat - ./monitor.cron > crontab.txt && sudo crontab crontab.txt && rm crontab.txt
```

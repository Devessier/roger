# These are instructions to setup our Roger

We use Debian.

## Follow instructions in the Debian installer

This is not really difficult, just create 2 partitions, of 4.2G and 4.4G respectively.

To get devices sizes run `lsbkl` or `sudo fdisk -l` or to get sizes in bytes run `lsblk -b` or `sudo fdisk -l --bytes`.

## Add the created user to sudoers group

We must install `sudo` command.
And then and the user to the sudoers group.

## Setup the static IP

- In the settings of the VM in VirtualBox, replace `NAT` by `Bridged Adaptater`
- Enable `enp0s3` in /etc/network/interfaces
- Configure the file `/etc/network/interfaces` :

```
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s3
allow-hotplug enp0s3
iface enp0s3 inet static
	address 192.168.68.117
	netmask 255.255.255.252
	gateway 192.168.68.1
	broadcast 192.168.68.255
	dns-nameservers 192.168.8.254
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
4. Force pubkey authentication by returning into `/etc/ssh/sshd_config` and setting `PubkeyAuthentication` to `yes`
5. Restart `sshd` service with `sudo service sshd restart`

We have some things to do to finish this part :

1. Save that key into the server which in our case is also the client (LOL) : `ssh-copy-id -i ~/.ssh/id_rsa.pub roger@192.168.68.117 -p 2222`
2. Disallow `PasswordAuthentication` and don't `PermitEmptyPasswords`
3. Now when we try to connect using SSH the passphrase will be asked and not anymore our password. The passphrase is `roger`.

## Configure the Firewall

We setup the firewall using iptables rules.
See `iptables.sh` file.
The `iptables-persistent` package can be used to persist iptables rules.

## Add DOS protections

Install `fail2ban` and `nginx`.
We will use nginx in the first bonus part.

See `jail.local` and `http-get-dos.conf` files.

Look at `http-get-dos` and `sshd` entries.

## Prevent port scanning

Install `portsentry`: `sudo apt install portsentry`.

Modify `/etc/default/portsentry` and `/etc/portsentry/portsentry.conf` files to enable automatic mode.

We can scan ports using :

```
nmap -p 1-3000 192.168.68.117
```

To unban the IP :

1. check `/etc/hosts.deny` and delete our IP
2. run `iptables -L --line-numbers`
3. delete the corresponding entry with `iptables -D <SECTION> <ID>`

## Stop unused services

Run the following commands :

Here are our launched services (`sudo systemctl list-unit-files | grep enabled`) :

```
anacron.service
apparmor.service
autovt@.service
bluetooth.service
console-setup.service
cron.service
dbus-fi.w1.wpa_supplicant1.service
dbus-org.bluez.service
dbus-org.freedesktop.timesync1.service
fail2ban.service
getty@.service
keyboard-setup.service
networking.service
nginx.service
rsyslog.service
ssh.service
sshd.service
syslog.service
systemd-fsck-root.service
systemd-timesyncd.service
ufw.service
wpa_supplicant.service
remote-fs.target
anacron.timer
apt-daily-upgrade.timer
apt-daily.timer
logrotate.timer
man-db.timer
```

We will keep the following services :

```
cron.service
autovt@.service # necessary for virtual terminals
fail2ban.service
getty@.service # necessary for logging in
networking.service # necessary to have internet connection
nginx.service # useful for bonus part
ssh.service
sshd.service
rsyslog.service # without this service we fail2ban doesn't work
postfix.service
netfilter-persistent.service # for iptables/
```

Stop all unused services with :

```
sudo systemctl disable <SERVICE>
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
- `Root and master mail recipient` = `root@localhost`
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
readonly WATCHED_FILE="/etc/crontab"

touch $SUM_FILE

oldsum=$(cat $SUM_FILE)
newsum=$(shasum $WATCHED_FILE | awk '{ print $1 }')

if [ "$oldsum" != "$newsum" ]
then
	# a modification occured, send an email to the root user
	echo $newsum > $SUM_FILE

	cat <<EOF | sudo mail -s "The file $WATCHED_FILE has been modified" root@localhost
Go to $WATCHED_FILE NOW !
Someone modified it !
EOF
fi
```

Create a file named `monitor.cron` containing the cron scheduling for `monitor.sh` file :

```
0 0 * * * /home/roger/monitor.sh
```

To append this cron job to the previous ones inserted do :

```
sudo crontab -l | cat - ./monitor.cron > crontab.txt && sudo crontab crontab.txt && rm crontab.txt
```

## Serve a Web page with HTTPS

We serve through Nginx a [website](https://github.com/Devessier/login-page-sapper) built using Svelte, Sapper and TailwindCSS.
We add HTTPS support thanks to an [self-signed SSL certificate](https://www.digitalocean.com/community/tutorials/how-to-create-a-self-signed-ssl-certificate-for-nginx-in-ubuntu-16-04).

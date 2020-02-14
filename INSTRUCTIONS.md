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

See `jail.local`.
Links :
- https://serverfault.com/questions/690820/fail2ban-filter-errors 


# Overview

Helper documentation steps for anyone looking to create their own VPN Server.
Creating self host VPN Server to be used when requested by customer.  Creating the server using the OpenVPN Community project.
Download can be found [here](https://openvpn.net/community-downloads/)


## Prerequisite

* Provisioned AWS Elastic IP
* Provisioned AWS EC2 Instance using Ubuntu Server 20.04 LTS Linux 
* Create EC2 Security Group to allow incoming for ports 80, 443 for public
* Optional - Add Allow Security Group incoming for 22 SSH, 943 OpenVPN Default, 1194 OpenVPN Default 
* Add Route53 DNS hosted zone A record for `vpnconnect.<YourCompanyName>.com` with value `<YourEC2_ElasticIP>`

## Get Started

Log into the Server using SSH with `<YourCompanyName>.ppk` AWS key
ec2-user@<YourEC2_ElasticIP>


Download instructions are derived from page below:
https://openvpn.net/download-open-vpn/


Log in as root user to perform below
```
sudo su
```

Install below as root user
```
apt update && apt -y install ca-certificates wget net-tools gnupg
wget -qO - https://as-repository.openvpn.net/as-repo-public.gpg | apt-key add -
echo "deb http://as-repository.openvpn.net/as/debian bionic main">/etc/apt/sources.list.d/openvpn-as-repo.list
apt update && apt -y install openvpn-as
```

### Setup the Hostname for our VPN Server

Go to https://vpnconnect.<YourCompanyName>.com/admin/network_settings
Located in OpenVPN Web Admin UI -> Configuration -> Network Settings -> Hostname and enter `vpnconnect.<YourCompanyName>.com`


### Adding OpenVPN User 

1. Add the local user via the SSH terminal first
```
sudo useradd <myNewUsername>
sudo passwd <myNewUserPassword>

# Enter the new password 
```

2. Login to https://vpnconnect.<YourCompanyName>.com/admin/ with the Admin credentials
 * Go to `User Management` menu on the left and Add the user and select their permission
 

### User Created

Admin username
```
openvpn 
```
Admin password
```
<YourSpecialPasswordHere>@
```

VPN Client
Username
```
<YourRegularUserHere>
```
Password
```
<YourRegularUserPassword>
```


## Adding the Let's Encrypt


Important:  Completed before proceeding.  If you are using Route53 make sure to add the DNS record A record to point to the ElasticIP address of this EC2 you are adding the OpenVPN on.


Add the Let's Encrypt
```
sudo apt-get update
sudo apt-get install software-properties-common
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install python-certbot-nginx
sudo certbot --nginx
sudo certbot --nginx -d vpnconnect.<YourCompanyName>.com
```

### Add the Nginx Configuration to proxy 

Edit the file `/etc/nginx/conf.d/vpnconnect.conf` to handle server name `vpnconnect.<YourCompanyName>.com`
```
server {
 server_name vpnconnect.<YourCompanyName>.com;

 location / {
   proxy_pass https://localhost:943/;
   proxy_redirect http:// https://;
 }

     proxy_http_version 1.1;

     proxy_set_header   Host              $host;
     proxy_set_header   X-Real-IP         $remote_addr;
     proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
     proxy_set_header   X-Forwarded-Proto $scheme;
     proxy_max_temp_file_size 0;

     #this is the maximum upload size

     proxy_connect_timeout      90;
     proxy_send_timeout         90;
     proxy_read_timeout         90;
     proxy_buffering            off;

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/vpnconnect.<YourCompanyName>.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/vpnconnect.<YourCompanyName>.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

server {
  if ($host = vpnconnect.<YourCompanyName>.com) {
      return 301 https://$host$request_uri;
  } # managed by Certbot

  server_name vpnconnect.<YourCompanyName>.com;
  listen 80;
  return 404; # managed by Certbot
}
```

Restart the service for nginx
```
sudo service nginx restart
```

## Update OpenVPN Server to use the Let's Encrypt Certificate

Remain login as root user `sudo su`
Then run the followings
```
service openvpnas stop
```

Create the script below to run SSL key update for OpenVPN to use the Let's Encrypt SSL Certificates


Add the shell script as Root, to be run via Crontab in root.
```
sudo su
```

Edit with content below  `sudo vi /root/update-cert-openvpn.sh`

```
#!/bin/bash

##Let's Encrypt Client Runs Here in standalone mode##

/usr/local/openvpn_as/scripts/confdba -mk cs.ca_bundle -v "`cat /etc/letsencrypt/live/vpnconnect.<YourCompanyName>.com/fullchain.pem`"

/usr/local/openvpn_as/scripts/confdba -mk cs.priv_key -v "`cat /etc/letsencrypt/live/vpnconnect.<YourCompanyName>.com/privkey.pem`" > /dev/null

/usr/local/openvpn_as/scripts/confdba -mk cs.cert -v "`cat /etc/letsencrypt/live/vpnconnect.<YourCompanyName>.com/cert.pem`"

sudo service openvpnas restart
```

Change mode so the file can execute
```
chmod +x /root/update-cert-openvpn.sh
```

## Adding cronjob schedule

### Set Up Let's Encrypt SSL Auto-Renewal and OpenVPN SSL Certificate Update
Letʼs Encryptʼs certificates are only valid for ninety days. This is to encourage users to automate their
certificate renewal process. Weʼll need to set up a regularly run command to check for expiring certificates and
renew them automatically.
To run the renewal check daily, we will use cron, a standard system service for running periodic jobs. We tell
cron what to do by opening and editing a file called a crontab.
```
sudo crontab -e
```
Your text editor will open the default crontab which is a text file with some help text in it. Paste in the following
line at the end of the file, then save and close it: crontab

```
# m h  dom mon dow   command
15 3 * * * sudo /usr/bin/certbot renew --quiet
0 4 * * sat /root/update-cert-openvpn.sh 2>&1
```

The `15 3 * * *` part of this line means `run the following command at 3:15 am, every day`. You may choose any time.

The `0 4 * * sat` means run every Saturday at 4AM.








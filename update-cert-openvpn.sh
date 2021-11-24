#!/bin/bash

##Let's Encrypt Client Runs Here in standalone mode##

/usr/local/openvpn_as/scripts/confdba -mk cs.ca_bundle -v "`cat /etc/letsencrypt/live/vpnconnect.<YourCompanyName>.com/fullchain.pem`"

/usr/local/openvpn_as/scripts/confdba -mk cs.priv_key -v "`cat /etc/letsencrypt/live/vpnconnect.<YourCompanyName>.com/privkey.pem`" > /dev/null

/usr/local/openvpn_as/scripts/confdba -mk cs.cert -v "`cat /etc/letsencrypt/live/vpnconnect.<YourCompanyName>.com/cert.pem`"

service openvpnas restart
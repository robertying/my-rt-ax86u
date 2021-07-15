#!/bin/bash

curl -o /opt/share/chinadns-ng/chinalist.txt https://cdn.jsdelivr.net/gh/robertying/shadowsocks-acl@main/chinalist.txt
curl -o /opt/share/chinadns-ng/gfwlist.txt https://cdn.jsdelivr.net/gh/robertying/shadowsocks-acl@main/gfwlist.txt

cat /opt/share/chinadns-ng/customchina.txt >> /opt/share/chinadns-ng/chinalist.txt
cat /opt/share/chinadns-ng/customgfw.txt >> /opt/share/chinadns-ng/gfwlist.txt

/opt/etc/init.d/S11chinadns-ng restart

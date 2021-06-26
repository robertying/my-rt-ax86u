#!/bin/bash

curl -o /opt/share/chinaipsets/chinaip4.txt https://cdn.jsdelivr.net/gh/17mon/china_ip_list@master/china_ip_list.txt
curl -o /opt/share/chinaipsets/chinaip6.txt https://cdn.jsdelivr.net/gh/gaoyifan/china-operator-ip@ip-lists/china6.txt
echo -e "" >> /opt/share/chinaipsets/chinaip4.txt

sed -e 's/^/add chinaip4 /' /opt/share/chinaipsets/chinaip4.txt > /opt/share/chinaipsets/chinaip4.ipset
sed -e 's/^/add chinaip6 /' /opt/share/chinaipsets/chinaip6.txt > /opt/share/chinaipsets/chinaip6.ipset

ipset create chinaip4 hash:net family inet -exist
ipset create chinaip6 hash:net family inet6 -exist
ipset flush chinaip4
ipset flush chinaip6
ipset restore < /opt/share/chinaipsets/chinaip4.ipset
ipset restore < /opt/share/chinaipsets/chinaip6.ipset

while read -r line || [[ -n "$line" ]]; do
    if [ -n "$line" ]; then
        ipset add chinaip4 "$line"
    fi
done < /opt/share/chinaipsets/custom4.txt

while read -r line || [[ -n "$line" ]]; do
    if [ -n "$line" ]; then
        ipset add chinaip6 "$line"
    fi
done < /opt/share/chinaipsets/custom6.txt

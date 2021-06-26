#!/bin/bash

ACTION=$1 # create / flush
CHINA_IPSET_V4=$2 # chinaip4 / empty
CHINA_IPSET_V6=$3 # chinaip6 / empty
REDIR_PORT=$4 # $PORT / empty
ENABLE_UDP=$5 # "udp" / empty

SS_FWMARK=0xff # right now hardcoded by shadowsocks-rust
FWMARK=0x233 # some uint that is unique across tables

iptables46() {
    iptables "$@"
    ip6tables "$@"
}

flush() {
    ip -4 route del local 0/0 dev lo table 100
    ip -4 rule del fwmark "$FWMARK" table 100
    ip -6 route del local ::/0 dev lo table 100
    ip -6 rule del fwmark "$FWMARK" table 100

    # flush existing rules
    iptables-save | grep -v SHADOWSOCKS | iptables-restore
    ip6tables-save | grep -v SHADOWSOCKS | ip6tables-restore

    echo "Flushed iptables"
}

create() {
    modprobe xt_TPROXY || { echo "Failed to load TPROXY module"; exit 1; }

    readonly IPV4_RESERVED_IPADDRS="\
        0/8 \
        10/8 \
        100.64/10 \
        127/8 \
        169.254/16 \
        172.16/12 \
        192/24 \
        192.0.2.0/24 \
        192.88.99/24 \
        192.168/16 \
        198.18/15 \
        198.51.100/24 \
        203.0.113/24 \
        224/4 \
        240/4 \
        255.255.255.255/32 \
    "
    readonly IPV6_RESERVED_IPADDRS="\
        ::/128 \
        ::1/128 \
        ::ffff:0:0/96 \
        ::ffff:0:0:0/96 \
        64:ff9b::/96 \
        100::/64 \
        2001::/32 \
        2001:20::/28 \
        2001:db8::/32 \
        2002::/16 \
        fc00::/7 \
        fe80::/10 \
        ff00::/8 \
    "

    # add firewall mark
    ip -4 route add local 0/0 dev lo table 100
    ip -4 rule add fwmark "$FWMARK" table 100
    ip -6 route add local ::/0 dev lo table 100
    ip -6 rule add fwmark "$FWMARK" table 100

    # lan rules
    iptables46 -t mangle -N SHADOWSOCKS

    # bypass lan ip
    for addr in $IPV4_RESERVED_IPADDRS; do
        iptables -t mangle -A SHADOWSOCKS -d "$addr" -j RETURN
    done
    for addr in $IPV6_RESERVED_IPADDRS; do
        ip6tables -t mangle -A SHADOWSOCKS -d "$addr" -j RETURN
    done

    # bypass sslocal outbound with mask $SS_FWMARK
    iptables46 -t mangle -A SHADOWSOCKS -m mark --mark "$SS_FWMARK"/"$SS_FWMARK" -j RETURN

    # bypass china ip
    iptables -t mangle -A SHADOWSOCKS -m set --match-set "$CHINA_IPSET_V4" dst -p tcp -j RETURN
    ip6tables -t mangle -A SHADOWSOCKS -m set --match-set "$CHINA_IPSET_V6" dst -p tcp -j RETURN

    # TPROXY TCP/UDP with mask $FWMARK to port $REDIR_PORT
    iptables46 -t mangle -A SHADOWSOCKS -p tcp -j TPROXY --on-port "$REDIR_PORT" --tproxy-mark "$FWMARK/$FWMARK"

    # apply lan rules
    iptables46 -t mangle -A PREROUTING -p tcp -j SHADOWSOCKS

    ##########

    # local rules
    iptables46 -t mangle -N SHADOWSOCKS-MARK

    # bypass lan ip
    for addr in $IPV4_RESERVED_IPADDRS; do
        iptables -t mangle -A SHADOWSOCKS-MARK -d "$addr" -j RETURN
    done
    for addr in $IPV6_RESERVED_IPADDRS; do
        ip6tables -t mangle -A SHADOWSOCKS-MARK -d "$addr" -j RETURN
    done

    # bypass sslocal outbound with mask $SS_FWMARK
    iptables46 -t mangle -A SHADOWSOCKS-MARK -m mark --mark "$SS_FWMARK"/"$SS_FWMARK" -j RETURN

    # bypass china ip
    iptables -t mangle -A SHADOWSOCKS-MARK -m set --match-set "$CHINA_IPSET_V4" dst -p tcp -j RETURN
    ip6tables -t mangle -A SHADOWSOCKS-MARK -m set --match-set "$CHINA_IPSET_V6" dst -p tcp -j RETURN

    # reroute
    iptables46 -t mangle -A SHADOWSOCKS-MARK -p tcp -j MARK --set-xmark "$FWMARK/0xffffffff"

    # apply local rules
    iptables46 -t mangle -A OUTPUT -p tcp -j SHADOWSOCKS-MARK

    ##########

    # udp
    if [ "$ENABLE_UDP" == "udp" ]; then
        # bypass china ip
        iptables -t mangle -A SHADOWSOCKS -m set --match-set "$CHINA_IPSET_V4" dst -p udp -j RETURN
        ip6tables -t mangle -A SHADOWSOCKS -m set --match-set "$CHINA_IPSET_V6" dst -p udp -j RETURN

        # TPROXY TCP/UDP with mask $FWMARK to port $REDIR_PORT
        iptables46 -t mangle -A SHADOWSOCKS -p udp -j TPROXY --on-port "$REDIR_PORT" --tproxy-mark "$FWMARK/$FWMARK"

        # apply lan rules
        iptables46 -t mangle -A PREROUTING -p udp -j SHADOWSOCKS

            # bypass china ip
        iptables -t mangle -A SHADOWSOCKS-MARK -m set --match-set "$CHINA_IPSET_V4" dst -p udp -j RETURN
        ip6tables -t mangle -A SHADOWSOCKS-MARK -m set --match-set "$CHINA_IPSET_V6" dst -p udp -j RETURN

        # reroute
        iptables46 -t mangle -A SHADOWSOCKS-MARK -p udp -j MARK --set-xmark "$FWMARK/0xffffffff"

        # apply local rules
        iptables46 -t mangle -A OUTPUT -p udp -j SHADOWSOCKS-MARK
    fi

    echo "Created iptables"
}

if [ "$ACTION" == "flush" ]; then
    flush
elif [ "$ACTION" == "create" ]; then
    create
fi

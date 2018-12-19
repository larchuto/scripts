#!/bin/sh

TCP_=6
UDP_=17
BOTH_=$TCP_,$UDP_

ORIGIN_=webui
SOURCE_INTERFACE_=data

SYSBUS=~/sysbus/sysbus.py


function set_port_forwarding_rule {
    ARG_INTERNAL_PORT=$1
    ARG_EXTERNAL_PORT=$2
    ARG_PROTOCOL=$3
    ARG_TARGET_IP_ADDR=$4

    ORIGIN=$ORIGIN_
    SOURCE_INTERFACE=$SOURCE_INTERFACE_
    INTERNAL_PORT=$ARG_INTERNAL_PORT
    DESTINATION_IP_ADDRESS=$ARG_TARGET_IP_ADDR
    PROTOCOL=$ARG_PROTOCOL

    # opt values
    ID=""
    EXTERNAL_PORT=$ARG_EXTERNAL_PORT
    SOURCE_PREFIX=""
    ENABLE=True
    PERSISTANT=""
    DESCRIPTION=""
    DESTINATION_MAC_ADDRESS=""
    LEASE_DURATION=""
    UPNPVN1_COMPAT=False

    $SYSBUS sysbus.Firewall:setPortForwarding \
        id="$ID" \
        origin="$ORIGIN" \
        sourceInterface="$SOURCE_INTERFACE" \
        externalPort="$EXTERNAL_PORT" \
        internalPort="$INTERNAL_PORT" \
        destinationIPAddress="$DESTINATION_IP_ADDRESS" \
        sourcePrefix="$SOURCE_PREFIX" \
        protocol="$PROTOCOL" \
        enable="$ENABLE" \
        persistent="$PERSISTANT" \
        description="$DESCRIPTION" \
        destinationMACAddress="$DESTINATION_MAC_ADDRESS" \
        leaseDuration="$LEASE_DURATION" \
        upnpv1Compat="$UPNPVN1_COMPAT"
}

function delete_port_forwarding_rule {
    ARG_TARGET_IP_ADDR=$1

    ORIGIN=$ORIGIN_
    DESTINATION_IP_ADDRESS=$ARG_TARGET_IP_ADDR

    $SYSBUS sysbus.Firewall:deletePortForwarding \
        origin="$ORIGIN" \
        DestinationIPAddress="$DESTINATION_IP_ADDRESS"
}

function config_sysbus {
    ARG_PASSWORD=$1
    ARG_LIVEBOX_VERSION=lb$2

    $SYSBUS -config -password $ARG_PASSWORD -lversion $ARG_LIVEBOX_VERSION
}


function open_ssh_access {
    ARG_LOCAL_IP_ADDRESS=$1

    SSH_PORT=22

    systemctl start sshd &&
    set_port_forwarding_rule $SSH_PORT $SSH_PORT $BOTH_ $ARG_LOCAL_IP_ADDRESS 1&>/dev/null

    echo "Accès SSH ouvert."
}

function close_ssh_access {
    ARG_LOCAL_IP_ADDRESS=$1

    systemctl stop sshd &&
    delete_port_forwarding_rule $ARG_LOCAL_IP_ADDRESS 1&>/dev/null &&

    echo "Accès SSH fermé."
}

function print_ssh_infos {
    DISTANT_IP_ADDRESS=$($SYSBUS -info | grep ExternalIPAddress | cut -d ":" -f2 | tr -d " ")
    USER=$(whoami)

    echo "Addresse IP : $DISTANT_IP_ADDRESS"
    echo "Nom d'utilisateur : $USER"
}

function check_config_ok {
    if [ ! -f ~/.sysbusrc ]; then
        echo "Erreur, la configuration du mot de passe administrateur et de la version de la livebox semble ne pas avoir été faite !"
        exit 1
    fi
}

function print_usage {
    echo "Utilisation :"
    echo -e "\t$0 {help|open|close|infos}"
    echo -e "\t$0 config <livebox admin password> <livebox version number>"
}

function print_help {
    print_usage
    echo ""
    echo "Ouvre ou ferme l'accès SSH au travers d'une livebox."
    echo ""
    echo "Commandes :"
    echo -e "\thelp :"
    echo -e "\t\tAffiche cette aide."
    echo -e "\topen :"
    echo -e "\t\tOuvre le port SSH sur la livebox et démarre le service sshd."
    echo -e "\tclose :"
    echo -e "\t\tFerme le port SSH sur la livebox et arrête le service sshd."
    echo -e "\tinfos :"
    echo -e "\t\tRetourne l'addresse IP publique et le nom d'utilisateur."
    echo -e "\tconfig <password> <version> :"
    echo -e "\t\tEnregistre le mot de passe administrateur de la livebox ainsi que sa version."
    echo -e "\t\tCette action est necessaire pour pouvoir utiliser l'outil."
}


LOCAL_IP_ADDRESS=$(ip route | grep src | head -n 1 | cut -d ' ' -f9)

if [ -z "$1" ]; then
    echo "Erreur, commande manquante."
    print_usage
    exit 1
fi

CMD=$1

if [ "$CMD" = "help" ]; then
    print_help
elif [ "$CMD" = "open" ]; then
    check_config_ok
    open_ssh_access $LOCAL_IP_ADDRESS
elif [ "$CMD" = "close" ]; then
    check_config_ok
    close_ssh_access $LOCAL_IP_ADDRESS
elif [ "$CMD" = "infos" ]; then
    check_config_ok
    print_ssh_infos
elif [ "$CMD" = "config" ]; then
    if [ "$#" != "3" ]; then
        echo -e "Erreur, arguments maquants ou trop nombreux."
        print_usage
        exit 1
    else
        config_sysbus $2 $3
    fi
else
    echo "Erreur, commande invalide : $CMD."
    print_usage
    exit 1
fi


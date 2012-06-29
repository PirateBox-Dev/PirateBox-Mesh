#!/bin/sh

#------------------------------------ 
#  Configuration for piratebox-mesh
#------------------------------------

RADIODEVICE=radio0
OPENWRT=no
OPENWRT_NETWORK="meshwork"
# Interface for normal AP Mode
AP_IF=wlan0
# Interface for MESH
MESH_IF=mesh0
# Channel
#  If 0 it will use the same channel as configured 
#       in /etc/config/wireless -> RADIODEVICE
MESH_CHANNEL=0
# Mesh-SSID
MESH_SSID="PB-Mesh"
# Needed MTU for B.A.T.M.A.N.
MTU_NEEDED=1528
# Change this to 2nd card, if needed
IW_DEVICE=phy0
# Source MAC Adress.. If non WRT should be filled
SOURCEMAC=""
# Modified MAC
#   if empty, it will exchange a few letters for itself
MODMAC=""
# Needed for 2nd device comming up
EXCHANGE_MAC="yes"

#Fixed BSSID to avoid cell splitting
CUSTOM_BSSID="12:CA:FF:EE:BA:BA"

#Disable RTS/CTS
DISABLE_RTS="yes"

####
# BATMAN stuff
BAT_IF=bat0
# Increase lookup Frequency to 5s
BAT_INT=5000

#-------------------------------------------
# SET Ipv6 Stuff
SET_IPV6="no"
# Do you want a fixed address?
IPV6_FIXED=""

####--------
#  Extracts the fe80 address and adds an choosen prefix
####
SET_GENERATED_IPV6="yes"
#used for mesh if
IPV6_GEN_PREFIX="fdc0:ffea"
#Enter without /
IPV6_GEN_NETMASK="48"
#---------------------------------------------

#---------------------------------------------
# IPV4 Stuff
SET_IPV4="yes"
# Do you want to choose your IP? 
IPV4_FIXED=""
IPV4_SUBNET_MASK="255.0.0.0"

# Generates a 10.x.y.z  IP Adress
IPV4_GENERATE="no"

#Load from file or openWRT config (if openwrt)
IPV4_LOAD="yes"

IPV4_IP_SAVE=/etc/mesh_ipv4.cfg

#----- Configuration END

#-------- Common Functiond
BATCTL_FOUND="yes"
V6_GEN_RESULT=""

check_rc() {
  MSG=""
  if [ -n "$2" ] ; then
    MSG="Error in $2"
  else
    MSG="Failed with RC $1"
  fi
  [ "$1" != "0" ] && echo $MSG && exit 255
}


uci_get_details() {
  #get mac Adress from uci
  SOURCEMAC=$(uci get wireless.$RADIODEVICE.macaddr)
  check_rc $? "getting  SourceMac"
  [[ $MESH_CHANNEL = "0" ]] && MESH_CHANNEL=$( uci get wireless.$RADIODEVICE.channel)
  check_rc $? "getting Channel"

  if [ "$IPV4_LOAD" = "yes" ] ; then
     $IPV4_FIXED=$(uci get network.$OPENWRT_NETWORK.ipaddr) 
     check_rc $? "getting  IPv4 from openwrt config"
  fi
}

generate_v6() {
  IF=$1
  PREFIX="fd00"

  test -n "$2" && PREFIX=$2

  CURRENT_GEN=`ifconfig $IF |
          grep "inet6 addr: fe80" |
          sed  -n "s|^.*::\([^/]*\)/.*|\1|p" |
          tr -d ":"`

  FIXED=`echo ${CURRENT_GEN} | tr -d "\012" | 
                 sed "s|\(....\)\(....\)\(....\)\(....\)|\1:\2:\3:\4|"`

  echo "Extracted for $IF : $PREFIX::$FIXED "
  V6_GEN_RESULT="$PREFIX::$FIXED"
}


RANDOM_NUM=0
random_num() {
  NUM=$((`</dev/urandom tr -dc 1-9 | head -c3`))
  [[ "$NUM" >  "254" ]] && NUM=$(($NUM / 7))
  RANDOM_NUM=$NUM
}

RANDOM_IP_NUM=0
random_ip_num() {
  #Repeat until IP is in range
  RANDOM_IP_NUM=0
  RANDOM_NUM=0
  until  [[  "$RANDOM_NUM" -gt "000" ]] && [[ $RANDOM_NUM -lt "255" ]]
  do
     random_num
     [[ 1 == 2  ]] && echo  "Result random_num $RANDOM_NUM" 
  done
  RANDOM_IP_NUM=$RANDOM_NUM

   [[ 1 == 2  ]] &&  echo "result random_ip_num $RANDOM_IP_NUM"
}


generate_ipv4() {
    # 10.x.y.z
    x=0
    y=0
    z=0

    random_ip_num
    x=$RANDOM_IP_NUM
    random_ip_num
    y=$RANDOM_IP_NUM
    random_ip_num
    z=$RANDOM_IP_NUM

    IPV4_FIXED="10.$x.$y.$z"
} 

modify_MAC() {
  # Modify MAC for 2nd interface if not set
  #Change two letters
  if [ "$MODMAC" = "" ] ;  then
    MODMAC=$( echo $SOURCEMAC | sed 's/c/a/'  | sed 's/1/2/' )
    check_rc $?  "sed :( "
    echo "Found MAC for $RADIODEVICE :  $SOURCEMAC"
    echo " modified for 2nd Wifi-if  :  $MODMAC"
  fi
}

do_wlan_if_up() {
   echo  "Setting up AdHoc Interface for B.A.T.M.A.N. "
   iw $IW_DEVICE interface add $MESH_IF type adhoc
   check_rc $?

   echo "Setting fixed BSSID up"
   iwconfig $MESH_IF ap $CUSTOM_BSSID
   check_rc $?

   if [ "$DISABLE_RTS" = "yes" ] ; then
     echo "Disabling RTS/CTS "
     iwconfig $MESH_IF rts off
     check_rc $?
   fi

  echo "Increasing MTU for $MESH_IF to $MTU_NEEDED"
  ifconfig $MESH_IF mtu $MTU_NEEDED
  check_rc $?

  # Only disable, if IPV6 exists on device
  if [ -e "/proc/sys/net/ipv6/conf/$MESH_IF/disable_ipv6" ] ; then
	  echo "Disabling IPV6 for $MESH_IF - IF without any configuration!"
	  echo "1" > /proc/sys/net/ipv6/conf/$MESH_IF/disable_ipv6
	  check_rc $?
  fi	  

  if [ "$EXCHANGE_MAC" = "yes" ] ; then
    echo "Changing $MESH_IF MAC to $MODMAC"
    ifconfig $MESH_IF hw ether $MODMAC
    check_rc $?
  fi

  echo "Setting up Channel $MESH_CHANNEL"
  iwconfig $MESH_IF channel $MESH_CHANNEL
  check_rc $?

  echo "Setting SSID for Mesh $MESH_SSID"
  iwconfig $MESH_IF  essid  $MESH_SSID
  check_rc $?
}


save_gen_ipv4() {
     #Save IPv4 Address to tmp-space for later use
     echo "$IPV4_FIXED" > $IPV4_IP_SAVE
}

load_gen_ipv4() {
     IPV4_FIXED=$(cat $IPV4_IP_SAVE)
}

do_batman_up() {
  if [ "$BATCTL_FOUND" = "yes" ] ; then
     echo "Adding $MESH_IF to B.A.T.M.A.N."
     batctl if add  $MESH_IF  
     check_rc $?
  else
      echo "Adding $MESH_IF to B.A.T.M.A.N. via  /sys/class/ "
      echo "$BAT_IF" > /sys/class/net/$MESH_IF/batman_adv/mesh_iface 
       check_rc $?
  fi

  echo "Starting $BAT_IF"
  ifconfig $BAT_IF 0.0.0.0 up
  check_rc $?

  if [ "$BATCTL_FOUND" = "yes" ] ; then
    echo "Setting B.A.T.M.A.N. Intervall to $BAT_INT "
    batctl it $BAT_INT
    check_rc $?
  else 
    echo "Setting B.A.T.M.A.N. Intervall via /sys/class/ to $BAT_INT "
    echo "$BAT_INT"  > /sys/class/net/$BAT_IF/mesh/orig_interval 
    check_rc $?
  fi

  if [ "$SET_GENERATED_IPV6" = "yes" ] ; then
    echo "Generating IPv6 address for $BAT_IF"
    generate_v6 $BAT_IF $IPV6_GEN_PREFIX
    check_rc $?
    IPV6_FIXED="$V6_GEN_RESULT"/"$IPV6_GEN_NETMASK" 
  fi

  if [ "$SET_IPV6" = "yes" ] ; then
    echo "Setting up ipv6 address ->$IPV6_FIXED<-  on  $BAT_IF"
    ifconfig  "$BAT_IF"  add $IPV6_FIXED
    check_rc $?
  fi

  if [ "$IPV4_GENERATE" = "yes" ] ; then
     echo "Generating IPv4 10.x.y.z address for $BAT_IF "
     generate_ipv4
  fi

  if [ "$IPV4_LOAD" = "yes" ] ; then
     load_gen_ipv4 
  fi

  if [ "$SET_IPV4" = "yes" ] ; then
    echo "Setting up ipv4 address ->$IPV4_FIXED<-  on  $BAT_IF"
     ifconfig  "$BAT_IF"  add $IPV4_FIXED netmask $IPV4_SUBNET_MASK
     check_rc $?
  fi
}

mesh_start() {
  echo "Starting Mesh-IF!" 
  ifconfig $MESH_IF 0.0.0.0 up
  check_rc $?

# Extract auto IPV6 adress and remove it from mesh if
#  AUTO_IPV6=$( ifconfig $MESH_IF | grep "inet6.* " | sed -e "s/^.*inet6 addr: //" -e "s/ Scope.*\$//" )
#  echo "Removing .. $AUTO_IPV6 from $MESH_IF"
#  ifconfig $MESH_IF inet6 del $AUTO_IPV6
#  check_rc $? "resetting IPv6 on $MESH_IF"

}

mesh_stop() {
  echo "Stopping Mesh if!"
  ifconfig $MESH_IF down
}

do_wlan_if_down() {
   echo "Cleaning up interfaces"
   iw dev $MESH_IF del 
}

do_batman_down() {
  if [ "$BATCTL_FOUND" = "yes" ] ; then
     echo "Remove $MESH_IF from  $BAT_IF "
     batctl if del $MESH_IF
  else
    echo "Remove $MESH_IF from  $BAT_IF via /sys/class/"
    echo none  > /sys/class/net/$MESH_IF/batman_adv/mesh_iface
  fi
}

check_requirements() {
  lsmod | grep batman >> /dev/null
  if [ "$?" != "0" ] ; then
     modprobe  batman-adv
     check_rc $? "Loading kernel module batman-adv failed.. maybe not installed?"
  fi
  batctl if > /dev/null
  if [ $? != "0" ] ; then 
    echo "Failed running batctl- maybe not installed? "
    echo "Try to use  /sys/class/"  
    BATCTL_FOUND='no'
  fi
}

build_mesh() {
  check_requirements
  echo "Starting Mesh Network with uci-collect..."
  [ "$OPENWRT" = "yes" ] &&  echo "Starting Mesh Network with uci-collect..." \
  	&& uci_get_details
  modify_MAC
  do_wlan_if_up
  mesh_start
  do_batman_up
  echo "finished"
}

destroy_mesh() {
  echo "Stopping Mesh Network..."
  mesh_stop
  do_batman_down
  do_wlan_if_down
  echo "finished"
}


openwrt_postinst() {
  echo "Generating IPv4 ..."
  generate_ipv4 
  save_gen_ipv4 
  echo "Generated $IPV4_FIXED for this box!"

  echo "Backuping /etc/config/network"
  cp -v  /etc/config/network /etc/config/network_pre_mesh.backup
  echo "Backuping /etc/config/firewall"
  cp -v  /etc/config/firewall /etc/config/firewall_pre_mesh.backup

  echo "Do interface $OPENWRT_NETWORK  setup on /etc/config/network"
  uci set network.$OPENWRT_NETWORK=interface
  uci set network.$OPENWRT_NETWORK.ipaddr=$IPV4_FIXED
  uci set network.$OPENWRT_NETWORK.netmask=$IPV4_SUBNET_MASK
  uci set network.$OPENWRT_NETWORK.proto=static
  uci set network.$OPENWRT_NETWORK.ifname=$BAT_IF
  uci commit

  echo "Do firewall configuration /etc/config/firewall"

  #Enable Forward on lan zone. Lan zone is always the first
  # in MR3020
  echo " ... enabling forward on lan"
  uci set firewall.@zone[0].forward=ACCEPT
 
  echo " ... inserting new zone $OPENWRT_NETWORK"
  uci add firewall zone
  uci set firewall.@zone[-1].name=$OPENWRT_NETWORK
  uci set firewall.@zone[-1].masq=1
  uci set firewall.@zone[-1].mtu_fix=1
  uci set firewall.@zone[-1].input=ACCEPT
  uci set firewall.@zone[-1].output=ACCEPT
  uci set firewall.@zone[-1].forward=REJECT

  echo " ... adding new forward-rule"
  uci add firewall forwarding
  uci set firewall.@forwarding[-1].src=lan
  uci set firewall.@forwarding[-1].dest=$OPENWRT_NETWORK

  uci commit

}

openwrt_preremove() {
   if [ -f /etc/config/network_pre_mesh.backup ] ; then
      echo "Saving current state of config/network"
      mv  /etc/config/network /etc/config/network_after_mesh.backup
      echo "Restoring config/network"
      mv  /etc/config/network_pre_mesh.backup /etc/config/network
   fi

   if [ -f /etc/config/firewall_pre_mesh.backup ] ; then
      echo "Saving current state of config/firewall"
      mv /etc/config/firewall /etc/config/firewall_after_mesh.backup
      echo "Restoring config/firewall"
      mv /etc/config/firewall_pre_mesh.backup /etc/config/firewall
   fi
}

## mesh.common END


#  ----piece_start_stop Start
# -- Stuff will be added on Make 

check_config() {
  if [ "$MESH_CHANNEL" = "0" ] ; then 
     echo "Please set option MESH_CHANNEL"
     exit 255
  elif [ "$SOURCEMAC" =  "$MODMAC"  ] ; then
     echo "Please set option SOURCEMAC to the MAC Address of you wifi device"
     ifconfig wlan0 || ifconfig
     echo "Please set option SOURCEMAC to the MAC Address of you wifi device"
     echo "   or enter a modified one in MODMAC and set EXCHANGE_MAC=no "
     exit 255
  fi
}


#  Start Stop stuff for running in script directly
if [ "$1" = "start" ] ; then
  check_config   
  build_mesh
elif  [  "$1" = "stop" ] ; then
  destroy_mesh
elif [  "$1" = "restart" ] ; then
  destroy_mesh
  check_config
  build_mesh
elif [ "$1" = "test_gen" ] ; then
  generate_ipv4
  echo "Generated IPv4: $IPV4_FIXED"
else
  echo "valid options are start|stop|restart"
  exit 255
fi
#  ----piece_start_stop End



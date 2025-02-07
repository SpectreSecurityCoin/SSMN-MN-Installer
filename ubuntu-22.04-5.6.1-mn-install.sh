#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="spectresecurity.conf"
SPECTRESECURITY_DAEMON="/usr/local/bin/spectresecurityd"
SPECTRESECURITY_CLI="/usr/local/bin/spectresecurity-cli"
SPECTRESECURITY_REPO="https://github.com/SpectreSecurityCoin/SpectreSecurityMN.git"
SPECTRESECURITY_PARAMS="https://github.com/SpectreSecurityCoin/SpectreSecurityMN/releases/download/5.6.1/util.zip"
SPECTRESECURITY_LATEST_RELEASE="https://github.com/SpectreSecurityCoin/SpectreSecurityMN/releases/download/5.6.1/spectresecurity-5.6.1-ubuntu22-daemon.zip"
COIN_BOOTSTRAP='https://bootstrap.spectresecurity.com/boot_strap.tar.gz'
COIN_ZIP=$(echo $SPECTRESECURITY_LATEST_RELEASE | awk -F'/' '{print $NF}')
COIN_CHAIN=$(echo $COIN_BOOTSTRAP | awk -F'/' '{print $NF}')
COIN_NAME='SpectreSecurity'
CONFIGFOLDER='.spectresecurity'
COIN_BOOTSTRAP_NAME='boot_strap.tar.gz'

DEFAULT_SPECTRESECURITY_PORT=7272
DEFAULT_SPECTRESECURITY_RPC_PORT=7273
DEFAULT_SPECTRESECURITY_USER="spectresecurity"
SPECTRESECURITY_USER="spectresecurity"
NODE_IP=NotCheckedYet
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function download_bootstrap() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME BootStrap${NC}"
  mkdir -p /opt/chaintmp/
  cd /opt/chaintmp >/dev/null 2>&1
  rm -rf boot_strap* >/dev/null 2>&1
  wget $COIN_BOOTSTRAP >/dev/null 2>&1
  cd /home/$SPECTRESECURITY_USER/$CONFIGFOLDER
  rm -rf sporks zerocoin blocks database chainstate peers.dat
  cd /opt/chaintmp >/dev/null 2>&1
  tar -zxf $COIN_BOOTSTRAP_NAME
  cp -Rv cache/* /home/$SPECTRESECURITY_USER/$CONFIGFOLDER/ >/dev/null 2>&1
  chown -Rv $SPECTRESECURITY_USER /home/$SPECTRESECURITY_USER/$CONFIGFOLDER >/dev/null 2>&1
  cd ~ >/dev/null 2>&1
  rm -rf /opt/chaintmp >/dev/null 2>&1
  clear
}

function install_params() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME Params Files${NC}"
  mkdir -p /opt/tmp/
  cd /opt/tmp
  rm -rf util* >/dev/null 2>&1
  wget -q $SPECTRESECURITY_PARAMS
  unzip $SPECTRESECURITY_PARAMS >/dev/null 2>&1
  unzip util.zip >/dev/null 2>&1
  chmod -Rv 777 /opt/tmp/util/fetch-params.sh >/dev/null 2>&1
  runuser -l $SPECTRESECURITY_USER -c '/opt/tmp/util/./fetch-params.sh' >/dev/null 2>&1
}

purgeOldInstallation() {
    echo -e "${GREEN}Searching and removing old $COIN_NAME Daemon{NC}"
    #kill wallet daemon
	systemctl stop $SPECTRESECURITY_USER.service
	
	#Clean block chain for Bootstrap Update
    cd $CONFIGFOLDER >/dev/null 2>&1
    rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
	
    #remove binaries and SpectreSecurity utilities
    cd /usr/local/bin && sudo rm spectresecurity-cli spectresecurity-tx spectresecurityd > /dev/null 2>&1 && cd
    echo -e "${GREEN}* Done${NONE}";
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *22.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 22.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $SPECTRESECURITY_DAEMON)" ] || [ -e "$SPECTRESECURITY_DAEMON" ] ; then
  echo -e "${GREEN}\c"
  echo -e "SpectreSecurity is already installed. Exiting..."
  echo -e "{NC}"
  exit 1
fi
}

function prepare_system() {

echo -e "Prepare the system to install SpectreSecurity master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding Pivx PPA repository"
apt-add-repository -y ppa:pivx/berkeley-db4 >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get upgrade >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" git make build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libssl-dev libgmp-dev libevent-dev libboost-all-dev libdb4.8-dev libdb4.8++-dev ufw fail2ban pwgen curl unzip libminiupnpc-dev libnatpmp-dev libzmq3-dev >/dev/null 2>&1
NODE_IP=$(curl -s4 icanhazip.com)
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt-get -y upgrade"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:pivx/berkeley-db4"
    echo "apt-get update"
    echo "apt install -y git make build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libssl-dev libgmp-dev libevent-dev libboost-all-dev libdb4.8-dev libdb4.8++-dev unzip libminiupnpc-dev libnatpmp-dev libzmq3-dev -y"
    exit 1
fi
clear

}

function ask_yes_or_no() {
  read -p "$1 ([Y]es or [N]o | ENTER): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

function compile_spectresecurity() {
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "4" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 4G of RAM without SWAP, creating 8G swap file.${NC}"
    SWAPFILE=/swapfile
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=8388608
    chown root:root $SWAPFILE
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon $SWAPFILE
    echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
else
  echo -e "${GREEN}Server running with at least 4G of RAM, no swap needed.${NC}"
fi
clear
  echo -e "Clone git repo and compile it. This may take some time."
  cd $TMP_FOLDER
  git clone $SPECTRESECURITY_REPO spectresecurity
  cd spectresecurity
  ./autogen.sh
  ./configure
  make
  strip src/spectresecurityd src/spectresecurity-cli src/spectresecurity-tx
  make install
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function copy_spectresecurity_binaries(){
   cd /root
  wget $SPECTRESECURITY_LATEST_RELEASE
  unzip spectresecurity-5.6.1-ubuntu22-daemon.zip
  cp spectresecurity-cli spectresecurityd spectresecurity-tx /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/spectresecurity* >/dev/null
  clear
}

function install_spectresecurity(){
  echo -e "Installing SpectreSecurity files."
  echo -e "${GREEN}You have the choice between source code compilation (slower and requries 4G of RAM or VPS that allows swap to be added), or to use precompiled binaries instead (faster).${NC}"
  if [[ "no" == $(ask_yes_or_no "Do you want to perform source code compilation?") || \
        "no" == $(ask_yes_or_no "Are you **really** sure you want compile the source code, it will take a while?") ]]
  then
    copy_spectresecurity_binaries
    clear
  else
    compile_spectresecurity
    clear
  fi
}

function enable_firewall() {
  echo -e "Installing fail2ban and setting up firewall to allow ingress on port ${GREEN}$SPECTRESECURITY_PORT${NC}"
  ufw allow $SPECTRESECURITY_PORT/tcp comment "SpectreSecurity MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function systemd_spectresecurity() {
  cat << EOF > /etc/systemd/system/$SPECTRESECURITY_USER.service
[Unit]
Description=SpectreSecurity service
After=network.target
[Service]
ExecStart=$SPECTRESECURITY_DAEMON -conf=$SPECTRESECURITY_FOLDER/$CONFIG_FILE -datadir=$SPECTRESECURITY_FOLDER
ExecStop=$SPECTRESECURITY_CLI -conf=$SPECTRESECURITY_FOLDER/$CONFIG_FILE -datadir=$SPECTRESECURITY_FOLDER stop
Restart=always
User=$SPECTRESECURITY_USER
Group=$SPECTRESECURITY_USER

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $SPECTRESECURITY_USER.service
  systemctl enable $SPECTRESECURITY_USER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$SPECTRESECURITY_USER | grep $SPECTRESECURITY_DAEMON)" ]]; then
    echo -e "${RED}spectresecurityd is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $SPECTRESECURITY_USER.service"
    echo -e "systemctl status $SPECTRESECURITY_USER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function ask_port() {
read -p "SPECTRESECURITY Port: " -i $DEFAULT_SPECTRESECURITY_PORT -e SPECTRESECURITY_PORT
: ${SPECTRESECURITY_PORT:=$DEFAULT_SPECTRESECURITY_PORT}
}

function ask_user() {
  echo -e "${GREEN}The script will now setup SpectreSecurity user and configuration directory. Press ENTER to accept defaults values.${NC}"
  read -p "SpectreSecurity user: " -i $DEFAULT_SPECTRESECURITY_USER -e SPECTRESECURITY_USER
  : ${SPECTRESECURITY_USER:=$DEFAULT_SPECTRESECURITY_USER}

  if [ -z "$(getent passwd $SPECTRESECURITY_USER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $SPECTRESECURITY_USER
    echo "$SPECTRESECURITY_USER:$USERPASS" | chpasswd

    SPECTRESECURITY_HOME=$(sudo -H -u $SPECTRESECURITY_USER bash -c 'echo $HOME')
    DEFAULT_SPECTRESECURITY_FOLDER="$SPECTRESECURITY_HOME/.spectresecurity"
    read -p "Configuration folder: " -i $DEFAULT_SPECTRESECURITY_FOLDER -e SPECTRESECURITY_FOLDER
    : ${SPECTRESECURITY_FOLDER:=$DEFAULT_SPECTRESECURITY_FOLDER}
    mkdir -p $SPECTRESECURITY_FOLDER
    chown -R $SPECTRESECURITY_USER: $SPECTRESECURITY_FOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $SPECTRESECURITY_PORT ]] || [[ ${PORTS[@]} =~ $[SPECTRESECURITY_PORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $SPECTRESECURITY_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$DEFAULT_SPECTRESECURITY_RPC_PORT
listen=1
server=0
daemon=1
port=$SPECTRESECURITY_PORT
#External SpectreSecurity IPV4
addnode=199.127.140.224:7272
addnode=199.127.140.225:7272
addnode=199.127.140.228:7272
addnode=199.127.140.231:7272
addnode=199.127.140.233:7272
addnode=199.127.140.235:7272
addnode=199.127.140.236:7272

#External SpectreSecurity IPV6
addnode=[2604:6800:5e11:3611::1]:7272
addnode=[2604:6800:5e11:3611::2]:7272
addnode=[2604:6800:5e11:3612::4]:7272
addnode=[2604:6800:5e11:3613::2]:7272
addnode=[2604:6800:5e11:3613::5]:7272
addnode=[2604:6800:5e11:3614::1]:7272
addnode=[2604:6800:5e11:3614::2]:7272
addnode=[2604:6800:5e11:3614::3]:7272
addnode=[2604:6800:5e11:3614::4]:7272

#External WhiteListing IPV4
whitelist=199.127.140.224
whitelist=199.127.140.225
whitelist=199.127.140.228
whitelist=199.127.140.231
whitelist=199.127.140.233
whitelist=199.127.140.235
whitelist=199.127.140.236

#External WhiteListing IPV6
whitelist=[2604:6800:5e11:3611::1]
whitelist=[2604:6800:5e11:3611::2]
whitelist=[2604:6800:5e11:3612::4]
whitelist=[2604:6800:5e11:3613::2]
whitelist=[2604:6800:5e11:3613::5]
whitelist=[2604:6800:5e11:3614::1]
whitelist=[2604:6800:5e11:3614::2]
whitelist=[2604:6800:5e11:3614::3]
whitelist=[2604:6800:5e11:3614::4]

#Internal WhiteListing IPV4
whitelist=10.36.11.1
whitelist=10.36.11.2
whitelist=10.36.12.4
whitelist=10.36.13.2
whitelist=10.36.13.5
whitelist=10.36.14.1
whitelist=10.36.14.2
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e SPECTRESECURITY_KEY
  if [[ -z "$SPECTRESECURITY_KEY" ]]; then
  su $SPECTRESECURITY_USER -c "$SPECTRESECURITY_DAEMON -conf=$SPECTRESECURITY_FOLDER/$CONFIG_FILE -datadir=$SPECTRESECURITY_FOLDER -daemon"
  sleep 15
  if [ -z "$(ps axo user:15,cmd:100 | egrep ^$SPECTRESECURITY_USER | grep $SPECTRESECURITY_DAEMON)" ]; then
   echo -e "${RED}SpectreSecurityd server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  SPECTRESECURITY_KEY=$(su $SPECTRESECURITY_USER -c "$SPECTRESECURITY_CLI -conf=$SPECTRESECURITY_FOLDER/$CONFIG_FILE -datadir=$SPECTRESECURITY_FOLDER createmasternodekey")
  su $SPECTRESECURITY_USER -c "$SPECTRESECURITY_CLI -conf=$SPECTRESECURITY_FOLDER/$CONFIG_FILE -datadir=$SPECTRESECURITY_FOLDER stop"
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $SPECTRESECURITY_FOLDER/$CONFIG_FILE
  cat << EOF >> $SPECTRESECURITY_FOLDER/$CONFIG_FILE
maxconnections=256
masternode=1
masternodeaddr=$NODE_IP:$SPECTRESECURITY_PORT
masternodeprivkey=$SPECTRESECURITY_KEY
EOF
  chown -R $SPECTRESECURITY_USER: $SPECTRESECURITY_FOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "SpectreSecurity Masternode is up and running as user ${GREEN}$SPECTRESECURITY_USER${NC} and it is listening on port ${GREEN}$SPECTRESECURITY_PORT${NC}."
 echo -e "${GREEN}$SPECTRESECURITY_USER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$SPECTRESECURITY_FOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $SPECTRESECURITY_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $SPECTRESECURITY_USER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODE_IP:$SPECTRESECURITY_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$SPECTRESECURITY_KEY${NC}"
 echo -e "Please check SpectreSecurity is running with the following command: ${GREEN}systemctl status $SPECTRESECURITY_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
   ask_user
  install_params
  download_bootstrap
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  systemd_spectresecurity
  important_information
}


##### Main #####
clear
purgeOldInstallation
checks
prepare_system
install_spectresecurity
setup_node

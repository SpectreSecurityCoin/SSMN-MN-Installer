#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="spectresecurity.conf"
SPECTRESECURITY_DAEMON="/usr/local/bin/spectresecurityd"
SPECTRESECURITY_CLI="/usr/local/bin/spectresecurity-cli"
SPECTRESECURITY_REPO="https://github.com/SpectreSecurityCoin/SpectreSecurityMN.git"
SPECTRESECURITY_LATEST_RELEASE="https://github.com/SpectreSecurityCoin/SpectreSecurityMN/releases/download/5.6.1/spectresecurity-5.6.1-ubuntu-20-daemon.zip"
COIN_BOOTSTRAP='https://bootstrap.spectresecurity.com/boot_strap.tar.gz'
COIN_ZIP=$(echo $SPECTRESECURITY_LATEST_RELEASE | awk -F'/' '{print $NF}')
COIN_CHAIN=$(echo $COIN_BOOTSTRAP | awk -F'/' '{print $NF}')

DEFAULT_SPECTRESECURITY_PORT=7272
DEFAULT_SPECTRESECURITY_RPC_PORT=7273
DEFAULT_SPECTRESECURITY_USER="spectresecurity"
SPECTRESECURITY_USER="spectresecurity"
NODE_IP=NotCheckedYet
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

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


function download_bootstrap() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME BootStrap${NC}"
  mkdir -p /root/tmp
  cd /root/tmp >/dev/null 2>&1
  rm -rf boot_strap* >/dev/null 2>&1
  wget -q $COIN_BOOTSTRAP
  cd $CONFIGFOLDER >/dev/null 2>&1
  rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
  cd /root/tmp >/dev/null 2>&1
  tar -zxf $COIN_CHAIN /root/tmp >/dev/null 2>&1
  cp -Rv cache/* $CONFIGFOLDER >/dev/null 2>&1
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}

function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *20.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 20.04. Installation is cancelled.${NC}"
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


function copy_spectresecurity_binaries(){
  cd /root
  apt-get install build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libgmp-dev libevent-dev libboost-all-dev libsodium-dev cargo libminiupnpc-dev libnatpmp-dev libzmq3-dev -y
  wget $SPECTRESECURITY_LATEST_RELEASE
  unzip spectresecurity-5.6.1-ubuntu-20-daemon.zip
  cp spectresecurity-cli spectresecurityd spectresecurity-tx /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/spectresecurity* >/dev/null
  clear
}

function install_spectresecurity(){
  echo -e "Installing SpectreSecurity files."
  copy_spectresecurity_binaries
  clear
}


function systemd_spectresecurity() {
sleep 2
systemctl start $SPECTRESECURITY_USER.service
}


function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "SpectreSecurity Masternode Upgraded to the Latest Version{NC}"
 echo -e "Commands to Interact with the service are listed below{NC}"
 echo -e "Start: ${RED}systemctl start $SPECTRESECURITY_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $SPECTRESECURITY_USER.service${NC}"
 echo -e "Please check SpectreSecurity is running with the following command: ${GREEN}systemctl status $SPECTRESECURITY_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
	download_bootstrap
	systemd_spectresecurity
	important_information
}


##### Main #####
clear
purgeOldInstallation
checks
install_spectresecurity


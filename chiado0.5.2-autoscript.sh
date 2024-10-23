#!/bin/bash
LOG_FILE="/var/log/warden_node_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

printGreen() {
    echo -e "\033[32m$1\033[0m"
}

printLine() {
    echo "------------------------------"
}

# Function to print the node logo
function printNodeLogo {
    echo -e "\033[32m"
    echo "          
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
---------------------------------------------    ---------------------------------------------------
-------------------------------------      -       -     -------------------------------------------
--------------------------------          -  ----  -           -------------------------------------
-----------------------------      ---------       ---------      ----------------------------------
--------------------------     ------- -  ----   ----  - -------     -------------------------------
------------------------    ---- ----  ---  -------  ---  --------     -----------------------------
----------------------    ------ ----  -----  ---  ----- ------------    ---------------------------
--------------------    --         --  ------     ------  -------------    -------------------------
--------------------------------  -----------    ---------------------------------------------------
----------------------------------------------------------------------------------------------------
----------               -------           --------                ------                  ---------
-------                  ----                ------                  ----                  ---------
------     ---------     ---     --------     -----    ----------     ---    -----------------------
------   ------------------    ------------    ----    -----------    ---    -----------------------
-----    ------------------    ------------    ----                  ----               ------------
-----    ------------------    ------------    ----                ------               ------------
------    -----------    ---    ----------    -----    ---------     ----    -----------------------
-------     ------      -----     ------     ------    ----------    ----    ------------- ---------
---------             ---------            --------    ----------    ----                  ---------
-------------    -------------------  ------      --------------------------------------------------
--------------------------------------------  ---  -------------------------------------------------
--------------------------------------------      --------------------------------------------------
-----      ----------    -------           ---- ---              --------                  ---------
-----       ---------    -----               ------                 -----                  ---------
-----         -------    ----    --------     -----    ---------     ----    -----------------------
-----    --     -----    ---    -----------    ----    -----------    ---    -----------------------
-----    ---     ----    ---   ------------    ----    -----------    ---               ------------
-----    -----     --    ---   ------------    ----    -----------    ---              -------------
-----    -------    -    ---    ----------    -----   -----------    ----    -----------------------
-----    ---------      -----      -----     ------                 -----                  ---------
-----    ----------     -------             -------               -------                  ---------
-----------------------------------     ------------------------------------------------------------
----------------------------------------------   ---------------------------------------------------
-------------------    --------- ----  ------     ------  --          --    ------------------------
---------------------   -------- ----  ------  -  ------  ---  --------   --------------------------
----------------------    ------ ----  ----  ----  -----  ---  ------    ---------------------------
------------------------     --------  ---  -------  --- ---------     -----------------------------
---------------------------     --------  ----   ----  --------     --------------------------------
-----------------------------       --------       --------       ----------------------------------
---------------------------------         -  ----  -          --------------------------------------
---------------------------------------   --  ---  -    --------------------------------------------
----------------------------------------------   ---------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
CoreNode 2024 All rights reserved."
    echo -e "\033[0m"
}

# Show the node logo
printNodeLogo

# User confirmation to proceed
echo -n "Type 'yes' to start the installation Warden Chiado v0.5.2 with Cosmovisor and press Enter: "
read user_input

if [[ "$user_input" != "yes" ]]; then
  echo "Installation cancelled."
  exit 1
fi

# Function to print in green
printGreen() {
  echo -e "\033[32m$1\033[0m"
}

printGreen "Starting installation..."
sleep 1

printGreen "If there are any, clean up the previous installation files"

sudo systemctl stop wardend
sudo systemctl disable wardend
sudo rm -rf /etc/systemd/system/wardend.service
sudo rm $(which wardend)
sudo rm -rf $HOME/.warden
sed -i "/WARDEN_/d" $HOME/.bash_profile

# Update packages and install dependencies
printGreen "1. Updating and installing dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

# User inputs
read -p "Enter your MONIKER: " MONIKER
echo 'export MONIKER='$MONIKER
read -p "Enter your PORT (2-digit): " PORT
echo 'export PORT='$PORT

# Setting environment variables
echo "export MONIKER=$MONIKER" >> $HOME/.bash_profile
echo "export WARDEN_CHAIN_ID=\"chiado_10010-1\"" >> $HOME/.bash_profile
echo "export WARDEN_PORT=$PORT" >> $HOME/.bash_profile
source $HOME/.bash_profile

printLine
echo -e "Moniker:        \e[1m\e[32m$MONIKER\e[0m"
echo -e "Chain ID:       \e[1m\e[32m$WARDEN_CHAIN_ID\e[0m"
echo -e "Node custom port:  \e[1m\e[32m$WARDEN_PORT\e[0m"
printLine
sleep 1

# Install Go
printGreen "2. Installing Go..." && sleep 1
cd $HOME
VER="1.23.0"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=\$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

# Version check
echo $(go version) && sleep 1

# Download Warden protocol binary
printGreen "3. Downloading Warden binary and setting up..." && sleep 1
cd $HOME
rm -rf bin
mkdir -p $HOME/.warden/cosmovisor/genesis/bin/
mkdir bin && cd bin
wget https://github.com/warden-protocol/wardenprotocol/releases/download/v0.5.2/wardend_Linux_x86_64.zip
unzip wardend_Linux_x86_64.zip
chmod +x wardend
cd $HOME
mv $HOME/bin/wardend $HOME/.warden/cosmovisor/genesis/bin/

# Create symlinks
printGreen "3. Creating symlinks..." && sleep 1
sudo ln -s $HOME/.warden/cosmovisor/genesis $HOME/.warden/cosmovisor/current -f
sudo ln -s $HOME/.warden/cosmovisor/current/bin/wardend /usr/local/bin/wardend -f

# Installi Cosmovisor
printGreen "3. Installing Cosmovisor..." && sleep 1
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0

# Create service file
printGreen "4. Creating service file..." && sleep 1
sudo tee /etc/systemd/system/wardend.service > /dev/null << EOF
[Unit]
Description=warden node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.warden"
Environment="DAEMON_NAME=wardend"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$HOME/.warden/cosmovisor/current/bin"

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo systemctl daemon-reload
sudo systemctl enable wardend

# Initialize the node
printGreen "5. Initializing the node..."
wardend config set client chain-id ${WARDEN_CHAIN_ID}
wardend config set client keyring-backend test
wardend config set client node tcp://localhost:${WARDEN_PORT}657
wardend init ${MONIKER} --chain-id ${WARDEN_CHAIN_ID}

# Download genesis and addrbook files
printGreen "6. Downloading genesis and addrbook..."
curl -Ls https://raw.githubusercontent.com/hazennetworksolutions/warden-chiado/refs/heads/main/genesis.json > $HOME/.warden/config/genesis.json
wget -O $HOME/.warden/config/addrbook.json "https://raw.githubusercontent.com/hazennetworksolutions/warden-chiado/refs/heads/main/addrbook.json"

# Configure gas prices and ports
printGreen "7. Configuring custom ports and gas prices..." && sleep 1
sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"250000000000000award\"/;" ~/.warden/config/app.toml
sed -i.bak -e "s%:1317%:${WARDEN_PORT}317%g; s%:8080%:${WARDEN_PORT}080%g; s%:9090%:${WARDEN_PORT}090%g; s%:9091%:${WARDEN_PORT}091%g; s%:8545%:${WARDEN_PORT}545%g; s%:8546%:${WARDEN_PORT}546%g; s%:6065%:${WARDEN_PORT}065%g" $HOME/.warden/config/app.toml

# Configure P2P and ports
sed -i.bak -e "s%:26658%:${WARDEN_PORT}658%g; s%:26657%:${WARDEN_PORT}657%g; s%:6060%:${WARDEN_PORT}060%g; s%:26656%:${WARDEN_PORT}656%g; s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${WARDEN_PORT}656\"%" $HOME/.warden/config/config.toml

# Set up seeds and peers
printGreen "8. Setting up peers and seeds..." && sleep 1
SEEDS="8288657cb2ba075f600911685670517d18f54f3b@warden-testnet-seed.itrocket.net:18656"
PEERS="b14f35c07c1b2e58c4a1c1727c89a5933739eeea@warden-testnet-peer.itrocket.net:18656,5461e7642520a1f8427ffaa57f9d39cf345fcd47@54.72.190.0:26656,2d2c7af1c2d28408f437aef3d034087f40b85401@52.51.132.79:26656"
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" $HOME/.warden/config/config.toml
sed -i.bak -e "s/^seeds = \"\"/seeds = \"$SEEDS\"/" $HOME/.warden/config/config.toml
sed -i.bak -e "s/^persistent_peers = \"\"/persistent_peers = \"$PEERS\"/" $HOME/.warden/config/config.toml

# Download the snapshot
printGreen "9. Downloading snapshot and starting node..." && sleep 1

wardend tendermint unsafe-reset-all --home $HOME/.warden --keep-addr-book
curl https://snapshots-testnet.nodejumper.io/warden/warden_latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.warden


# Start the node
printGreen "10. Starting the node..."
sudo systemctl start wardend

# Check node status
printGreen "11. Checking node status..."
sudo journalctl -u wardend -f -o cat

# Verify if the node is running
if systemctl is-active --quiet wardend; then
  echo "The node is running successfully! Logs can be found at /var/log/warden_node_install.log"
else
  echo "The node failed to start. Logs can be found at /var/log/warden_node_install.log"
fi
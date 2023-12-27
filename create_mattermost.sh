#!/bin/sh
# Shell script to setup a new Mattermost server quickly using a MySQL 8.0.x server on Debian
# For now it is mainly used to do test installs and then upgrades to newer versions.
#
# Syntax: create_matttermost.sh <mattermost.tar.gz>
#
# Developed on Debian platforms. So it works best on Debian/Ubuntu
# Copyright: Roalt Zijlstra - 2023-12-27

VERSION=0.1
INSTALL_TAR=$*

echo "Mattermost installer v${VERSION}"
echo
echo "Mattermost requires MySQL or Postgresql. PostgreSQL is the preferred databse since version Mattermost version 9.x"
echo "This installer only supports MySQL.. and Debian. PostgreSQL support will come and eventually other platforms."

if [ "${INSTALL_TAR}" == "" ]; then
        echo "Get yourself a tar file from https://docs.mattermost.com/install/install-tar.html "
        echo
        echo "For installation use: $0 <mattermost.tar.gz file>"
        exit
fi

PACKAGE_TOOL=""
if [ "$(which dpkg)" == "/usr/bin/dpkg" ]; then
        PACKAGE_TOOL="dpkg"
fi

if [ "${PACKAGE_TOOL}" == "" ]; then
        echo "Cannot find package tool like dpkg or yum"
        exit
fi

if [ "$(which wget)" == "" ]; then
        echo "The wget command is required to download packages. Please install it."
        echo "On Debian it is:"
        echo "apt install wget"
        exit
fi
# One of the gnupg tools is gnutar.. so we check on that command.
if [ "$(which gpgtar)" == "" ]; then
        echo "The gnupg command is required to download packages. Please install it."
        echo "On Debian it is:"
        echo "apt install gnupg"
        exit
fi

# Check for mysql-server installation
if [ "$(dpkg -l | grep mysql-server | wc -l)" == "0" ]; then
        read -p "No MySQL installed. Install Oracle MySQL? (y/n)" MYSQL_INSTALL
        if [ "${MYSQL_INSTALL}" == "y" ]; then
                if [ "$(dpkg -l | grep mysql-apt-config | wc -l)" == "0" ]; then
                        wget -O /var/tmp/mysql-apt-config_0.8.29-1_all.deb https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb
                        sudo dpkg -i /var/tmp/mysql-apt-config_0.8.29-1_all.deb
                        sudo apt update
                else
                        echo "Mysql Apt Config tool found."
                fi
                echo "Please follow the instructions and specify a root password"
                echo
                echo "Please choose for the weak athentication: Use Legacy Authentication Method (Retain MySQL 5.x Compatibility)  "
                echo
                sudo apt install mysql-server
        fi
else
        echo "MySQL  install found"
         mysql --version
fi
if [ -d /opt/mattermost ]; then
        echo "Mattermost install folder is already there. Please cleanup first, then do a fresh install"
        exit
fi
echo "Install Mattermost from ${INSTALL_TAR}"
echo "Create /opt"
if [ ! -d /opt ]; then
    sudo mkdir /opt
fi
echo "Unpacking archive"
sudo mkdir -p /opt/mattermost/data
sudo tar -C /opt -xzf "${INSTALL_TAR}"
echo "Create mattermost user"
sudo useradd --system --user-group mattermost

echo "Fixing ownerships"
sudo chown -R mattermost:mattermost /opt/mattermost
sudo chmod -R g+w /opt/mattermost

echo "Setting up systemd service"
sudo touch /lib/systemd/system/mattermost.service
sudo chmod 666 /lib/systemd/system/mattermost.service
sudo cat > /lib/systemd/system/mattermost.service << EOL
[Unit]
Description=Mattermost
After=network.target

[Service]
Type=notify
ExecStart=/opt/mattermost/bin/mattermost
TimeoutStartSec=3600
KillMode=mixed
Restart=always
RestartSec=10
WorkingDirectory=/opt/mattermost
User=mattermost
Group=mattermost
LimitNOFILE=49152
After=mysql.service
BindsTo=mysql.service

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload

echo "Setup default config file"
# For MySQL support we need to tweak the Database DataSource
sudo cp /opt/mattermost/config/config.json /opt/mattermost/config/config.defaults.json
sudo grep -v '"DataSource"' /opt/mattermost/config/config.defaults.json | sed 's/"postgres",/"mysql",\n    "DataSource": "MYSQLSOURCE",/' > /var/tmp/config.defaults.json
sudo cp /var/tmp/config.defaults.json /opt/mattermost/config/config.json
sudo rm /var/tmp/config.defaults.json

echo "Setup MySQL stuff"
read -p "What password for the mmuser do you want to use: " MMUSER_PASSWORD
# in mattermost config
#        "DriverName": "mysql",
#       "DataSource": "mmuser:mostest@(localhost:3306)/mattermost?charset=utf8mb4,utf8&writeTimeout=30s",
sudo sed -i "s/\"MYSQLSOURCE\"/\"mmuser:${MMUSER_PASSWORD}@(localhost:3306)\/mattermost?charset=utf8mb4,utf8\&writeTimeout=30s\"/g" /opt/mattermost/config/config.json

# in MySQL
sudo cat > /var/tmp/mm_create_user.sql << EOL
create user if not exists 'mmuser'@'%' identified by 'mmuser-password';
create database if not exists mattermost;
grant all privileges on mattermost.* to 'mmuser'@'%';
EOL
sed -i "s/mmuser-password/${MMUSER_PASSWORD}/g" /var/tmp/mm_create_user.sql


echo "We will setup an mmuser in MySQL with the specified password: '${MMUSER_PASSWORD}'"
echo "You will need to specify the root password for MySQL in order to do this."
echo
cat /var/tmp/mm_create_user.sql | mysql -u root -p

echo "Now we enable the mattermost service and start it"
sudo systemctl enable mattermost
sudo systemctl start mattermost


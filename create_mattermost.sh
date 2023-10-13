#!/bin/sh

INSTALL_TAR=$*

echo "Install Mattermost from ${INSTALL_TAR}"
echo "Create /opt"
if [ ! -d /opt ]; then
    mkdir /opt
fi
echo "Unpacking archive"
mkdir -p /opt/mattermost/data
tar -C /opt -xzf "${INSTALL_TAR}" 
echo "Create mattermost user"
useradd --system --user-group mattermost

echo "Fixing ownerships"
chown -R mattermost:mattermost /opt/mattermost
chmod -R g+w /opt/mattermost

echo "Setting up systemd service"
touch /lib/systemd/system/mattermost.service
cat > /lib/systemd/system/mattermost.service << EOL
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

echo "Setup default config file"
cp /opt/mattermost/config/config.json /opt/mattermost/config/config.defaults.json
exit
# in mattermost config
        "DriverName": "mysql",
	"DataSource": "mmuser:mostest@(localhost:3306)/mattermost?charset=utf8mb4,utf8&writeTimeout=30s",



# in MySQL
create user 'mmuser'@'%' identified by 'mmuser-password';
create database mattermost;
grant all privileges on mattermost.* to 'mmuser'@'%';


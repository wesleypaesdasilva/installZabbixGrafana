#!/bin/bash

# Version: 1.2
# Date of create: 10/10/2018
# Create by: Wesley Paes
# Description: Script for installation Zabbix-Server, Percona-Server and Grafna-Server (CentOS/RHEL/Fedora)

############# Chanding ##########
#
# Data of last change: 08/05/2020
# Changer by: Wesley Paes

# Variables
DIR_ROOT="/root"
HTTP_ZBX_FILE="/etc/httpd/conf.d/zabbix.conf"
HTTP_INDEX_ZBX="/var/www/html"
ZBX_SERVER_FILE="/etc/zabbix/zabbix_server.conf"
ZBX_AGENT_FILE="/etc/zabbix/zabbix_agentd.conf"
ZBX_CONF_PHP="/etc/zabbix/web/zabbix.conf.php"
ZBX_ISSUES="/usr/share/zabbix/include/defines.inc.php"
SECURITY_FILE="/etc/selinux/config"
GRAFANA_CONF="/etc/grafana/grafana.ini"
GRAFANA_REPO="/etc/yum.repos.d/grafana.repo"
TOMCAT_CONF="/usr/share/tomcat/conf/tomcat.conf"
FQDN=$( ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/' )

# Create Passwords
PASS_ROOT_MYSQL_LOCAL=$( openssl rand -base64 20 )
PASS_METRICS_MYSQL_EXT='2zbj091LpQeVOEsaWjPlgnRYWVA='
PASS_ZABBIX_MYSQL=$( openssl rand -base64 20 )

# Functions
update-system()
{

		echo " "
		echo "########## Update Operational System... ##########"
		echo " "

			# Update System
			yum -t -y -e 0 update

		echo " "
		echo "########## Done! ##########"
		echo " "

}

install_other_packets()
{
		echo "########## Install Repo EPEL... ##########"
		echo " "

			# Install Repo Epel
			yum -t -y -e 0 install epel-release

			# Clean Libs Repo
			yum clean all

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "########## Install Other Packeges... ##########"
		echo " "

			# Install Others Packages Necessary of System
			yum -t -y -e 0 install vim net-tools nc htop glances lsof wget yum-utils unzip net-snmp-utils ntp net-snmp telnet iotop traceroute bind-utils nmap tomcat tomcat-webapps tomcat-admin-webapps inxi screen
	
		echo " "
		echo "########## Done! ##########"
		echo " "

}

change_security_files()
{
		echo "########## Alter Mode Operation Selinux... ##########"
		echo " "
		echo "########## Check Mode Selinux... ##########"

			# Check Status Selinux
			getenforce

		echo " "

			# Alter Mode Selinux Config
			sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" $SECURITY_FILE

		echo "########## Alter Mode Selinux... ##########"
		echo " "

			# Alter Status Selinux Enforcing > Permissive
			setenforce 0

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "########## Stoping and Disabled Firewalld... ##########"
		echo " "

			# Alter Status Firewalld
			systemctl stop firewalld 

			# Disabled Firewalld
			systemctl disable firewalld

		echo " "
		echo "########## Done! ##########"
		echo " "
		
}

install_apache()
{
	
		echo " "
		echo "######### Install Apache Server #########"
		echo " "

			# Install Apache and Apache Tools
			yum -t -y -e 0 install httpd httpd-tools

		echo " "
		echo "######### Done! #########"
		echo " "

}

install_sgbd()
{
	
		echo "########## Install Percona-Server (MySQL)... ##########"
		echo " "

			# Install Repo Percona-Server
			yum -t -y -e 0 install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm mytop

            # Install Percona-Server
            yum -t -y -e 0 install Percona-Server-server-57.x86_64

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "########## Starting Percona-Server (MySQL)... ##########"
		echo " "

			# Starting Service Percona-Server (MySQL)
			systemctl start mysqld

			# Enable Starting Automatic Service Percona-Server (MySQL)
			systemctl enable mysqld

		echo " "
		echo "########## Done! ##########"
		echo " "

}

config_access_sgbd()
{

TEMP_PASS_MYSQL=$( cat /var/log/mysqld.log | grep "A temporary password is generated for" | tail -1 | sed -n 's/.*root@localhost: //p' )

		echo " "
		echo "########### Seting New Password for User Root and Zabbix in MySQL... ###########"
		echo ""

		echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '$PASS_ROOT_MYSQL_LOCAL';FLUSH PRIVILEGES;"
		echo " "

			# Seting New Password root Localhost
			mysql -uroot -p$TEMP_PASS_MYSQL -Bse "ALTER USER 'root'@'localhost' IDENTIFIED BY '$PASS_ROOT_MYSQL_LOCAL';FLUSH PRIVILEGES;" --connect-expired-password

		echo " "
		echo "CREATE USER 'metrics'@'%' IDENTIFIED BY '$PASS_METRICS_MYSQL_EXT';"
		echo " "

			# Create User Metrics 
			mysql -uroot -p$PASS_ROOT_MYSQL_LOCAL -e "CREATE USER 'metrics'@'%' IDENTIFIED BY '$PASS_METRICS_MYSQL_EXT';"

			# Seting Permission User Metrics External
			mysql -uroot -p$PASS_ROOT_MYSQL_LOCAL -e "GRANT SELECT ON zabbix.* TO 'metrics'@'%';"
		
			# Flush Privileges
			mysql -uroot -p$PASS_ROOT_MYSQL_LOCAL -e "FLUSH PRIVILEGES;"

		echo "########## Create Database Zabbix... ##########"
		echo " "

		echo " "
		echo "CREATE DATABASE zabbix CHARACTER SET utf8 COLLATE utf8_bin;"
		echo " "

			# Create Database Zabbix 
			mysql -uroot -p$PASS_ROOT_MYSQL_LOCAL -e "CREATE DATABASE zabbix CHARACTER SET utf8 COLLATE utf8_bin;"

		echo " "
		echo "########## Check Databases... ##########"
		echo " "

			# Check Databases in MySQL
			mysql -uroot -p$PASS_ROOT_MYSQL_LOCAL -e "SHOW DATABASES;"

			sleep 3

		echo " "
		echo "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost' IDENTIFIED BY '$PASS_ZABBIX_MYSQL';"
		echo " "	

			# Seting Password Zabbix User
			mysql -uroot -p$PASS_ROOT_MYSQL_LOCAL -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost' IDENTIFIED BY '$PASS_ZABBIX_MYSQL';"
			
			# Flush Privileges Database
			mysql -uroot -p$PASS_ROOT_MYSQL_LOCAL -e "FLUSH PRIVILEGES;"

		echo "########## Create file $DIR_ROOT/.my.cnf ##########"
		echo " "

		# Create File .my.cnf
		echo "[client]
host='localhost'
user='root'
password='$PASS_ROOT_MYSQL_LOCAL'" > $DIR_ROOT/.my.cnf

		echo " "
		echo "########## Password Access for MySQL... ##########"
		echo " "

			echo "Access for MySQL - Zabbix Server"
			echo " "

			echo "Password for root localhost: $PASS_ROOT_MYSQL_LOCAL"
			echo " "
			echo "Password for zabbix localhost: $PASS_ZABBIX_MYSQL"

			sleep 7

		echo "########## Done! ##########"
		echo " "

}

install_zabbix_server()
{

		echo "########## Install Zabbix-Server... ##########"
		echo " "

			# Import Zabbix Repo
			rpm -ivh http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-2.el7.noarch.rpm 

		echo " "			

			# Install Zabbix Server, Agent, Get and Sender
			yum -t -y -e 0 install zabbix-server-mysql zabbix-web-mysql zabbix-java-gateway zabbix-get zabbix-agent zabbix-sender

		echo " "
		echo "########## Done! ##########"
		echo " "

}

import_zabbix_sql()
{

		echo "########## Create Database Struct for zabbix Database... ##########"
		echo " "

			# Create Struct Database Zabbix
			zcat -v /usr/share/doc/zabbix-server-mysql-*/create.sql.gz | mysql -uroot -p$PASS_ROOT_MYSQL_LOCAL zabbix

		echo " "			
		echo "########## Check Tables in zabbix Database... ########## "
		echo " "

		echo "USER zabbix and SHOW TABLES"
		echo " "

			# Check Tables Zabbix Database
			mysql -uroot -p$PASS_ROOT_MYSQL_LOCAL -e "USE zabbix;SHOW TABLES;"

			sleep 5

		echo " "
		echo "########## Done! ##########"
		echo " "

}

config_zabbix_file()
{

		echo "########## Seting TimeZone Zabbix-Server in $HTTP_ZBX_FILE... ##########"
		echo " "

			# Seting TimeZone Zabbix-Server
			sed -i "s/# php_value date.timezone Europe\/Riga/php_value date.timezone America\/Sao_paulo/g" $HTTP_ZBX_FILE
		
		echo " "
		echo "########## Done! ##########"
		echo " "

 		echo " "			
		echo "########## Seting parameters in Zabbix-Agent file $ZBX_AGENT_FILE... ##########"
		echo " "

			# Enable Remote Commands
			sed -i "s/# EnableRemoteCommands=0/EnableRemoteCommands=1/g" $ZBX_AGENT_FILE

			# Enable Logs Remote Commands
			sed -i "s/# LogRemoteCommands=0/LogRemoteCommands=1/g" $ZBX_AGENT_FILE

			# Seting Hostname Zabbix
			sed -i "s/Hostname=Zabbix server/# Hostname=Zabbix server/g" $ZBX_AGENT_FILE

			# Seting Hostname system
			sed -i "s/# HostnameItem=system.hostname/HostnameItem=system.hostname/g" $ZBX_AGENT_FILE
			
			# Seting Active Agent
			sed -i "s/# HostMetadataItem=/HostMetadataItem=system.uname/g" $ZBX_AGENT_FILE

		echo " "
		echo "########## Done! ##########"
		echo " "

 		echo " "			
		echo "########## Seting Parameters in Zabbix-Server file $ZBX_SERVER_FILE... ##########"
		echo " "

			# Seting Password for Zabbix User
			sed -i "s/# DBPassword=/DBPassword=$PASS_ZABBIX_MYSQL/g" $ZBX_SERVER_FILE

		echo " "
		echo "########## Done! ##########"
		echo " "

}

set_zabbix_name()
{

		echo "########## Seting Name for Zabbix-Server... ##########"
		echo " "

		# Seting Name for Zabbix-Server
		echo -n "Enter with name of Zabbix-Server: "
				read ZBXSERVERNAME

		echo "<?php
// Zabbix GUI configuration file.
global \$DB;

\$DB['TYPE']     = 'MYSQL';
\$DB['SERVER']   = '127.0.0.1';
\$DB['PORT']     = '0';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER']     = 'zabbix';
\$DB['PASSWORD'] = '$PASS_ZABBIX_MYSQL';
			  
// Schema name. Used for IBM DB2 and PostgreSQL.
\$DB['SCHEMA'] = '';
			  
\$ZBX_SERVER      = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = '$ZBXSERVERNAME';
			  
\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;" > $ZBX_CONF_PHP

		echo " "
		echo "########## Done! ##########"
		echo " "


		echo " "
		echo "########## Create file index.php for Zabbix redirect... ##########"
		echo " "

		echo "<?php header ( "Location: http://$FQDN/zabbix" );?> > $HTTP_INDEX_ZBX/index.php"
		echo " "

		# Create File index.php for Redirect /zabbix
		echo "<?php header ( \"Location: http://$FQDN/zabbix\" );?>" > $HTTP_INDEX_ZBX/index.php

		echo "########## Warning in case of external publishing on the Zabbix server change the index.php file by adding the DNS instead of the IP !!! ##########"
		echo " "
		echo "########## The index.php file is located in $HTTP_INDEX_ZBX/index.php ##########"
			
		echo " "
		echo "########## Done! ##########"
		echo " "

}

config_tomcat()
{

    echo " "
    echo "########## Configuration JAVA Setings in $TOMCAT_CONF... ##########"
    echo " "

        echo '"JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true -Xmx512m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC"' >> $TOMCAT_CONF
    
    echo " "
    echo "########## Done! ##########"
    echo " "

} 

install_grafana_server()
{
    
	echo "########## Install Grafana-Server... ##########"
	echo " "

		# Create New Repository for Grafana-Server
		echo '[grafana]
name=grafana
baseurl=https://packagecloud.io/grafana/stable/el/7/$basearch
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packagecloud.io/gpg.key https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt' > $GRAFANA_REPO

			# Clean Libs repo
			yum clean all

			# Install Grafana-Server
			yum -t -y -e 0 install grafana
			
		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "########## Install Plugins Grafana-Server... ##########"
			
			# Install Plugins Grafana-Server
			grafana-cli plugins install alexanderzobnin-zabbix-app 
			grafana-cli plugins install grafana-clock-panel 
			grafana-cli plugins install grafana-piechart-panel 
			grafana-cli plugins install jdbranham-diagram-panel 
			grafana-cli plugins install vonage-status-panel
		
		echo " "
		echo "########## Disable sign users in $GRAFANA_CONF... ##########"
		echo " "

			# Disable Sign Users Grafana-Server
			sed -i "s/;allow_sign_up = true/allow_sign_up = false/g" $GRAFANA_CONF

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "########## Staring Grafana-Server... ##########"				
		echo " "

			# Start Service Grafana-Server
			systemctl start grafana-server
			
			# Enable Starting Boot Grafana-Server
			systemctl enable grafana-server

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "######### Check Status of Grafana-Server... #########"
		echo " "

			# Check Status Service Grafana-Server
			systemctl status grafana-server -ll

		echo " "
		echo "########## Done! ##########"

}

start_services()
{

		echo "######### Start Apache Server... #########"
		echo " "

			# Start Service Apache
			systemctl start httpd

		echo " " 
		echo "######### Configuration Auto Start Service on Apache... #########"
		echo " "

			# Enable Start Service Apache on Boot 
			systemctl enable httpd

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "######### Check Status of Apache Server... #########"

			# Check Status Service Apache 
			systemctl status httpd -ll

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "######### Start Zabbix Server... #########"
		echo " "

			# Start Service Zabbix-Sever
			systemctl start zabbix-server

		echo " " 
		echo "######### Configuration Auto Start Service on Zabbix-Server... #########"
		echo " "

			# Enable Service Zabbix-Server on Boot
			systemctl enable zabbix-server

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "######### Check Status of Zabbix Server... #########"
		echo " "  

			# Check Status Zabbix-Server
			systemctl status zabbix-server -ll

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo "######### Start Zabbix Agent... #########"
		echo " "

			# Start Service Zabbix-Agent
			systemctl start zabbix-agent

		echo " " 
		echo "######### Configuration Auto Start Service on Zabbix-Agent... #########"
		echo " "

			# Enable Service Zabbix-Agent on Boot
			systemctl enable zabbix-agent

		echo " "
		echo "######### Check Status of Zabbix Agent... #########"
		echo " "

			# Check Status Service Zabbix-Agent
			systemctl status zabbix-agent -ll

		echo "######### Start Tomcat... #########"
		echo " "

			# Start Service Tomcat
			systemctl start tomcat

		echo " " 
		echo "######### Configuration Auto Start Service on Tomcat... #########"
		echo " "

			# Enable Service Tomcat on Boot
			systemctl enable tomcat

		echo " "
		echo "######### Check Status of Tomcat... #########"
		echo " "

			# Check Status Service Tomcat
			systemctl status tomcat -ll

		echo " "
		echo "########## Done! ##########"
		echo " "

		echo " "
		echo "######### Configuration Localtime America/Sao_Paulo... #########"
		echo " "

			# Set Localtime America/Sao_Paulo
			timedatectl set-timezone America/Sao_Paulo

		echo "######### Start NTPD... #########"
		echo " "

			# Start Service NTPD
			systemctl start ntpd

		echo " " 
		echo "######### Configuration Auto Start Service on NTPD... #########"
		echo " "

			# Enable Service NTPD on Boot
			systemctl enable ntpd

		echo " "
		echo "######### Check Status of NTPD... #########"
		echo " "

			# Check Status Service Zabbix-Agent
			systemctl status ntpd -ll

		echo " "
		echo "########## Done! ##########"
		echo " "

}

monitor() 
{

           	update-system
			install_other_packets
			change_security_files
			install_apache
			install_sgbd
			config_access_sgbd
			install_zabbix_server
			import_zabbix_sql
			config_zabbix_file
			set_zabbix_name
			config_tomcat
			install_grafana_server
			start_services

}

main()
{

	monitor

}

# Call Main
main

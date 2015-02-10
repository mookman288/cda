#!/bin/bash
# Copyright 2010-2014 PxO Ink. All Rights Reserved.
# Create/Delete/Append Script
# This script creates, deletes or appends based upon input.
#
# This script supports:
#	* Linux Accounts - CDA
#	* Webalizer - C
#	* Apache Virtual Hosts - C
#	* domain.tld - CD
#	* sub.domain.tld - CD
#	* Exim4 - C
#	* IMAP Port 465 TLS - C
#	* SMTP mail.domain.tld - C
#	* Squirrelmail - C
#	* Forwarding - C 
#	* postmaster@domain.tld fwd - C
#	* webmaster@domain.tld fwd
#	* administrator@domain.tld - C
#	* username@domain.tld - C
#	* MySQL - C
#	* username - C

# Declare colors
blue='\e[0;34m'
red='\e[0;31m'
purple='\e[0;35m'
lightblue='\e[1;34m'
white='\e[1;37m'
green='\e[0;32m'
reset='\e[0;37m'

# Version
VERSION='0.2.1 Alpha'

validation() { 
	echo
	echo "Checking for basic dependencies..."
	echo -e $green
	if [[ $EUID -ne 0 ]]; then
		echo -e $red "ERROR:" $reset "You must have elevated permissions to use this script!"
 	elif [[ ! `type -P apache2` ]]; then
		echo -e $red "ERROR:" $reset "Apache2 must be installed!"
		exit;
	elif [[ ! `type -p php5` ]]; then
         echo -e $red "ERROR:" $reset "PHP5 must be installed!"
         exit;
	elif [[ ! `type -p mysql` ]]; then
         echo -e $red "ERROR:" $reset "MySQL must be installed!"
         exit;
	elif [[ ! `type -p exim4` ]]; then
         echo -e $red "ERROR:" $reset "EXIM4 must be installed!"
         exit;
	elif [[ ! `type -p webalizer` ]]; then
         echo -e $red "ERROR:" $reset "webalizer must be installed!"
         exit;
	elif [[ ! -d /usr/share/squirrelmail ]]; then
		echo -e $red "ERROR:" $reset "SquirrelMail installation cannot be verified!"
		echo
	fi
}

vhost() {
	#Declare variables.
	USER=$1
	VHOST=$2
	
	#Set the directories. 
	PVHOST="/etc/apache2/sites-available/$VHOST"
	PVMAIL="/etc/apache2/sites-available/mail.$VHOST"
	VHDIR="/var/www/$VHOST"
	
	#Create the directories.
	mkdir $VHDIR
	mkdir $VHDIR/public
	mkdir $VHDIR/private
	mkdir $VHDIR/ssl
	mkdir $VHDIR/public/webalizer
	mkdir $VHDIR/private/webalizer
	
	#Set permissions.
	chown -R $USER:www-data $VHDIR
	
	#Create the error log.
	touch /var/log/apache2/error.$VHOST.log
	chown www-data:www-data /var/log/apache2/error.$VHOST.log
	
	#Create the access log.
	touch /var/log/apache2/access.$VHOST.log
	chown www-data:www-data /var/log/apache2/access.$VHOST.log
	
	#Create the domain conf file.
	echo "
<VirtualHost *:80>
	ServerName $VHOST
	ServerAlias www.$VHOST
	DocumentRoot $VHDIR/public
	ErrorLog ${APACHE_LOG_DIR}/error.$VHOST.log
	TransferLog ${APACHE_LOG_DIR}/access.$VHOST.log
</VirtualHost>

KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 60

<Directory $VHDIR/public>
	Options FollowSymLinks
	AllowOverride All
</Directory>

<IfModule mod_ssl.c>
	<VirtualHost *:443>
		ServerName $VHOST
		ServerAlias www.$VHOST
		DocumentRoot $VHDIR/public
		ErrorLog ${APACHE_LOG_DIR}/error.$VHOST.log
		TransferLog ${APACHE_LOG_DIR}/access.$VHOST.log
		SSLEngine On
		SSLCertificateFile $VHDIR/private/ssl/.crt
		SSLCertificateFile $VHDIR/private/ssl/.key
		<FilesMatch \"\.(cgi|shtml|phtml|php)$\">
			SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
			 SSLOptions +StdEnvVars
		</Directory>
		BrowserMatch \"MSIE [2-6]\" \
			nokeepalive ssl-unclean-shutdown \
		 	downgrade-1.0 force-response-1.0
		BrowserMatch \"MSIE [17-9]\" ssl-unclean-shutdown
	</VirtualHost>
</IfModule>

Include /etc/apache2/vhosts/*.$VHOST.conf" > $PVHOST.conf
	
	#Create the mail subdomain conf file.
	echo "
<VirtualHost *:80>
	ServerName mail.$VHOST
	ServerAlias www.mail.$VHOST
	DocumentRoot /usr/share/squirrelmail
	ErrorLog ${APACHE_LOG_DIR}/error.mail.$VHOST.log
	TransferLog ${APACHE_LOG_DIR}/access.mail.$VHOST.log
</VirtualHost>
	echo
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 60
	echo
<IfModule mod_ssl.c>
	<VirtualHost *:443>
		ServerName mail.$VHOST
		ServerAlias www.mail.$VHOST
		DocumentRoot /usr/share/squirrelmail
		ErrorLog ${APACHE_LOG_DIR}/error.mail.$VHOST.log
		TransferLog ${APACHE_LOG_DIR}/access.mail.$VHOST.log
		SSLEngine On
		SSLCertificateFile /var/www/mail/.crt
		SSLCertificateFile /Var/www/mail/.key
		<FilesMatch \"\.(cgi|shtml|phtml|php)$\">
			SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
			 SSLOptions +StdEnvVars
		</Directory>
		BrowserMatch \"MSIE [2-6]\" \
			nokeepalive ssl-unclean-shutdown \
		 	downgrade-1.0 force-response-1.0
		BrowserMatch \"MSIE [17-9]\" ssl-unclean-shutdown
	</VirtualHost>
</IfModule>" > $PVMAIL.conf
	
	#Enable the site.
	a2ensite $VHOST
	a2ensite mail.$VHOST
	
	#Reload apache.
	service apache2 reload
}


subvhost() {
	#Declare variables.
	USER=$1
	DOMAIN=$2
	SUB=$3
	VHOST="$SUB.$DOMAIN"
	
	#Set the directories. 
	PVHOST="/etc/apache2/sites-available/$VHOST"
	VHDIR="/var/www/$VHOST"
	
	#Set permissions.
	chown -R $USER:www-data $VHDIR
	
	#Create the directories.
	mkdir $VHDIR
	mkdir $VHDIR/public
	mkdir $VHDIR/private
	mkdir $VHDIR/ssl
	mkdir $VHDIR/public/webalizer
	mkdir $VHDIR/private/webalizer
	
	#Create the error log.
	touch /var/log/apache2/error.$VHOST.log
	chown www-data:www-data /var/log/apache2/error.$VHOST.log
	
	#Create the access log.
	touch /var/log/apache2/access.$VHOST.log
	chown www-data:www-data /var/log/apache2/access.$VHOST.log
	
	#Create the domain conf file.
	echo "
<VirtualHost *:80>
	ServerName $VHOST
	ServerAlias www.$VHOST
	DocumentRoot $VHDIR/public
	ErrorLog ${APACHE_LOG_DIR}/error.$VHOST.log
	TransferLog ${APACHE_LOG_DIR}/access.$VHOST.log
</VirtualHost>

KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 60

<Directory $VHDIR/public>
	Options FollowSymLinks
	AllowOverride All
</Directory>

<IfModule mod_ssl.c>
	<VirtualHost *:443>
		ServerName $VHOST
		ServerAlias www.$VHOST
		DocumentRoot $VHDIR/public
		ErrorLog ${APACHE_LOG_DIR}/error.$VHOST.log
		TransferLog ${APACHE_LOG_DIR}/access.$VHOST.log
		SSLEngine On
		SSLCertificateFile $VHDIR/private/ssl/.crt
		SSLCertificateFile $VHDIR/private/ssl/.key
		<FilesMatch \"\.(cgi|shtml|phtml|php)$\">
			SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
			 SSLOptions +StdEnvVars
		</Directory>
		BrowserMatch \"MSIE [2-6]\" \
			nokeepalive ssl-unclean-shutdown \
		 	downgrade-1.0 force-response-1.0
		BrowserMatch \"MSIE [17-9]\" ssl-unclean-shutdown
	</VirtualHost>
</IfModule>" > $PVHOST.conf
	
	#Enable the site.
	a2ensite $VHOST
	
	#Reload apache.
	service apache2 reload
}

webalizer() {
	#Declare variables.
	USER=$1
	VHOST=$2
	PVHOST="/etc/webalizer/$VHOST"
	
	#Output configuration file.
	echo "
	Logfile /var/log/apache2/access.$VHOST.log
	OutputDir /var/www/$VHOST/public/webalizer
	HistoryName /var/www/$VHOST/private/webalizer/$VHOST.hist
	IncrementalName /var/www/$VHOST/private/webalizer/$VHOST.current
	HostName $VHOST" > $PVHOST.conf
}

mail() {
	#Declare variables.
	USER=$1
	MAILNAME=$2
	DOMAIN=$3
	PASS=$4
	
	#Output configuration file.
	echo "
	postmaster:		administrator@$DOMAIN
	webmaster:		administrator@$DOMAIN
	administrator:	$USER@localhost
	$MAILNAME:		$USER@localhost" >> /etc/exim4/virtual/$DOMAIN
	
	#Set a new mailname.
	echo "$USER@$DOMAIN" >> /etc/mailname
	
	#Set password.
	if [[ "$PASS" != "" ]]; then 
		htpasswd -nb $USER $PASS >> /etc/exim4/passwd
	fi
	
	#Update exim.
	update-exim4.conf			
}

createMail() {
	#Declare variables.
	USER=$1
	EMAIL=$2
	DOMAIN=$3
	
	#Add the email to the vhost. 
	echo "$EMAIL:	$USER@localhost" >> /etc/exim4/virtual/$DOMAIN
	
	#Set a new mailname.
	echo "$USER@$DOMAIN" >> /etc/mailname
	
	#Update exim.
	update-exim4.conf
}

mailForward() {
	#Declare variables.
	USER=$1
	DOMAIN=$2
	FORWARD=$3
	
	#Add new forwarding address.
	echo "$USER:	$FORWARD" >> /etc/exim4/virtual/$DOMAIN
	
	#Add the mailname. 
	echo "$USER@$DOMAIN" >> /etc/mailname
	
	#Update exim.
	update-exim4.conf
}

phpsql() {
	USER=$1
	MYSQLUSER="${USER}.write"
	MYSQLUSERREAD="${USER}.read"
	stty -echo
	read -p "MySQL Write Password? " RWXPASS
	echo
	read -p "MySQL Read Password? " READPASS
	echo
	stty echo	
	mysql -u root -p -e "
	CREATE USER '${MYSQLUSER}'@'localhost' IDENTIFIED BY '${RWXPASS}';
	CREATE USER '${MYSQLUSERREAD}'@'localhost' IDENTIFIED BY '${READPASS}';
	GRANT ALL PRIVILEGES ON *.* TO '${MYSQLUSER}'@'localhost';
	GRANT SELECT ON *.* TO '${MYSQLUSERREAD}'@'localhost';"
	echo
}

validation
echo -e $lightblue ":::: Create/Delete/Append Script" $VERSION
echo -e $blue ":::: Created By: PxO Ink"
echo -e $reset 
 
if [ "$1" == "" ]; then
	echo "Please enter the following code to begin:"
	echo
	echo -e $lightblue "create" $reset "			Create a New User with Domain"
	echo -e $lightblue "delete" $reset "			Delete an Existing User"
	echo -e $lightblue "append" $reset "			Append/Modify an Existing User"
	read -p "Code: " CODE
else 
	echo -e $red "ERROR: " $reset "You must select a code!"
	CODE=$1	
fi

cd /

case $CODE in
	create)
		echo "Please input the following information:"
		echo 	
		read -p "Username: " USERNAME 
		read -p "Domain/Hostname: " DOMAIN
		read -p "Personal Email Handle: " EMAIL
		stty -echo
		read -p "Universal Email Password: " PASSWD
		stty echo
		if [[ "$USERNAME" != "" && "$DOMAIN" != "" && "$EMAIL" != "" && "$PASSWD" != "" ]]; then
			echo "Creating: $USERNAME at $DOMAIN"
			adduser --force-badname $USERNAME 
			usermod -a -G www-data $USERNAME
			phpsql $USERNAME
			vhost $USERNAME $DOMAIN
			webalizer $USERNAME $DOMAIN
			mail $USERNAME $EMAIL $DOMAIN $PASSWD
		else
			echo -e $red "ERROR: " $reset "You must input all requested information!"
			exit; 
		fi		
	;;
	delete)
		echo -e $red "WARNING: " $reset "This will delete a user account!"
		echo -e $red "WARNING: " $reset "All domains and emails will remain until removed!"
		echo -e $reset 
		echo "Please input the following information:"
		echo 
		read -p "Username: " USERNAME
		if [ "$USERNAME" != "" ]; then
			echo "Deleting: $USERNAME"
			userdel --remove $USERNAME		
		else 
			echo -e $red "ERROR: " $reset "You must include a username to delete!"
			exit;
		fi
	;;
	append)
		echo "Please input the following code:"
		echo
		echo -e $lightblue "domain" $reset "		Modify Domains"
		echo -e $lightblue "email" $reset "			Modify Email"
		read -p "Code: " APPEND
		case $APPEND in
			domain)
				echo "Please input the following code:"
				echo -e $lightblue "add" $reset "                       Add a Domain Name"
				echo -e $lightblue "sub" $reset "	                    Add a Sub Domain Name"
				echo -e $lightblue "del" $reset "                       Delete a Domain Name"
				read -p "Code: " ADOMAIN
				case $ADOMAIN in
					add)
						echo "Please input the following information:"
						echo
						read -p "Username: " USER
						read -p "Domain: " DOMAIN
						read -p "Personal Email Handle: " EMAIL		
						if [[ "$USER" != "" && "$DOMAIN" != "" && "$EMAIL" != "" ]]; then
							PASSWD=""
							echo "Appending $DOMAIN to $USER"
							vhost $USER $DOMAIN
							webalizer $USER $DOMAIN
							mail $USER $EMAIL $DOMAIN $PASSWD
						else
							echo -e $red "ERROR: " $reset "You must input all requested information!"
							exit;
						fi
					;;
					sub)
						echo "Please input the following information:"
						echo
						read -p "Username: " USER
						read -p "Domain: " DOMAIN
						read -p "Sub Domain: " SUB
						if [[ "$USER" != "" && "$DOMAIN" != "" && "$SUB" != "" ]]; then
							echo "Appending $SUB to $DOMAIN"
							subvhost $USER $DOMAIN $SUB
							webalizer $USER "$SUB.$DOMAIN"
						else 
							echo -e $red "ERROR: " $reset "You must input all requested information!"
							exit;
						fi
					;;
					del)
						echo "Please input the following information:"
						echo
						read -p "Username: " USER
						read -p "Domain: " DOMAIN
						if [ "$DOMAIN" != "" ]; then
							echo "Deleting: $DOMAIN"
							rm /var/log/apache2/error.$DOMAIN.log
							rm /var/log/apache2/access.$DOMAIN.log
							rm /etc/apache2/vhosts/$DOMAIN.conf
							rm /etc/apache2/vhosts/mail.$DOMAIN.conf
							rm /etc/webalizer/$DOMAIN.conf
							rm /etc/webalizer/mail.$DOMAIN.conf
							rm -r /home/$USER/html/$DOMAIN
							echo -e $red "WARNING: " $reset "Email accounts still active!"
						else
							echo -e $red "ERROR: " $reset "You must input all requested information!"
							exit;
						fi
					;;
				esac 
			;;
			email)
				echo "Please input the following code:"
				echo -e $lightblue "add" $reset "			Add an Email Address"
				echo -e $lightblue "fwd" $reset "			Add Forwarding Address"
				read -p "Code: " AEMAIL
				case $AEMAIL in
					add)
						echo "Please input the following information:"
						echo
						read -p "Username: " USER
						read -p "Email Account: " EMAIL
						read -p "Domain: " DOMAIN
						if [[ "$USER" != "" && "$EMAIL" != "" && "$DOMAIN" != "" ]]; then						
							createMail $USER $EMAIL $DOMAIN
						else
							echo -e $red "ERROR: " $reset "You must input all requested information!"
							exit;
						fi
					;;
					fwd)
						echo "Please input the following information:"
						echo
						read -p "Email Handle: " EMAIL
						read -p "Domain: " DOMAIN
						read -p "Forwarding Address: " FORWARD
						if [[ "$EMAIL" != "" && "$DOMAIN" != "" && "$FORWARD" != "" ]]; then
							mailForward $EMAIL $DOMAIN $FORWARD
						else
							echo -e $red "ERROR: " $reset "You must input all requested information!"
							exit;
						fi
					;;
				esac
			;;
		esac 
	;;
esac
apache2ctl -k graceful
/etc/init.d/exim4 restart
cd ~
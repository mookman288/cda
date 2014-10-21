#!/bin/bash
# Copyright 2010-2014 PxO Ink. All Rights Reserved.
# Create/Delete/Append Script
# This script creates, deletes or appends based upon input.
#
# This script supports:
#	* Linux Accounts - COMPLETE - CDA
#	* Webalizer - COMPLETE
#	* Apache Virtual Hosts - COMPLETE :: 2.4 w/ Self-Signed Certificate
#	* domain.tld - COMPLETE - CD
#	* sub.domain.tld - COMPLETE - CD
#	* Exim4 - COMPLETE
#	* IMAP Port 465 TLS - COMPLETE
#	* SMTP mail.domain.tld - COMPLETE
#	* Squirrelmail - COMPLETE
#	* Forwarding - COMPLETE 
#	* postmaster@domain.tld - COMPLETE - C
#		-forwarded to-
#	* administrator@domain.tld - COMPLETE - C
#	* username@domain.tld - COMPLETE - C
#	* MySQL/PhpMyAdmin - COMPLETE
#	* username.read - COMPLETE
#	* username.write - COMPLETE
#	* ????

# Declare colors
blue='\e[0;34m'
red='\e[0;31m'
purple='\e[0;35m'
lightblue='\e[1;34m'
white='\e[1;37m'
green='\e[0;32m'
reset='\e[0;37m'

# Version
VERSION='0.1.7 Alpha'

validation() { 
	echo
	echo "Checking for basic dependencies..."
	echo -e $green
 	if ! type -P apache2 ; then
		echo -e $red "ERROR:" $reset "Apache2 must be installed!"
		exit;
	elif ! type -p php5 ; then
                 echo -e $red "ERROR:" $reset "PHP5 must be installed!"
                 exit;
	elif ! type -p mysql ; then
                 echo -e $red "ERROR:" $reset "MySQL must be installed!"
                 exit;
	elif ! type -p exim4 ; then
                 echo -e $red "ERROR:" $reset "EXIM4 must be installed!"
                 exit;
	elif ! type -p webalizer ; then
                 echo -e $red "ERROR:" $reset "webalizer must be installed!"
                 exit;
	else
		echo
		echo -e $red "WARNING:" $reset "SquirrelMail installation cannot be verified!"
		echo
	fi
}

vhost() {
	USER=$1
	VHOST=$2
	PVHOST="/etc/apache2/sites-available/$VHOST"
	PVMAIL="/etc/apache2/sites-available/mail.$VHOST"
	echo "<VirtualHost *:80>" >> $PVHOST.conf
	echo "	ServerName $VHOST" >> $PVHOST.conf
	echo "	ServerAlias www.$VHOST" >> $PVHOST.conf
	mkdir /home/$USER/html/$VHOST
	mkdir /home/$USER/html/$VHOST/public
	echo "	DocumentRoot /home/$USER/html/$VHOST/public" >> $PVHOST.conf
	mkdir /var/log/apache2/$USER
	echo "	ErrorLog /var/log/apache2/$USER/$VHOST-error.log" >> $PVHOST.conf
	echo "	TransferLog /var/log/apache2/$USER/$VHOST-access.log" >> $PVHOST.conf
	echo "</VirtualHost>" >> $PVHOST.conf
	
	echo >> $PVHOST.conf
	echo "Include /etc/apache2/vhosts/*.$VHOST.conf" >> $PVHOST.conf
	mkdir /home/$USER/html/$VHOST/files
	mkdir /home/$USER/html/$VHOST/webalizer
	ln -s /usr/share/phpmyadmin /home/$USER/html/$VHOST/phpmyadmin
	echo "<VirtualHost *:80>" > $PVMAIL.conf
	echo "	ServerName www.mail.$VHOST" >> $PVMAIL.conf
	echo "	ServerAlias mail.$VHOST" >> $PVMAIL.conf
	echo "	DocumentRoot /usr/share/squirrelmail" >> $PVMAIL.conf
	echo "	ErrorLog /var/log/apache2/$USER/mail.$VHOST-error.log" >> $PVMAIL.conf
	echo "	TransferLog /var/log/apache2/$USER/mail.$VHOST-access.log" >> $PVMAIL.conf
	echo "</VirtualHost>" >> $PVMAIL.conf 
	mkdir /home/$USER/html/mail.$VHOST
	a2ensite $VHOST
	a2ensite mail.$VHOST
}


subvhost() {
	USER=$1
	DOMAIN=$2
	SUB=$3
	VHOST="$SUB.$DOMAIN"
	PVHOST="/etc/apache2/sites-avilabile/$VHOST"
	echo "<VirtualHost *:80>" > $PVHOST.conf
	echo "  ServerName www.$VHOST" >> $PVHOST.conf
	echo "  ServerAlias $VHOST" >> $PVHOST.conf
	mkdir /home/$USER/html/$VHOST/public
	echo "  DocumentRoot /home/$USER/html/$VHOST" >> $PVHOST.conf
	echo "  ErrorLog /var/log/apache2/$USER/$VHOST-error.log" >> $PVHOST.conf
	echo "  TransferLog /var/log/apache2/$USER/$VHOST-access.log" >> $PVHOST.conf
	echo "</VirtualHost>" >> $PVHOST.conf
	a2ensite $VHOST
}

webalizer() {
	USER=$1
	VHOST=$2
	PVHOST="/etc/webalizer/$VHOST"
	echo "LogFile /var/log/apache2/$USER/$VHOST-access.log" > $PVHOST.conf
	echo "OutputDir /home/$USER/html/$VHOST/webalizer" >> $PVHOST.conf
	echo "HostName www.$VHOST" >> $PVHOST.conf
	echo "HideReferrer www.$VHOST" >> $PVHOST.conf
}

mail() {
	USER=$1
	MAILNAME=$2
	DOMAIN=$3
	PASS=$4
	echo "postmaster:	administrator@$DOMAIN" > /etc/exim4/virtual/$DOMAIN
	echo "administrator:	$USER@localhost" >> /etc/exim4/virtual/$DOMAIN
	echo "$MAILNAME:	$USER@localhost" >> /etc/exim4/virtual/$DOMAIN
	echo "$USER@$DOMAIN" >> /etc/mailname
	if [[ "$PASS" != "" ]]; then 
		htpasswd -nb $USER $PASS >> /etc/exim4/passwd
	fi
	update-exim4.conf			
}

createMail() {
	USER=$1
	EMAIL=$2
	DOMAIN=$3
	echo "$EMAIL:	$USER@localhost" >> /etc/exim4/virtual/$DOMAIN
	echo "$USER@$DOMAIN" >> /etc/mailname
	update-exim4.conf
}

mailForward() {
	USER=$1
	DOMAIN=$2
	FORWARD=$3
	echo "$USER:	$FORWARD" >> /etc/exim4/virtual/$DOMAIN
	echo "$USER@$DOMAIN" >> /etc/mailname
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
	echo -e $lightblue "create" $reset "			Create a New User"
	echo -e $lightblue "delete" $reset "			Delete an Existing User"
	echo -e $lightblue "append" $reset "			Append an Existing User"
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
		read -p "Domain/Host: " DOMAIN
		read -p "Personal Email Handle: " EMAIL
		stty -echo
		read -p "Universal Email Password: " PASSWD
		stty echo
		if [[ "$USERNAME" != "" && "$DOMAIN" != "" && "$EMAIL" != "" && "$PASSWD" != "" ]]; then
			echo "Creating: $USERNAME at $DOMAIN"
			adduser --force-badname $USERNAME 
			phpsql $USERNAME
			vhost $USERNAME $DOMAIN
			ln -s /var/log/apache2/$USER /home/$USER/log
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
		echo -e $lightblue "domain" $reset "			Modify Domains"
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
						if [[ "$USER" != "" && "$DOMAIN" != "" && "$EMAIL" != ""  ]]; then
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
							rm /var/log/apache2/$USER/$DOMAIN-error.log
							rm /var/log/apache2/$USER/$DOMAIN-access.log
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
./webalizer.sh	

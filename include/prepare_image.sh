#!/usr/bin/env sh
#
# To execute, sh prepare_image.sh 
# Note:  You will be prompted for the admin password for the ADS.

WORKING_DIR=$1
ADS_ADMIN_PASSWORD=$2

source $WORKING_DIR/prepare_image.vars

# Initialize Logging
echo "Prepare_image LOG File ..." > $WORKING_DIR/prepare_image.log

###########################
#  JOIN ACTIVE DIRECTORY  #
###########################
function setup_AD () {
	# Install AD packages
	echo "INFO: Installing samba-common ......";
	yum -y install samba-common &>> $WORKING_DIR/prepare_image.log

	# See if AD line exists in hosts file and if so update otherwise insert line
	grep -q '^'$ADS_IP'' /etc/hosts && sed -i 's/'$ADS_IP'.*/'$ADS_IP'   '$ADS_SERVER'.'$ADS_DOMAIN'   '$ADS_SERVER'/g' /etc/hosts || \
	echo ''$ADS_IP'   '$ADS_SERVER'.'$ADS_DOMAIN'   '$ADS_SERVER'' >> /etc/hosts

	# Set the SAMBA config options for Active Directory
    	# 'authconfig' will update the /etc/samba/smb.conf file
	authconfig  --update \
   	        --kickstart \
   	        --enablewinbind \
            	--enablewinbindauth \
            	--smbsecurity=ads \
            	--smbworkgroup=$ADS_WORKGROUP \
            	--smbrealm=$ADS_DOMAIN \
            	--smbservers=$ADS_SERVER \
            	--winbindtemplatehomedir=$NFS_PATH_HOME/%U \
            	--winbindtemplateshell=/bin/bash \
            	--enablewinbindusedefaultdomain \
            	--enablelocauthorize \
            	--enablemkhomedir

	# Now Restart windbind to pick up these options from smb.conf
	service winbind stop &>> $WORKING_DIR/prepare_image.log
	service winbind start &>> $WORKING_DIR/prepare_image.log

	# Now Join the Active Directory Domain
	net ads join -S $ADS_SERVER -U $ADS_ADMIN_USER%$ADS_ADMIN_PASSWORD

	echo ""
	echo "INFO: Done setting up winbind communication with Active Directory"
	echo ""
}


###########################
#  CREATE MOUNTING POINT  #
###########################
function setup_mountpoint () {
	# Install NFS packages
	echo "INFO: Installing nfs-utils nfs-utils-lib ......";
	yum -y install nfs-utils nfs-utils-lib &>> $WORKING_DIR/prepare_image.log

	# Make NFS Mounting point
	mkdir -p $LOCAL_MOUNT_HOME
	chmod 755 $LOCAL_MOUNT_HOME
	mount $NFS_SERVER:$NFS_PATH_HOME $LOCAL_MOUNT_HOME

	# Make NFS Mounting point
	mkdir -p $LOCAL_MOUNT_PROJECTS
	chmod 755 $LOCAL_MOUNT_PROJECTS
	mount $NFS_SERVER:$NFS_PATH_PROJECTS $LOCAL_MOUNT_PROJECTS

	# If line exists in fstab, update, otherwise, copy the line into the fstab file
	if grep -Fxq "$NFS_SERVER:$NFS_PATH_HOME      $LOCAL_MOUNT_HOME            nfs     defaults        0 0" /etc/fstab
	then
    	echo "INFO: Updating /etc/fstab"
    	sed '/$NFS_SERVER:$NFS_PATH_HOME      $LOCAL_MOUNT_HOME            nfs     defaults        0 0/ i '$NFS_SERVER':'$NFS_PATH_HOME'      '$LOCAL_MOUNT_HOME'  nfs    defaults        0 0' /etc/fstab  &>> $WORKING_DIR/prepare_image.log
	else
    	echo "INFO: Inserting line into /etc/fstab"
    	echo ''$NFS_SERVER':'$NFS_PATH_HOME'      '$LOCAL_MOUNT_HOME'            nfs     defaults        0 0' >> /etc/fstab
	fi

        # If line exists in fstab, update, otherwise, copy the line into the fstab file
	if grep -Fxq "$NFS_SERVER:$NFS_PATH_PROJECTS      $LOCAL_MOUNT_PROJECTS            nfs     defaults        0 0" /etc/fstab
	then
    	echo "INFO: Updating /etc/fstab"
    	sed '/$NFS_SERVER:$NFS_PATH_PROJECTS      $LOCAL_MOUNT_PROJECTS            nfs     defaults        0 0/ i '$NFS_SERVER':'$NFS_PATH_PROJECTS'      '$LOCAL_MOUNT_PROJECTS'  nfs    defaults        0 0' /etc/fstab  &>> $WORKING_DIR/prepare_image.log
	else
    	echo "INFO: Inserting line into /etc/fstab"
    	echo ''$NFS_SERVER':'$NFS_PATH_PROJECTS'      '$LOCAL_MOUNT_PROJECTS'            nfs     defaults        0 0' >> /etc/fstab
	fi
}


#########################
#  INSTALL R & RSTUDIO  #
#########################
function install_R () {
	echo ""
	echo "INFO: Install R and Rstudio ....."
	echo ""

	# Install EPEL release
	CENTOS_VERSION=$(cat /etc/issue |grep CentOS |awk '{print $3}')
	if [[ $CENTOS_VERSION =~ ^6.* ]];then
		echo "INFO: Installing epel release 6 for CentOS 6.x....";
		rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm &>> $WORKING_DIR/prepare_image.log
	elif [[ $CENTOS_VERSION =~ ^7.* ]];then
		echo "INFO: Installing epel release 7 for CentOS 7.x....";
		rpm -Uvh http://download.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm &>> $WORKING_DIR/prepare_image.log
		#yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &>> $WORKING_DIR/prepare_image.log
	else
		echo "##############################################################"
		echo "EPEL Not Installed as CentOS did not macth version 6.x or 7.x"
		echo "##############################################################"
	fi

	# Install R & RStudio packages
	echo "INFO: Installing R R-devel......";
	yum -y install R R-devel &>> $WORKING_DIR/prepare_image.log
	echo "INFO: Installing rstudio-server RPM......";
	yum -y install https://download2.rstudio.org/rstudio-server-rhel-$RSTUDIO_SERVER_VERSION-x86_64.rpm &>> $WORKING_DIR/prepare_image.log

	# Install R library requirements:
	echo "INFO: Installing following packages: gmp libcurl-devel libxml2-devel mpfr openssl-devel ......";
	yum -y install gmp libcurl-devel libxml2-devel mpfr openssl-devel &>> $WORKING_DIR/prepare_image.log

	# Configure R to work with Java properly
	R CMD javareconf &>> $WORKING_DIR/prepare_image.log

	echo "INFO: Installing a bunch of R packages ......"
	R_PACKAGES='"rJava", "RJSONIO", "rmr", "rhdfs", "rhbase", "plyrmr", "Rcpp", "digest", "functional", "reshape2", "stringr", "plyr", "caTools"'
	R_REPO="'http://cran.us.r-project.org'"
	echo "install.packages(c($R_PACKAGES), dependencies=TRUE, repos=$R_REPO)" > $WORKING_DIR/tmp_install-R-packages.R
	sudo R CMD BATCH $WORKING_DIR/tmp_install-R-packages.R &>> $WORKING_DIR/prepare_image.log

	# Download & Install R hadoop packages
	echo "INFO: Downloading 'rmr2' and 'rhdfs' packages ......"
	wget $RMR2_PACKAGE_URL -P $WORKING_DIR &>> $WORKING_DIR/prepare_image.log
	wget $RHDFS_PACKAGE_URL -P $WORKING_DIR &>> $WORKING_DIR/prepare_image.log

	echo "INFO: Installing 'rmr2' and 'rhdfs' packages ......"
	R CMD INSTALL $WORKING_DIR/$RMR2_PACKAGE_NAME &>> $WORKING_DIR/prepare_image.log

	# Set HADOOP_CMD needed for installation of 'rhdfs' package
	export HADOOP_CMD='/usr/bin/hadoop'

	R CMD INSTALL $WORKING_DIR/$RHDFS_PACKAGE_NAME &>> $WORKING_DIR/prepare_image.log

	# Enable users to log in using LDAP/AD
	cp /etc/pam.d/rstudio /etc/pam.d/rstudio.bak
	cp /etc/pam.d/login /etc/pam.d/rstudio

	echo ""
	echo "INFO: Done with 'R' installation ....."
	echo ""
}

###############################################################
# Check HDP version and set R related system variables for HDP
###############################################################
function set_R_variables () {
	echo ""
	echo "INFO: Setup R variables ...."
	echo ""
	#sudo vi /usr/lib64/R/etc/Renviron
	#sudo vi /etc/profile
	#add:
	#HADOOP_HOME='/usr/hdp/2.3.2.0-2950/hadoop'
	#HADOOP_CMD='/usr/bin/hadoop'
	#HADOOP_STREAMING='/usr/hdp/2.3.2.0-2950/hadoop-mapreduce/hadoop-streaming.jar'
	#found in /usr/hdp/
	#HDP_VERSION="ls /usr/hdp | grep '^[0-9]\W*'"
	#echo $HDP_VERSION
}

################################################################################
# Execute script at startup to join AD DOmain and update run time config options
################################################################################
function runtime_config_update () {

	# Move config_update.sh to root directory
	mv $WORKING_DIR/config_update.sh /root/.
	chmod 500 /root/config_update.sh

	# Update config_update.sh with the ADS Admin Password
	sed -i "s/<ADS_ADMIN_PASSWORD>/$ADS_ADMIN_PASSWORD/" /root/config_update.sh
	sed -i "s/<ADS_IP>/$ADS_IP/g" /root/config_update.sh
	sed -i "s/<ADS_SERVER>/$ADS_SERVER/g" /root/config_update.sh
	sed -i "s/<ADS_DOMAIN>/$ADS_DOMAIN/g" /root/config_update.sh
	
	echo "" >> /etc/rc.local
	echo "if [[ -e /root/config_update.sh ]]" >> /etc/rc.local
	echo "then" >> /etc/rc.local
  	echo "echo \"\"" >> /etc/rc.local
  	echo "echo \"Running configuration update for Rstudio and Active Directory setup\"" >> /etc/rc.local
  	echo "echo \"\"" >> /etc/rc.local
  	echo "/root/config_update.sh" >> /etc/rc.local
	echo "" >> /etc/rc.local
  	echo "# We are done. Only execute this script once and then delete it" >> /etc/rc.local
  	echo "rm -f /root/config_update.sh" >> /etc/rc.local
  	echo "# Done with Self Destruction!!!" >> /etc/rc.local
	echo "fi" >> /etc/rc.local
	echo "service winbind stop" >> /etc/rc.local
	echo "service winbind start" >> /etc/rc.local
	echo "" >> /etc/rc.local
}

function main () {
	setup_AD
	setup_mountpoint
	install_R
	set_R_variables
	runtime_config_update
}

main

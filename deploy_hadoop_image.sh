#!/bin/bash

source openrc
source vars/cluster.vars

############################################
# Create the Base Image
############################################
function create_ambari_base_image () {
	echo ""
	echo "Creating Ambari Image from qcow file Downloaded from Mirantis"
	echo ""
	# Get the official Image and Checksum
	mkdir $WORKING_DIR
	echo "Downloading qcow Image file"
	rm -f $WORKING_DIR/$HADOOP_IMAGE
	rm -f $WORKING_DIR/$HADOOP_IMAGE_MD5
	wget -P $WORKING_DIR $HADOOP_IMAGE_URL/$HADOOP_IMAGE
	wget -P $WORKING_DIR $HADOOP_IMAGE_URL/$HADOOP_IMAGE_MD5
	# Extract Checksum from the file
	CHECKSUM=`cat $WORKING_DIR/$HADOOP_IMAGE_MD5 | awk '{print $1}'`
	# Now Create the glance image
	openstack image create 	--disk-format qcow2 \
				--container-format bare \
       		                --file $WORKING_DIR/$HADOOP_IMAGE \
                                --checksum $CHECKSUM \
       		                --public \
       		                $MY_IMAGE_NAME
}

############################################
# Verify that the Image is 'active'
############################################
function verify_image () {
	echo "	-->Waiting for Image [$MY_IMAGE_NAME] to be active"
	count=0
	LIMIT=20
	while true;
	do
  		count=$(($count+1))
		IMAGE_STATUS="openstack image show $MY_IMAGE_NAME"
  		if [[ $($IMAGE_STATUS |grep status |awk '{print $4}') == "active" ]];
  		then
    			echo "Image [$MY_IMAGE_NAME] is now active"
    			break # Exit Loop and continue with script.
  		fi
  		if [ "$count" == "$LIMIT" ]
  		then
    			echo "[$MY_IMAGE_NAME] status is still [$($IMAGE_STATUS |grep status |awk '{print $4}')] and not active within the specified time."
    			echo "Exiting script...."
    			exit
  		fi
  		sleep 30
  		echo "[$MY_IMAGE_NAME] status is [$($IMAGE_STATUS |grep status |awk '{print $4}')] : Time Elapsed - $(($count*30)) Seconds"
	done
}

############################################
# Create the Base VM to be snapshotted!
############################################
function create_base_vm () {
	# Check if working directory exsists, if not then create it
	if [ ! -d "$WORKING_DIR" ]; then
	  mkdir $WORKING_DIR
	fi

	# Check if Flavor exists, if not then create it
        if [[ `openstack flavor list  |grep $IMAGE_FLAVOR |awk '{print $4}'` != $IMAGE_FLAVOR ]];
	then
	  openstack flavor create --ram 4096 --disk 5 --vcpus 4 $IMAGE_FLAVOR 
	fi
	echo "	-->Creating keypair [$KEYPAIR_NAME] and VM instance [$VM_NAME]"
	# Create Keypair
	openstack keypair create $KEYPAIR_NAME > $KEYPAIR_FILE
	chmod 600 $KEYPAIR_FILE
	NETWORK_ID=`openstack network show $NETWORK_NAME | grep " id " |awk '{print $4}'`
	openstack server create --nic net-id=$NETWORK_ID \
          	              	--flavor $IMAGE_FLAVOR \
				--key-name $KEYPAIR_NAME \
               		        --image $MY_IMAGE_NAME \
               		        $VM_NAME &> /dev/null

	echo "	-->Done Creating VM instance [$VM_NAME]"
	# Now get the VM IP
	VM_FLOATING_IP=`openstack ip floating create $EXTERNAL_NETWORK |grep " ip " |awk '{print $4}'`
	echo "	-->Waiting to assign [$VM_FLOATING_IP] to [$VM_NAME]"
	sleep 10
	openstack ip floating add $VM_FLOATING_IP $VM_NAME
	echo "	-->Done assigning floating IP to [$VM_NAME]"
	echo ""
}

##################################################
# Verify that the VM is online and can be accessed
##################################################
function verify_vm_connectivity () {
    if [ -z $VM_FLOATING_IP ];then
        VM_FLOATING_IP=$1
    fi
	echo "	-->Waiting to connect to VM at [$VM_FLOATING_IP]"
	count=0
	LIMIT=20
	while true;
	do
  		count=$(($count+1))
  		`ssh -i $KEYPAIR_FILE -q cloud-user@$VM_FLOATING_IP exit`
  		CHECK_SSH_ACCESS=`echo $?`
  		if [ $CHECK_SSH_ACCESS == 0 ];
  		then
    			echo "Successful in connecting to VM"
    			break # Exit Loop and continue with script.
  		fi
  		if [ "$count" == "$LIMIT" ]
  		then
    			echo "Failed to connect to VM within the specified time"
    			echo "Exiting script...."
    			exit
  		fi
  		sleep 30
  	echo "[$VM_FLOATING_IP] not accesssible : Time Elapsed - $(($count*30)) Seconds"
	done
}

###############################################################################
# Prepare Image with installatiion of various packages and update configuration 
###############################################################################
function update_vm () {
	echo ""
	echo "Updating VM ....."
	echo ""

	AD_ADMIN_USER_PASSWORD=$1
    if [ -z $VM_FLOATING_IP ];then
		VM_FLOATING_IP=$2
    fi
	ssh -q -i $KEYPAIR_FILE cloud-user@$VM_FLOATING_IP "mkdir $WORKING_DIR"
	scp -q -i $KEYPAIR_FILE include/prepare_image.sh cloud-user@$VM_FLOATING_IP:$WORKING_DIR/.
	scp -q -i $KEYPAIR_FILE vars/prepare_image.vars cloud-user@$VM_FLOATING_IP:$WORKING_DIR/.
	scp -q -i $KEYPAIR_FILE include/config_update.sh cloud-user@$VM_FLOATING_IP:$WORKING_DIR/. 
	ssh -q -i $KEYPAIR_FILE cloud-user@$VM_FLOATING_IP "sudo -u root $WORKING_DIR/prepare_image.sh $WORKING_DIR $AD_ADMIN_USER_PASSWORD"
	ssh -q -i $KEYPAIR_FILE cloud-user@$VM_FLOATING_IP "sudo -u root rm -f /etc/udev/rules.d/70-persistent-net.rules"
	sleep 5
	echo ""
	echo "Done with Updating VM...."
	echo ""
}

#############################################
# Take a snapshop of the Virtual Machine
#############################################
function take_vm_snapshot () {
	echo "Starting to take snapshot of [$VM_NAME] ...."
	openstack server image create --name $SNAPSHOT_IMAGE_NAME $VM_NAME
	openstack image set --public $SNAPSHOT_IMAGE_NAME
	echo "[$SNAPSHOT_IMAGE_NAME] Snapshot complete"
}

###############################################
# Verify that the snapshot is in active status
###############################################
function verify_snapshot () {
	echo "	-->Waiting for Snapshot Image [$SNAPSHOT_IMAGE_NAME] to be active"
	count=0
	LIMIT=30
	while true;
	do
  		count=$(($count+1))
		IMAGE_STATUS="openstack image show $SNAPSHOT_IMAGE_NAME"
  		if [[ $($IMAGE_STATUS |grep status |awk '{print $4}') == "active" ]];
  		then
    			echo "Image [$SNAPSHOT_IMAGE_NAME] is now active"
    			break # Exit Loop and continue with script.
  		fi
  		if [ "$count" == "$LIMIT" ]
  		then
    			echo "[$SNAPSHOT_IMAGE_NAME] status is still [$($IMAGE_STATUS |grep status |awk '{print $4}')] and not active within the specified time."
    			echo "Exiting script...."
    			exit
  		fi
  		sleep 60
  		echo "[$SNAPSHOT_IMAGE_NAME] status is [$($IMAGE_STATUS |grep status |awk '{print $4}')] : Time Elapsed - $(($count)) Minutes"
	done
}

###################################################
# Cleanup the FLoating IP, Keypair and VM instance
###################################################
function cleanup () {
    if [ -z $VM_FLOATING_IP ];then
        VM_FLOATING_IP=$1
    fi
	echo "	-->Starting Cleanup of Keypair [$KEYPAIR_NAME], VM instance [$VM_NAME] and Floating IP address [$VM_FLOATING_IP]"
	FLOATING_IP_ID=`openstack ip floating list |grep $VM_FLOATING_IP |awk '{print $2}'`
	openstack ip floating delete $FLOATING_IP_ID
	echo "Deleting Keypair $KEYPAIR_NAME"
	sleep 5
	openstack keypair delete $KEYPAIR_NAME 
	openstack server delete $VM_NAME
	rm -f $KEYPAIR_FILE
	echo "	-->Done with Cleanup"
}

#####################################
# Register the Image with Sahara
#####################################
function register_image_with_sahara () {
	SNAPSHOT_IMAGE_ID=$(openstack image show $SNAPSHOT_IMAGE_NAME |grep " id " |awk '{print $4}')
	sahara image-register --id $SNAPSHOT_IMAGE_ID --username cloud-user --description "Base Image for Ambari with Rstudio and Junyper"

	# Add the image tags to the Sahara Image
	sahara image-add-tag --id $SNAPSHOT_IMAGE_ID --tag "2.2"
	sahara image-add-tag --id $SNAPSHOT_IMAGE_ID --tag "2.3"
	sahara image-add-tag --id $SNAPSHOT_IMAGE_ID --tag "ambari"
	sahara image-add-tag --id $SNAPSHOT_IMAGE_ID --tag "r"
	sahara image-add-tag --id $SNAPSHOT_IMAGE_ID --tag "rstudio"
}

function usage() {
	echo ""
	echo "Missing paramter. Please Enter one of the following options"
	echo ""
	echo "Usage: $0 {Any of the options below}"
	echo ""
	echo "	deploy_all <Active Directory Administrator User Password>"
	echo "		- Will run all of he commands below except for create_image"
	echo "	create_image"
	echo "	verify_image"
	echo "	create_vm"
	echo "	verify_vm <VM IP Address>"
	echo "	update_vm <Active Directory Administrator User Password> <VM IP Address>"
	echo "	snapshot <VM IP Address>"
	echo "	verify_snapshot"
	echo "	register_image"
	echo "	cleanup <VM IP Address>"
	echo ""
}
function main () {
	echo ""
	echo "Welcome to Deploy Script"
	echo ""

	source openrc
	if [ -z $1 ]; then
		usage
		exit 1
        fi

    	if [ $1 == "deploy_all" ]; then
	if [ -z $2 ]; then
		echo ""
		echo "Missing Active Directory Administrator Password"
		echo ""
		usage
		exit 1
	fi
		verify_image
		create_base_vm
		verify_vm_connectivity
		update_vm $2
		take_vm_snapshot
		verify_snapshot
		register_image_with_sahara
		cleanup $2
	else
    	case $1 in
    		"create_image")
				create_ambari_base_image
				verify_image
				;;
 			"verify_image")
				verify_image
				;;
  			"create_vm")
				create_base_vm
			    verify_vm_connectivity
				;;
  			"verify_vm")
				verify_vm_connectivity $2
				;;
  			"update_vm")
   			 	update_vm $2 $3
				;;
  			"snapshot")
   			 	take_vm_snapshot
				verify_snapshot
				;;
  			"verify_snapshot")
				verify_snapshot
				;;
  			"register_image")
   			 	register_image_with_sahara
				;;
  			"cleanup")
   			 	cleanup $2
				;;
			*)
				usage
				exit 1
		esac
	fi
}

main $1 $2 $3

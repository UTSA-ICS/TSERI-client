#!/bin/bash

source openrc
source vars/cluster.vars

#######################
# Copy files to temp.
#######################
function setup () {
  mkdir $WORKING_DIR
  cp -r $TEMPLATE_DIR/*.json $WORKING_DIR/
  cp -r $TEMPLATE_DIR/$HA_MODE/*.json $WORKING_DIR/
  #############################
  # Setup Python Dependencies
  #############################
  #sudo apt-get install python-pip python-dev python-pip
  #sudo pip install python-openstackclient \
#		netifaces \
#		msgpack-python \
#		wrapt \
#		requestsexceptions \
#		appdirs \
#		simplejson
#  sudo pip install --upgrade warlock
  #############################################
  # Setup Master & Worker Node Group Template
  #############################################
  NETWORK_ID=`openstack --insecure network list | grep "$NETWORK_NAME " | awk '{print$2}'`
  FLOATING_IP_POOL_ID=`openstack --insecure network list |grep $EXTERNAL_NETWORK |awk '{print $2}'`

  # Setup the security groups and rules
  SECURITY_GROUP_IDS=""
  setup_security_group

  for i in $WORKING_DIR/*.json; do
      sed -i "s/{CLUSTER_NAME}/$CLUSTER_NAME/" $i
      sed -i "s/{TEMPLATE_NAME}/$TEMPLATE_NAME/" $i
      sed -i "s/{PLUGIN_NAME}/$PLUGIN_NAME/" $i
      sed -i "s/{HADOOP_VERSION}/$HADOOP_VERSION/" $i
      sed -i "s/{FLOATING_IP_POOL_ID}/$FLOATING_IP_POOL_ID/" $i
      sed -i "s/{AUTO_SECURITY_GROUP}/$AUTO_SECURITY_GROUP/" $i
      sed -i "s/{MASTER_CLUSTER_FLAVOR_ID}/$MASTER_CLUSTER_FLAVOR_ID/" $i
      sed -i "s/{WORKER_CLUSTER_FLAVOR_ID}/$WORKER_CLUSTER_FLAVOR_ID/" $i
      sed -i "s/{EXTERNAL_NETWORK}/$EXTERNAL_NETWORK/" $i
      sed -i "s/{KEY_PAIR_NAME}/$KEY_PAIR_NAME/" $i
      sed -i "s/{SECURITY_GROUPS}/$SECURITY_GROUP_IDS/" $i
      sed -i "s/{NETWORK_NAME}/$NETWORK_NAME/" $i
      sed -i "s/{NETWORK_ID}/$NETWORK_ID/" $i
      sed -i "s/\"{WORKER_COUNT}\"/$WORKER_COUNT/" $i
      sed -i "s/\"{MASTER_COUNT}\"/$MASTER_COUNT/" $i
  done
}

##################################
# Setup Security Groups and rules
##################################
function setup_security_group () {
  # Get Security Group IDs
  for i in $SECURITY_GROUPS; do
    SECURITY_GROUP_STATUS=`openstack --insecure security group list |grep " $i " |awk '{print $4}'`
    # Ensure Security Groups are present, if not then create them
    # https://github.com/openstack/python-openstackclient/blob/master/openstackclient/network/v2/security_group_rule.py
    if [[ -z $SECURITY_GROUP_STATUS ]]
    then
      echo "Security Group [$i] does not exits, creating it and the appropriate rules..."
      case $i in
        "nfsserver")
          openstack --insecure security group create --description "NFS Server specific security rules" nfsserver
          #Portmap                          - TCP 111   - Egress/Ingress 
          #Portmap                          - UDP 111   - Egress/Ingress 
          #NFS & Portmap                    - TCP 2049  - Egress/Ingress 
          #NFS & Portmap                    - UDP 2049  - Ingress
          openstack --insecure security group rule create --proto tcp --dst-port 111:111 nfsserver --egress
          openstack --insecure security group rule create --proto tcp --dst-port 111:111 nfsserver --ingress
          openstack --insecure security group rule create --proto udp --dst-port 111:111 nfsserver --egress
          openstack --insecure security group rule create --proto udp --dst-port 111:111 nfsserver --ingress
          openstack --insecure security group rule create --proto tcp --dst-port 2049:2049 nfsserver --egress
          openstack --insecure security group rule create --proto tcp --dst-port 2049:2049 nfsserver --ingress
          openstack --insecure security group rule create --proto udp --dst-port 2049:2049 nfsserver --ingress
          ;;
        "activedirectory")
          openstack --insecure security group create --description "Active Directory specific security rules" activedirectory
          # DNS resolution                  - TCP 53    - Ingress
          # DNS resolution                  - UDP 53    - Egress
          # Kerberos                        - TCP 88    - Egress
          # Kerberos                        - UDP 88    - Egress
          # NetBIOS Datagram Service        - TCP 139   - Egress
          # LDAP                            - TCP 389   - Egress/Ingress 
          # LDAP                            - TCP 636   - Egress/Ingress 
          # LDAP                            - UDP 389   - Egress
          # Microsoft DS                    - TCP 445   - Egress
          openstack --insecure security group rule create --proto tcp --dst-port 53:53 activedirectory --ingress 
          openstack --insecure security group rule create --proto udp --dst-port 53:53 activedirectory --egress
          openstack --insecure security group rule create --proto tcp --dst-port 88:88 activedirectory --egress
          openstack --insecure security group rule create --proto udp --dst-port 88:88 activedirectory --egress
          openstack --insecure security group rule create --proto tcp --dst-port 139:139 activedirectory --egress
          openstack --insecure security group rule create --proto tcp --dst-port 389:389 activedirectory --egress
          openstack --insecure security group rule create --proto tcp --dst-port 389:389 activedirectory --ingress
          openstack --insecure security group rule create --proto udp --dst-port 389:389 activedirectory --egress
          openstack --insecure security group rule create --proto tcp --dst-port 636:636 activedirectory --egress
          openstack --insecure security group rule create --proto tcp --dst-port 636:636 activedirectory --ingress
          openstack --insecure security group rule create --proto tcp --dst-port 445:445 activedirectory --egress
          ;;
        "rstudio")
          openstack --insecure security group create --description "RStudio specific security rules" rstudio
          # Install applications            - TCP 80    - Egress/Ingress
          # Install applications over SSL   - TCP 443   - Egress/Ingress
          # Rstudio webpage portal          - TCP 8787  - Ingress
          openstack --insecure security group rule create --proto tcp --dst-port 80:80 rstudio --egress
          openstack --insecure security group rule create --proto tcp --dst-port 80:80 rstudio --ingress
          openstack --insecure security group rule create --proto tcp --dst-port 443:443 rstudio --egress
          openstack --insecure security group rule create --proto tcp --dst-port 443:443 rstudio --ingress
          openstack --insecure security group rule create --proto tcp --dst-port 8787:8787 rstudio --ingress
          ;;
        "jupyter")
          openstack --insecure security group create --description "Jupyter specific security rules" jupyter
          # Install applications            - TCP 80    - Egress/Ingress
          # Install applications over SSL   - TCP 443   - Egress/Ingress
          openstack --insecure security group rule create --proto tcp --dst-port 80:80 jupyter --egress
          openstack --insecure security group rule create --proto tcp --dst-port 80:80 jupyter --ingress
          openstack --insecure security group rule create --proto tcp --dst-port 443:443 jupyter --egress
          openstack --insecure security group rule create --proto tcp --dst-port 443:443 jupyter --ingress
          ;;
        "hdp")
          openstack --insecure security group create --description "HDP specific security rules" hdp
          # Install applications            - TCP 80    - Egress/Ingress
          # Install applications over SSL   - TCP 443   - Egress/Ingress
          openstack --insecure security group rule create --proto tcp --dst-port 6080:6080 hdp --ingress
	  ;;
        *)
          break
      esac
      echo "Done with Security Groups and security group rules"
    fi
    SEC_ID=`openstack --insecure security group list |grep " $i " |awk '{print $2}'`
    if [[ -z $SECURITY_GROUP_IDS ]]
    then
      SECURITY_GROUP_IDS="\"$SEC_ID\""
    else
      SECURITY_GROUP_IDS="\"$SEC_ID\",$SECURITY_GROUP_IDS"
    fi
  done
  SECURITY_GROUP_IDS="[ $SECURITY_GROUP_IDS ]"
} 

################################
# Create Node Templates
################################
function create_node_templates () {
  openstack --insecure dataprocessing node group template create --json $WORKING_DIR/worker_node_template.json &> /dev/null
  echo "INFO: Worker Node Template Created"
  if [ $HA_MODE == "non-HA" ]; then
    openstack --insecure dataprocessing node group template create --json $WORKING_DIR/master_node_template.json &> /dev/null
  else
    openstack --insecure dataprocessing node group template create --json $WORKING_DIR/master1_node_template.json &> /dev/null
    openstack --insecure dataprocessing node group template create --json $WORKING_DIR/master2_node_template.json &> /dev/null
    openstack --insecure dataprocessing node group template create --json $WORKING_DIR/master3_node_template.json &> /dev/null
  fi
  echo "INFO: Master Node Template Created"
}
################################
# Setup Cluster Group Template
################################
function create_cluster_template () {
  sleep 2
  WORKER_NODE_ID=`openstack --insecure dataprocessing node group template list | grep " $TEMPLATE_NAME-worker"  | awk '{print$4}'`
  if [ $HA_MODE == "non-HA" ]; then
    MASTER_NODE_ID=`openstack --insecure dataprocessing node group template list | grep " $TEMPLATE_NAME-master "  | awk '{print$4}'`
  else
    MASTER1_NODE_ID=`openstack --insecure dataprocessing node group template list | grep " $TEMPLATE_NAME-master1"  | awk '{print$4}'`
    MASTER2_NODE_ID=`openstack --insecure dataprocessing node group template list | grep " $TEMPLATE_NAME-master2"  | awk '{print$4}'`
    MASTER3_NODE_ID=`openstack --insecure dataprocessing node group template list | grep " $TEMPLATE_NAME-master3"  | awk '{print$4}'`
  fi
  echo "Worker Node ID: [$WORKER_NODE_ID]"
  if [ $HA_MODE == "non-HA" ]; then
    echo "Master Node ID: [$MASTER_NODE_ID]"
  else
    echo "Master Node ID: [$MASTER1_NODE_ID]"
    echo "Master Node ID: [$MASTER2_NODE_ID]"
    echo "Master Node ID: [$MASTER3_NODE_ID]"
  fi

  for i in $WORKING_DIR/*.json; do
      sed -i "s/{WORKER_NODE_ID}/$WORKER_NODE_ID/" $i
      if [ $HA_MODE == "non-HA" ]; then
        sed -i "s/{MASTER_NODE_ID}/$MASTER_NODE_ID/" $i
      else
        sed -i "s/{MASTER1_NODE_ID}/$MASTER1_NODE_ID/" $i
        sed -i "s/{MASTER2_NODE_ID}/$MASTER2_NODE_ID/" $i
        sed -i "s/{MASTER3_NODE_ID}/$MASTER3_NODE_ID/" $i
      fi
  done

  openstack --insecure dataprocessing cluster template create --json $WORKING_DIR/cluster_template.json
  echo "INFO: Cluster Group Template Created"
}

##################
# Deploy cluster
##################
function deploy_cluster () {
  sleep 2
  CLUSTER_TEMPLATE_ID=`openstack --insecure dataprocessing cluster template list |grep " $TEMPLATE_NAME-$HA_MODE-cluster" | awk '{print $4}'`
  echo "INFO: Creating keypair [$CLUSTER_KEYPAIR]"
  # Create Keypair
  openstack --insecure keypair create $CLUSTER_KEYPAIR > $WORKING_DIR/$CLUSTER_KEYPAIR
  chmod 600 $WORKING_DIR/$CLUSTER_KEYPAIR
  #nova keypair-add $KEY_PAIR_NAME > $WORKING_DIR/KEY_PAIR_NAME.pem
  DEFAULT_IMAGE_ID=`openstack --insecure image list | grep $CLUSTER_IMAGE | awk '{print$2}'`
  for i in $WORKING_DIR/*.json; do
      sed -i "s/{CLUSTER_TEMPLATE_ID}/$CLUSTER_TEMPLATE_ID/" $i
      sed -i "s/{KEYPAIR_NAME}/$CLUSTER_KEYPAIR/" $i
      sed -i "s/{DEFAULT_IMAGE_ID}/$DEFAULT_IMAGE_ID/" $i
  done
  
  openstack --insecure dataprocessing cluster create --json $WORKING_DIR/my_cluster_create.json &> /dev/null
  echo "INFO: Cluster successfully deployed!"
  openstack --insecure dataprocessing cluster list
}

######################################################
# Cleanup Cluster, Cluster Template and Node Templates
######################################################
function cleanup () {

  # Cleanup Keypair
  rm -f $WORKING_DIR/$CLUSTER_KEYPAIR

  openstack --insecure keypair delete $CLUSTER_KEYPAIR
  # Cleanup Template working files
  rm -f $WORKING_DIR/*.json

  count=0
  LIMIT=10
  while true;
  do
    count=$(($count+1))
    CLUSTER_STATUS="openstack --insecure dataprocessing cluster list"
    if [[ $($CLUSTER_STATUS |grep $CLUSTER_NAME |awk '{print $2}') == $CLUSTER_NAME ]];
    then
      echo "Cluster [$CLUSTER_NAME] is not deleted"
      echo "Deleting Cluster [$CLUSTER_NAME]"
 
      # Cleanup Cluster
      openstack --insecure dataprocessing cluster delete $CLUSTER_NAME
    else 
      # Cleanup Cluster Template
      openstack --insecure dataprocessing cluster template delete $TEMPLATE_NAME-$HA_MODE-cluster

      # Cleanup Node Temaplate
      openstack --insecure dataprocessing node group template delete $TEMPLATE_NAME-worker 
      if [ $HA_MODE == "non-HA" ]; then
        openstack --insecure dataprocessing node group template delete $TEMPLATE_NAME-master 
      else
        openstack --insecure dataprocessing node group template delete $TEMPLATE_NAME-master1
        openstack --insecure dataprocessing node group template delete $TEMPLATE_NAME-master2
        openstack --insecure dataprocessing node group template delete $TEMPLATE_NAME-master3
      fi

      echo "Cluster $CLUSTER_NAME, Cluster Template and Node Templates Deleted"
      break # Exit Loop and continue with script.
    fi
    if [ "$count" == "$LIMIT" ]
    then
      echo "[$CLUSTER_NAME] status is still [$($CLUSTER_STATUS |grep status |awk '{print $6}')] and not Deleted within the specified time."
      echo "Exiting script...."
      exit
    fi
    sleep 30
    echo "[$CLUSTER_NAME] status is [$($CLUSTER_STATUS |grep status |awk '{print $6}')] : Time Elapsed - $(($count*30)) Seconds"
  done

}

function usage () {
  echo ""
  echo "Missing paramter. Please Enter one of the following options"
  echo ""
  echo "Usage: $0 {Any of the options below}"
  echo ""
  echo "  deploy <Cluster Name>"
  echo "         - Will run all of the commands below except for cleanup"
  echo "  create_node_templates"
  echo "  create_cluster_template"
  echo "  deploy_cluster <Cluster Name>"
  echo "  cleanup <Cluster Name>"
  echo ""
  echo ""
}

function main () {
  echo ""
  echo "Welcome to Cluster Deploy Script"
  echo ""

  source openrc
  if [ -z $2 ]; then
    usage
    exit 1
  fi

  CLUSTER_NAME=$2 
  CLUSTER_KEYPAIR=$CLUSTER_NAME$KEYPAIR
  WORKING_DIR=$WORKING_DIR/$CLUSTER_NAME
  if [ -z $3 ]; then
    HA_MODE="non-HA"
    echo "Setting HA mode to [$HA_MODE]"
  else
    HA_MODE=$3
    echo "Setting HA mode to [$HA_MODE]"
  fi
  # Add cluster name to Template name
  # i.e generate a new template for each cluster
  #TEMPLATE_NAME=$CLUSTER_NAME$TEMPLATE_NAME
  if [ $1 == "deploy" ]; then
    setup
    create_node_templates
    create_cluster_template
    deploy_cluster
  else
    case $1 in
      "create_node_templates")
        setup
        create_node_templates
        ;;
      "create_cluster_template")
        setup
        create_cluster_template
        ;;
      "deploy_cluster")
        setup
        deploy_cluster
        ;;
      "cleanup")
        cleanup
        ;;
      *)
        usage
        exit 1
    esac
  fi

}

main $1 $2 $3

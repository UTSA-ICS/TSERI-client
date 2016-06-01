#!/bin/bash

##################################################################
# Check if hdp directory exists.
# HDP setup typically takes a few minutes after VM startup,
# so wait for setup to complete and directory to be created.
##################################################################
HDP_VERSION=""
count=0
SECS=30
while true;
  do
    if [[ -d "/usr/hdp" ]];
    then
      echo "Directory /usr/hdp found, Now checking HDP version"
      HDP_VERSION=`ls /usr/hdp | grep '^[0-9]\W*'`
      echo "HDP version [$HDP_VERSION] detected"
      break;
    else
      echo "/usr/hdp directory does not exist as yet, waiting $SECS seconds for HDP setup to complete - Time Elapsed: $(($count*30)) seconds"
      sleep $SECS
      count=$(($count+1))
    fi
done

echo "" >> /usr/lib64/R/etc/Renviron
echo "# Hadoop Vars for Rstudio" >> /usr/lib64/R/etc/Renviron
echo "HADOOP_HOME='/usr/hdp/$HDP_VERSION/hadoop'" >> /usr/lib64/R/etc/Renviron
echo "HADOOP_CMD='/usr/bin/hadoop'" >> /usr/lib64/R/etc/Renviron
echo "HADOOP_STREAMING='/usr/hdp/$HDP_VERSION/hadoop-mapreduce/hadoop-streaming.jar'" >> /usr/lib64/R/etc/Renviron

echo "" >> /etc/profile
echo "# Hadoop Vars for Rstudio" >> /etc/profile
echo "HADOOP_HOME='/usr/hdp/$HDP_VERSION/hadoop'" >> /etc/profile
echo "HADOOP_CMD='/usr/bin/hadoop'" >> /etc/profile
echo "HADOOP_STREAMING='/usr/hdp/$HDP_VERSION/hadoop-mapreduce/hadoop-streaming.jar'" >> /etc/profile

HOSTNAME=`hostname |cut -d"." -f 1`
INSTANCE_NUMBER=`echo $HOSTNAME |rev |cut -c 1`
CLUSTER_NAME=`echo $HOSTNAME |sed s/-[a-zA-Z0-9]*[hHdDpP]-.*//`
CLUSTER_NAME=`echo $CLUSTER_NAME |cut -c -10`

if [[ `echo $HOSTNAME |grep "master"` == $HOSTNAME ]]
then
  NETBIOS_NAME=$CLUSTER_NAME-m$INSTANCE_NUMBER
else
  NETBIOS_NAME=$CLUSTER_NAME-w$INSTANCE_NUMBER
fi

echo ""
echo "Setting Netbios Name to [$NETBIOS_NAME]"
echo ""

# See if AD line exists in hosts file and if so update otherwise insert line
grep -q '^'<ADS_IP>'' /etc/hosts && sed -i 's/'<ADS_IP>'.*/'<ADS_IP>'   '<ADS_SERVER>'.'<ADS_DOMAIN>'   '<ADS_SERVER>'/g' /etc/hosts || \
echo ''<ADS_IP>'   '<ADS_SERVER>'.'<ADS_DOMAIN>'   '<ADS_SERVER>'' >> /etc/hosts


sed -i "s/^.*netbios name =.*/netbios name = $NETBIOS_NAME/" /etc/samba/smb.conf
net ads join -S TSERI-AD -U Administrator%<ADS_ADMIN_PASSWORD>

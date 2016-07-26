#!/bin/sh
# execute this program by CreateHDFSProject.sh projectname
# This will create a new project folder and set correct file permissions
export proj="$1"
 
su hdfs << 'EOF'
dirpath=/project/$proj
if hadoop fs -test -d $dirpath ; then
    echo "Directory exists"
    hadoop fs -ls /project
    hadoop fs -ls /project/$proj         
else
    echo "Creating new main project directory"
    hadoop fs -mkdir /project/$proj
 
    echo "Setting correct user permissions"
    hadoop fs -chmod 770 /project/$proj
 
    echo "Changing ownership of $proj folder"
    hadoop fs -chgrp $proj /project/$proj
    hadoop fs -chmod 770 /project/$proj
 
    echo "Creating new raw_data directory"
    hadoop fs -mkdir /project/$proj/raw_data
    hadoop fs -chmod 770 /project/$proj/raw_data
 
    echo "Creating new shared directory"
    hadoop fs -mkdir /project/$proj/shared
    hadoop fs -chmod 770 /project/$proj/shared
 
    echo "Creating new user_agreement directory"
    hadoop fs -mkdir /project/$proj/user_agreement
    hadoop fs -chmod 770 /project/$proj/user_agreement
 
    echo "Creating new results directory"
    hadoop fs -mkdir /project/$proj/results
    hadoop fs -chmod 770 /project/$proj/results
 
    echo "Creating new scripts directory"
    hadoop fs -mkdir /project/$proj/scripts
    hadoop fs -chmod 770 /project/$proj/scripts
 
    echo "Here is the new directory:"
    hadoop fs -ls /project
    hadoop fs -ls /project/$proj
fi
 
exit
EOF

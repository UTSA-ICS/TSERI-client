#!/bin/sh
# execute this program by CreateHDFSAccount.sh abc123
# This will create a new user folder and set correct file permissions
export abc="$1"
 
#dirpath=/user/hive
 
su hdfs << 'EOF'
dirpath=/user/$abc
if hadoop fs -test -d $dirpath ; then
    echo "Directory exists"
    hadoop fs -ls /user
else
    echo "Creating new directory"
    hadoop fs -mkdir /user/$abc
    echo "Setting correct user permissions"
    hadoop fs -chmod 750 /user/$abc
    echo "Changing ownership of folder"
    hadoop fs -chown $abc:$abc /user/$abc
    echo "Here is the new directory:"
    hadoop fs -ls /user
fi
 
exit
EOF

#!/bin/bash
function install_jupyter () {
	echo ""
	echo "INFO: Install Jupyter and JupyterHub ....."
	echo ""

    ret=`python -c 'import sys; print("%i" % (sys.hexversion<0x03000000))'`
    if [ $ret -eq 0 ]; then
       echo "we require python version <3"
    else 
       echo "python version is <3"
    fi

	echo "INFO: Enabling EPEL Repository dependancies......";
	yum -y install epel-release
	echo "INFO: Installing dependancies......";
	yum -y install nodejs npm git &> /dev/null
	npm install -g configurable-http-proxy
	
	echo "INFO: Installing JupyerHub......";
	pip3 install "ipython[notebook]"
	pip3 install jupyterhub
	git clone https://github.com/jupyter/jupyterhub.git
	cd jupyterHub
	pip3 install -r dev-requirements.txt -e .

	# Install R library requirements:
	echo "INFO: Installing following packages: gmp libcurl-devel libxml2-devel mpfr openssl-devel ......";
	yum -y install gmp libcurl-devel libxml2-devel mpfr openssl-devel &> /dev/null

	# Configure R to work with Java properly
	R CMD javareconf &> /dev/null

	echo "INFO: Installing a bunch of R packages ......"
	R_PACKAGES='"rJava", "RJSONIO", "rmr", "rhdfs", "rhbase", "plyrmr", "Rcpp", "digest", "functional", "reshape2", "stringr", "plyr", "caTools"'
	R_REPO="'http://cran.us.r-project.org'"
	echo "install.packages(c($R_PACKAGES), dependencies=TRUE, repos=$R_REPO)" > $WORKING_DIR/tmp_install-R-packages.R
	sudo R CMD BATCH $WORKING_DIR/tmp_install-R-packages.R &> /dev/null

	# Download & Install R hadoop packages
	echo "INFO: Downloading 'rmr2' and 'rhdfs' packages ......"
	wget $RMR2_PACKAGE_URL -P $WORKING_DIR &> /dev/null
	wget $RHDFS_PACKAGE_URL -P $WORKING_DIR &> /dev/null

	echo "INFO: Installing 'rmr2' and 'rhdfs' packages ......"
	R CMD INSTALL $WORKING_DIR/$RMR2_PACKAGE_NAME &> /dev/null

	# Set HADOOP_CMD needed for installation of 'rhdfs' package
	export HADOOP_CMD='/usr/bin/hadoop'

	R CMD INSTALL $WORKING_DIR/$RHDFS_PACKAGE_NAME &> /dev/null

	# Enable users to log in using LDAP/AD
	cp /etc/pam.d/rstudio /etc/pam.d/rstudio.bak
	cp /etc/pam.d/login /etc/pam.d/rstudio

	echo ""
	echo "INFO: Done with 'R' installation ....."
	echo ""
}
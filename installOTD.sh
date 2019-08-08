#!/bin/bash

#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./installOTD.sh <acceptOTNLicenseAgreement> <otnusername> <otnpassword> <originServers>"  
}

#Function to cleanup all temporary files
function cleanup()
{
    echo "Cleaning up temporary files..."
	
    rm -f $BASE_DIR/jdk-8u131-linux-x64.tar.gz
    rm -f $BASE_DIR/fmw_12.2.1.3.0_otd_linux64_Disk1_1of1.zip
	
    rm -rf $JDK_PATH/jdk-8u131-linux-x64.tar.gz
    rm -rf $OTD_PATH/fmw_12.2.1.3.0_otd_linux64_Disk1_1of1.zip
    
    rm -rf $OTD_PATH/silent-template
    	
    rm -rf $OTD_JAR
    echo "Cleanup completed."
}

#Function to create OTD Installation Location Template File for Silent Installation
function create_oraInstlocTemplate()
{
    echo "creating Install Location Template..."

    cat <<EOF >$OTD_PATH/silent-template/oraInst.loc.template
inventory_loc=[INSTALL_PATH]
inst_group=[GROUP]
EOF
}

#Function to create OTD Installation Response Template File for Silent Installation
function create_oraResponseTemplate()
{

    echo "creating Response Template..."

    cat <<EOF >$OTD_PATH/silent-template/response.template
[ENGINE]

#DO NOT CHANGE THIS.
Response File Version=1.0.0.0.0

[GENERIC]

#Set this to true if you wish to skip software updates
DECLINE_AUTO_UPDATES=false

#My Oracle Support User Name
MOS_USERNAME=

#My Oracle Support Password
MOS_PASSWORD=<SECURE VALUE>

#If the Software updates are already downloaded and available on your local system, then specify the path to the directory where these patches are available and set SPECIFY_DOWNLOAD_LOCATION to true
AUTO_UPDATES_LOCATION=

#Proxy Server Name to connect to My Oracle Support
SOFTWARE_UPDATES_PROXY_SERVER=

#Proxy Server Port
SOFTWARE_UPDATES_PROXY_PORT=

#Proxy Server Username
SOFTWARE_UPDATES_PROXY_USER=

#Proxy Server Password
SOFTWARE_UPDATES_PROXY_PASSWORD=<SECURE VALUE>

#The oracle home location. This can be an existing Oracle Home or a new Oracle Home
ORACLE_HOME=[INSTALL_PATH]/Oracle/Middleware/Oracle_Home

#Set this variable value to the Installation Type selected. e.g. WebLogic Server, Coherence, Complete with Examples.
INSTALL_TYPE=Standalone OTD (Managed independently of WebLogic server)

#Provide the My Oracle Support Username. If you wish to ignore Oracle Configuration Manager configuration provide empty string for user name.
MYORACLESUPPORT_USERNAME=

#Provide the My Oracle Support Password
MYORACLESUPPORT_PASSWORD=<SECURE VALUE>

#Set this to true if you wish to decline the security updates. Setting this to true and providing empty string for My Oracle Support username will ignore the Oracle Configuration Manager configuration
DECLINE_SECURITY_UPDATES=true

#Set this to true if My Oracle Support Password is specified
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false

#Provide the Proxy Host
PROXY_HOST=

#Provide the Proxy Port
PROXY_PORT=

#Provide the Proxy Username
PROXY_USER=

#Provide the Proxy Password
PROXY_PWD=<SECURE VALUE>

#Type String (URL format) Indicates the OCM Repeater URL which should be of the format [scheme[Http/Https]]://[repeater host]:[repeater port]
COLLECTOR_SUPPORTHUB_URL=


EOF
}

#Function to create OTD Uninstallation Response Template File for Silent Uninstallation
function create_oraUninstallResponseTemplate()
{
    echo "creating Uninstall Response Template..."

    cat <<EOF >$OTD_PATH/silent-template/uninstall-response.template
[ENGINE]

#DO NOT CHANGE THIS.
Response File Version=1.0.0.0.0

[GENERIC]

#This will be blank when there is nothing to be de-installed in distribution level
SELECTED_DISTRIBUTION=Standalone OTD (Managed independently of WebLogic server)~[OTDVER]

#The oracle home location. This can be an existing Oracle Home or a new Oracle Home
ORACLE_HOME=[INSTALL_PATH]/Oracle/Middleware/Oracle_Home/

EOF
}

# Uninstall OTD if already present
function uninstallOTD()
{
    export UNINSTALL_SCRIPT=$INSTALL_PATH/Oracle/Middleware/Oracle_Home/oui/bin/deinstall.sh
    if [ -f "$UNINSTALL_SCRIPT" ]
    then
            echo "#########################################################################################################"

	    echo "Stopping OTD server..."
	    sudo runuser -l oracle -c "$OTD_DOMAIN_HOME/config/fmwconfig/components/OTD/instances/${OTD_INSTANCE}/bin/stopserv > /dev/null 2>&1 &"

	    currentVer=`. $INSTALL_PATH/Oracle/Middleware/Oracle_Home/oui/bin/viewInventory.sh  | grep fmw_install_otd | awk {'print $3'}`
            echo "Uninstalling already installed version :"$currentVer
            sudo runuser -l oracle -c "$UNINSTALL_SCRIPT -silent -responseFile ${SILENT_FILES_DIR}/uninstall-response"

	    sudo rm -rf $INSTALL_PATH/*
	    sudo rm -rf $OTD_DOMAIN_HOME/*

	    echo "#########################################################################################################"
    fi
}

#Install OTD using Silent Installation Templates
function installOTD()
{
    # Using silent file templates create silent installation required files
    echo "Creating silent files for installation from silent file templates..."

    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/uninstall-response.template > ${SILENT_FILES_DIR}/uninstall-response
    sed -i 's@\[OTDVER\]@'"$OTD_VER"'@' ${SILENT_FILES_DIR}/uninstall-response
    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/response.template > ${SILENT_FILES_DIR}/response
    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/oraInst.loc.template > ${SILENT_FILES_DIR}/oraInst.loc
    sed -i 's@\[GROUP\]@'"$USER_GROUP"'@' ${SILENT_FILES_DIR}/oraInst.loc

    echo "Created files required for silent installation at $SILENT_FILES_DIR"

    # Uninstall OTD if already exists
    uninstallOTD

    echo "---------------- Installing Linux prerequisite libraries required for OTD --------------"
    sudo yum install -y binutils compat-libcap1 compat-libstdc++-33 libgcc libstdc++ libstdc++-devel sysstat gcc gcc-c++ ksh make glibc glibc-devel libaio libaio-devel 

    echo "---------------- Installing OTD ${OTD_JAR} ----------------"
    export INSTALL_TYPE="Standalone OTD (Managed independently of WebLogic server)"
    echo ${OTD_JAR} -silent ORACLE_HOME=$ORACLE_HOME DECLINE_SECURITY_UPDATES=true INSTALL_TYPE=\"${INSTALL_TYPE}\" -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc

    runuser -l oracle -c "${OTD_JAR} -silent ORACLE_HOME=$ORACLE_HOME DECLINE_SECURITY_UPDATES=true INSTALL_TYPE=\"${INSTALL_TYPE}\" -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc"

    # Check for successful installation and version requested
    if [[ $? == 0 ]];
    then
      echo "OTD Installation is successful!"
    else

      echo_stderr "Installation is not successful!"
      exit 1
    fi
    echo "#########################################################################################################"                                          
}

# Create py script for OTD instance creation
function createDomainScript()
{
    echo "creating wlst script to configure OTD..."

    OTDVM_PUBLIC_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
    export OTDVM_PUBLIC_IP

    cat <<EOF >${user_home_dir}/configureOTD.py
try:
  print 'Creating OTD Domain...'
  props = {'domain-home': '${OTD_DOMAIN_HOME}'}
  otd_createStandaloneDomain(props)
  print 'OTD Domain created successfully!'

  print 'Creating OTD instance...'
  props = {'domain-home': '${OTD_DOMAIN_HOME}', 'origin-server': '${originServers}', 'listener-port': '1905', 'instance': '${OTD_INSTANCE}', 'server-name': '${OTDVM_PUBLIC_IP}'}
  otd_createStandaloneInstance(props)
  print 'OTD instance created successfully!'
except Exception, e :
  print e

EOF
    sudo chown $username:$groupname ${user_home_dir}/configureOTD.py
}

# Create OTD domain and start instance
function startOTDInstance()
{
    # create py script
    createDomainScript

    # execute py script
    runuser -l oracle -c "${ORACLE_HOME}/oracle_common/common/bin/wlst.sh ${user_home_dir}/configureOTD.py"
    sleep 10

    # start OTD instance
    runuser -l oracle -c "$OTD_DOMAIN_HOME/config/fmwconfig/components/OTD/instances/${OTD_INSTANCE}/bin/startserv > /dev/null 2>&1 &"

    if [[ $? == 0 ]];
    then
      echo "OTD instance started successfully!"
    else

      echo_stderr "Issues in starting up OTD instance!"
      exit 1
    fi
}

#main script starts here

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BASE_DIR="$(readlink -f ${CURR_DIR})"

if [ $# -ne 4 ]
then
    usage
    exit 1
fi

export acceptOTNLicenseAgreement="$1"
export otnusername="$2"
export otnpassword="$3"
export originServers="$4"

if [ -z "$acceptOTNLicenseAgreement" ];
then
	echo _stderr "acceptOTNLicenseAgreement is required. Value should be either Y/y or N/n"
	exit 1
fi

if [[ ! ${acceptOTNLicenseAgreement} =~ ^[Yy]$ ]];
then
    echo "acceptOTNLicenseAgreement value not specified as Y/y (yes). Exiting installation Weblogic Server process."
    exit 1
fi

if [[ -z "$otnusername" || -z "$otnpassword" || -z "$originServers" ]]
then
	echo_stderr "otnusername / otnpassword / originServers is required. "
	exit 1
fi	

export OTD_VER="12.2.1.3.0"

#add oracle group and user
echo "Adding oracle user and group..."
groupname="oracle"
username="oracle"
user_home_dir="/u01/oracle"
USER_GROUP=${groupname}
sudo groupadd $groupname
sudo useradd -d ${user_home_dir} -g $groupname $username

JDK_PATH="/u01/app/jdk"
OTD_PATH="/u01/app/otd"

#create custom directory for setting up otd and jdk
sudo mkdir -p $JDK_PATH
sudo mkdir -p $OTD_PATH
sudo rm -rf $JDK_PATH/*
sudo rm -rf $OTD_PATH/*

cleanup

#Download OTD install jar from OTN // cookie; accept-dbindex-cookie
echo "Downloading OTD install kit from OTN..."
curl -s https://raw.githubusercontent.com/typekpb/oradown/master/oradown.sh  | bash -s -- --cookie=accept-dbindex-cookie --username="${otnusername}" --password="${otnpassword}" http://download.oracle.com/otn/linux/middleware/12c/12213/fmw_12.2.1.3.0_otd_linux64_Disk1_1of1.zip

#download jdk from OTN
echo "Downloading jdk from OTN..."
curl -s https://raw.githubusercontent.com/typekpb/oradown/master/oradown.sh  | bash -s -- --cookie=accept-weblogicserver-server --username="${otnusername}" --password="${otnpassword}" https://download.oracle.com/otn/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jdk-8u131-linux-x64.tar.gz

sudo chown -R $username:$groupname /u01/app

sudo cp $BASE_DIR/fmw_12.2.1.3.0_otd_linux64_Disk1_1of1.zip $OTD_PATH/fmw_12.2.1.3.0_otd_linux64_Disk1_1of1.zip
#sudo cp $BASE_DIR/fmw_12.2.1.4.0_otd_linux64.bin $OTD_PATH/fmw_12.2.1.4.0_otd_linux64.bin
sudo cp $BASE_DIR/jdk-8u131-linux-x64.tar.gz $JDK_PATH/jdk-8u131-linux-x64.tar.gz

echo "extracting and setting up jdk..."
sudo tar -zxvf $JDK_PATH/jdk-8u131-linux-x64.tar.gz --directory $JDK_PATH
sudo chown -R $username:$groupname $JDK_PATH

export JAVA_HOME=$JDK_PATH/jdk1.8.0_131
export PATH=$JAVA_HOME/bin:$PATH

java -version

if [ $? == 0 ];
then
    echo "JAVA HOME set succesfully."
else
    echo_stderr "Failed to set JAVA_HOME. Please check logs and re-run the setup"
    exit 1
fi

echo "Installing zip unzip wget vnc-server rng-tools bind-utils"
sudo yum install -y zip unzip wget vnc-server rng-tools bind-utils

echo "unzipping fmw_12.2.1.3.0_otd_linux64_Disk1_1of1.zip..."
sudo unzip -o $OTD_PATH/fmw_12.2.1.3.0_otd_linux64_Disk1_1of1.zip -d $OTD_PATH

export SILENT_FILES_DIR=$OTD_PATH/silent-template
sudo mkdir -p $SILENT_FILES_DIR
sudo rm -rf $OTD_PATH/silent-template/*
sudo chown -R $username:$groupname $OTD_PATH

export INSTALL_PATH="$OTD_PATH/install"
export ORACLE_HOME="$OTD_PATH/install/Oracle/Middleware/Oracle_Home"
export OTD_JAR="$OTD_PATH/fmw_12.2.1.3.0_otd_linux64.bin"
export OTD_DOMAIN_HOME=${user_home_dir}/otd_domain
export OTD_INSTANCE=azure_otd


mkdir -p $INSTALL_PATH
sudo chown -R $username:$groupname $INSTALL_PATH

create_oraInstlocTemplate
create_oraResponseTemplate
create_oraUninstallResponseTemplate

installOTD

startOTDInstance

cleanup

echo "OTD Setup Completed succesfully."

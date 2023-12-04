#!/bin/bash
# Install command 
# 		sudo bash -c "$(curl -sL https://staticdownloads.site24x7.com/server/Site24x7InstallScript.sh)" readlink -i -key=<device_key>
#Author : Arunagiriswaran E
#Company : ZOHOCORP

PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:/usr/sfw/bin:$PATH
PS_CMD='ps auxww '
if [ -f "/etc/release" ]; then
	cat /etc/release | grep "Solaris 10" > /dev/null
	if [ $? = 0 ]; then
		PATH=/usr/xpg4/bin:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:/usr/sfw/bin:$PATH
		PS_CMD='ps -e '
	fi
fi
OS_BINARY_TYPE=''
OS_NAME=`uname -s`
OS_ARCH=`uname -m`
LDD_VERSION=`ldd --version 2>/dev/null | awk 'NR==1{ print $NF }'`
SUCCESS=0
WARNING=1
FAILURE=2
BOOL_TRUE='True'
BOOL_FALSE='False'
IS_VENV_SUPPORT_NEEDED=$BOOL_FALSE
ECHO_PRINT=5
THIRTY_TWO_BIT='32-bit'
SIXTY_FOUR_BIT='64-bit'
SUDO=''
PRODUCT_NAME='Site24x7'
API_KEY=''
SITE24X7_AGENT_INSTALL_INPUT=''
SITE24X7_AGENT_INSTALL_PARAMS=''

SITE24X7_AGENT_NONROOT='0'
INSTALL='INSTALL'
REINSTALL='REINSTALL'
UNINSTALL='UNINSTALL'

#LOCAL_SETUP=$BOOL_TRUE
LOCAL_SETUP=$BOOL_FALSE

#local
LOCAL_SERVER=''

#livebuild
SERVER='https://staticdownloads.site24x7.com'
THIRTY_TWO_BIT_INSTALL_FILE='Site24x7_Linux_32bit.install'
SIXTY_FOUR_BIT_INSTALL_FILE='Site24x7_Linux_64bit.install'
VENV_INSTALL_FILE='Site24x7MonitoringAgent.install'
INSTALL_FILE='Site24x7InstallScript.sh'

DOWNLOAD_URL=""

print_green() {
    printf "\033[32m%s\033[0m\n" "$*"
}

print_console() {
    printf "%s\n" "$*"
}

print_red() {
    printf "\033[31m%s\033[0m\n" "$*"
}


print_done() {
    print_green "Done"
}

`command -v which 2>/dev/null 1>/dev/null`
if [ $? = 0 ]; then
    COMMAND_CHECKER="which"
else
    COMMAND_CHECKER="command -v"
fi

if [ $(command -v wget) ]; then
    DOWNLOAD_CMD="wget -O"
    print_green "wget detected"
elif [ $(command -v curl) ]; then
    DOWNLOAD_CMD="curl -Lo"
    print_green "curl detected"
elif [ $(command -v fetch) ]; then
    DOWNLOAD_CMD="fetch -o"
    print_green "fetch detected"
else
    DOWNLOAD_CMD=''
    print_red "All curl, wget and fetch not present hence exiting"
    exit $FAILURE
fi

if ! [ $(command -v tar) ]; then
	print_red "Tar utility not present to unzip product...Try installing tar before proceed with agent installation"
    exit $FAILURE
fi

log() {
	if [ "$1" = "$ECHO_PRINT" ]; then
		echo "$2"
	fi
}

getHardwarePlatform() {		
	if [ "`which file`" = "" ]; then		
	    if [ `/usr/bin/getconf LONG_BIT` = "64" ]; then
		    OS_BINARY_TYPE="$SIXTY_FOUR_BIT"
		elif [ `/usr/bin/getconf LONG_BIT` = "32" ]; then
		    OS_BINARY_TYPE="$THIRTY_TWO_BIT"
		fi
	else
		if /usr/bin/file /sbin/init | grep 'ELF 64-bit' >/dev/null; then
		    OS_BINARY_TYPE="$SIXTY_FOUR_BIT"
		elif /usr/bin/file /sbin/init | grep 'ELF 32-bit' >/dev/null; then
		    OS_BINARY_TYPE="$THIRTY_TWO_BIT"
		elif [ `/usr/bin/getconf LONG_BIT` = "64" ]; then
		    OS_BINARY_TYPE="$SIXTY_FOUR_BIT"
		elif [ `/usr/bin/getconf LONG_BIT` = "32" ]; then
		    OS_BINARY_TYPE="$THIRTY_TWO_BIT"
		fi
	fi	
}	

command_test() {
    $COMMAND_CHECKER $1 2>/dev/null 1>/dev/null
    if [ $? -ne 0 ]; then
    	if [ $2 = "optional" ]; then
    		WARNING_MSG=$WARNING_MSG" $1"
    		WARNING_FLAG=$BOOL_TRUE
    	else
    		ERROR_MSG=$ERROR_MSG" $1"
    		SEVERE_FLAG=$BOOL_TRUE
    	fi 
    fi
}

utilityCheck() {
	WARNING_MSG='Kindly install these if possible : '
	ERROR_MSG='Please install the following utility : '
	WARNING_FLAG=$BOOL_FALSE
	SEVERE_FLAG=$BOOL_FALSE
	command_test useradd "optional"
	command_test groupadd "optional"
	command_test usermod "optional"
	command_test awk "mandatory"
	command_test sed "mandatory"
 	if [ "$SEVERE_FLAG" = "$BOOL_TRUE" ]; then
 		print_red $ERROR_MSG
 		print_red $WARNING_MSG
 		exit $FAILURE
 	fi
}

detectArchitectureType(){
	if [[ "$OS_ARCH" = *"arm"* ]] || [[ "$OS_ARCH" = *"ARM"* ]] || [[ "$OS_ARCH" = *"Arm"* ]] || [[ "$OS_ARCH" = *"aarch"* ]] || [[ "$OS_ARCH" = *"ppc64le"* ]] || [[ "$OS_ARCH" = *"s390x"* ]] ; then
	  IS_VENV_SUPPORT_NEEDED=$BOOL_TRUE
	fi
	print_green "Detected os arch : $OS_ARCH"
}

detectOs(){
	if [ "$OS_NAME" != "Linux" ]; then
		IS_VENV_SUPPORT_NEEDED=$BOOL_TRUE
	fi
	print_green "Detected OS : $OS_NAME"
}

format_version() {
        echo "$@" | awk -F. '{ printf("%03d%03d%03d\n", $1,$2,$3); }';
}

detectLibc(){
	libc_version="$(ldd --version 2>/dev/null | awk 'NR==1{ print $NF }')"
	if [ "$libc_version" != "" ]; then
		if [ "$(format_version $libc_version)" -lt "$(format_version 2.5)" ]; then
			print_red "Libc vesion $libc_version which is less than 2.5"
			IS_VENV_SUPPORT_NEEDED=$BOOL_TRUE
		fi
	fi
}

detectFlatCarOs(){
		OS_INFO=`uname -a`
        if [[ "$OS_INFO" = *"flatcar"* ]];then
                IS_VENV_SUPPORT_NEEDED=$BOOL_TRUE
        fi
}

checkShellUtility(){
	if command -v bash >/dev/null; then
    	SHELL_UTILITY="bash"
    else
    	SHELL_UTILITY="sh"
    fi
}

isRootUser() {
	if [ "$(id -u)" != "0" ]; then
		print_red "Please use 'sudo' or log in as root to execute the script"
		exit $FAILURE
	fi
}

isNonRootUser() {
	if [ "$(id -u)" == "0" ]; then
		print_red "Can't use -nonroot or -nr option when logged in as root"
		exit $FAILURE
	fi
}

checkForBinSupport(){
	checkShellUtility
	detectOs
	detectLibc
	detectArchitectureType 2>/dev/null
	detectFlatCarOs
}

setServerDomain() {
	DC="${MON_AGENT_API_KEY:0:2}"
	case "$DC" in 
    	eu | cn | in | jp | uk | ca | sa ) 
			SERVER="${SERVER//.com/.$DC}"
        ;;
		au )
			SERVER="${SERVER//.com/".net.au"}"
		;;
	esac
}

setServerDomainForReinstall() {
	DC=$(echo "$SERVER_NAME" | awk -F. '{print $NF}')
	case "$DC" in 
    	eu | cn | in | au | jp | uk | ca | sa ) 
			SERVER="${SERVER//.com/.$DC}"
        ;;
		au )
			SERVER="${SERVER//.com/".net.au"}"
		;;
	esac
}

setDownloadUrl() {
	if [ "$LOCAL_SETUP" = "$BOOL_TRUE" ]; then
	   if [ "$IS_VENV_SUPPORT_NEEDED" = "$BOOL_FALSE" ]; then
		if [ "$OS_BINARY_TYPE" = "$THIRTY_TWO_BIT" ]; then
			DOWNLOAD_URL="$LOCAL_SERVER/$THIRTY_TWO_BIT_INSTALL_FILE"		
		else
			DOWNLOAD_URL="$LOCAL_SERVER/$SIXTY_FOUR_BIT_INSTALL_FILE"
		fi
	   else
	   		print_green "Hybrid agent support needed"
			DOWNLOAD_URL="$LOCAL_SERVER/$VENV_INSTALL_FILE"
	   fi
	else
	    if [ "$IS_VENV_SUPPORT_NEEDED" = "$BOOL_FALSE" ]; then
		if [ "$OS_BINARY_TYPE" = "$THIRTY_TWO_BIT" ]; then
			DOWNLOAD_URL="$SERVER/server/$THIRTY_TWO_BIT_INSTALL_FILE"		
		else
			DOWNLOAD_URL="$SERVER/server/$SIXTY_FOUR_BIT_INSTALL_FILE"
		fi
	    else
	   		print_green "Source agent support needed"
			DOWNLOAD_URL="$SERVER/server/$VENV_INSTALL_FILE"
	    fi
	fi
	print_green "Download url : $DOWNLOAD_URL"
}

deleteInstaller() {
        fileToDelete=`echo "${DOWNLOAD_URL##*/}"`
		if [ -f $fileToDelete  ];then
        	rm -f $fileToDelete
		fi
}

installAgent() {
	if [ "$SITE24X7_AGENT_NONROOT" == "1" ]; then
		isNonRootUser
	else
		isRootUser
	fi
	getHardwarePlatform
	utilityCheck
	checkForBinSupport
	if [ "$SITE24X7_AGENT_INSTALL_INPUT" = "$REINSTALL" ];then
		if [ "$SITE24X7_AGENT_NONROOT" == "1" ]; then
			username=`id -u -n`
			USER_HOME=`getent passwd $username | cut -d: -f6`
			INSTALL_DIR=$USER_HOME
		else
			INSTALL_DIR="/opt"
		fi
		PRODUCT_HOME=$INSTALL_DIR/site24x7
		MON_AGENT_HOME=$PRODUCT_HOME/monagent
		SERVER_CONF=$MON_AGENT_HOME/conf/monagent.cfg
		SERVER_NAME=`cat $SERVER_CONF | grep -w "server_name" | head -1`
		setServerDomainForReinstall
	else
		setServerDomain
	fi
	setDownloadUrl
	echo ""
	echo "      -----------------------------------------------------------------------------------------------------------------------------------------------------"
	echo "      |																			  |"	
	echo "      |							      Site24x7 Server Monitoring Agent Installation					         |"
	echo "      |																			  |"
	echo "      -----------------------------------------------------------------------------------------------------------------------------------------------------"
	echo ""	
	echo ""
	echo ""	
	if [ "$IS_VENV_SUPPORT_NEEDED" = "$BOOL_TRUE" ]; then
        echo "      --------------------------------------------------------Downloading install file for "$VENV_INSTALL_FILE"----------------------------------------------------------"  
 	else
        echo "      --------------------------------------------------------Downloading install file for "$OS_BINARY_TYPE"----------------------------------------------------------"
	fi 	
	echo ""	
	if [ "$IS_VENV_SUPPORT_NEEDED" = "$BOOL_TRUE" ]; then
       if [ -f $VENV_INSTALL_FILE  ];then
       		echo $VENV_INSTALL_FILE "already exists so removing and downloading new one"
       		rm -f $VENV_INSTALL_FILE
       fi
       $DOWNLOAD_CMD $VENV_INSTALL_FILE $DOWNLOAD_URL
        if [ ! -f $VENV_INSTALL_FILE ]; then
           echo $VENV_INSTALL_FILE" not present hence quitting"
           exit $FAILURE
        fi
        if [[ "$OS_NAME" = *"Sun"* ]] || [[ "$OS_NAME" = *"AIX"* ]];then
             eval "$SHELL_UTILITY $VENV_INSTALL_FILE $SITE24X7_AGENT_INSTALL_PARAMS"
        else
             eval "$SHELL_UTILITY $VENV_INSTALL_FILE $SITE24X7_AGENT_INSTALL_PARAMS"
        fi
    elif [ "$OS_BINARY_TYPE" = "$THIRTY_TWO_BIT" ]; then
        if [ -f $THIRTY_TWO_BIT_INSTALL_FILE  ];then
       		echo $THIRTY_TWO_BIT_INSTALL_FILE "already exists so removing and downloading new one"
       		rm -f $THIRTY_TWO_BIT_INSTALL_FILE
       	fi
        $DOWNLOAD_CMD $THIRTY_TWO_BIT_INSTALL_FILE $DOWNLOAD_URL
        if [ ! -f $THIRTY_TWO_BIT_INSTALL_FILE  ]; then
        echo $THIRTY_TWO_BIT_INSTALL_FILE" not present hence quitting"
        exit $FAILURE
        fi
        chmod 755 $THIRTY_TWO_BIT_INSTALL_FILE
        eval "$SHELL_UTILITY ./$THIRTY_TWO_BIT_INSTALL_FILE $SITE24X7_AGENT_INSTALL_PARAMS"
    else
        if [ -f $SIXTY_FOUR_BIT_INSTALL_FILE  ];then
       		echo $SIXTY_FOUR_BIT_INSTALL_FILE "already exists so removing and downloading new one"
       		rm -f $SIXTY_FOUR_BIT_INSTALL_FILE
       	fi
        $DOWNLOAD_CMD $SIXTY_FOUR_BIT_INSTALL_FILE $DOWNLOAD_URL
        if [ ! -f $SIXTY_FOUR_BIT_INSTALL_FILE  ]; then
        echo $SIXTY_FOUR_BIT_INSTALL_FILE" not present hence quitting"
        exit $FAILURE
        fi
        chmod 755 $SIXTY_FOUR_BIT_INSTALL_FILE
        eval "$SHELL_UTILITY ./$SIXTY_FOUR_BIT_INSTALL_FILE $SITE24X7_AGENT_INSTALL_PARAMS"
    fi
    deleteInstaller
}

usage() {
	log $ECHO_PRINT ""
	log $ECHO_PRINT "Usage :"
	log $ECHO_PRINT '	Install command   : bash -c "$(curl -sL https://staticdownloads.site24x7.com/server/Site24x7InstallScript.sh)" readlink [options] -i -key=<device_key>'
	log $ECHO_PRINT ""	
	log $ECHO_PRINT "Options:"
	log $ECHO_PRINT "	-ri                          	Reinstall Server Agent with new source packages and old configuration"
	log $ECHO_PRINT "	-f                           	Force install the agent even when the agent present already"
	log $ECHO_PRINT "	-s24x7-agent                 	Run the agent as a site24x7-agent user"
	log $ECHO_PRINT "	-nr,-nonroot                 	Run the agent as a non-root user"
	log $ECHO_PRINT "	-nosyslog|-ns                	Disable syslog Monitoring"
	log $ECHO_PRINT "	-newkey|-nk                  	Register agent with new key"
	log $ECHO_PRINT "	-h                           	output usage information"
	log $ECHO_PRINT "	-ct,-CT                      	Configuration Template to be associated with the server"
	log $ECHO_PRINT "	-rule                        	Configuration Rule to be associated with the server"
	log $ECHO_PRINT "	-uid                         Option to create a site24x7 agent User with a specific User ID"
	log $ECHO_PRINT "	-gid                         Option to create a site24x7 agent group with a specific Group ID"
	log $ECHO_PRINT "	-dn,-DN                      	Display name of the server"
	log $ECHO_PRINT "	-gn,-GN                     	Group to which the server has to be added"
	log $ECHO_PRINT "	-tp,-TP                      	Threshold profile to be associated with the server"
	log $ECHO_PRINT "	-np,-NP                      	Notification profile to be associated with the server"
	log $ECHO_PRINT "	-rp,-RP                      	Resource Profile to be associated with the server"
	log $ECHO_PRINT "	-lp,-LP                      	Log Profile to be associated with the server"
	log $ECHO_PRINT "	-lt,-LT                      	Log Type to be associated with the server. For example -lt=SysLog"
	log $ECHO_PRINT "	-lf,-LF                    	Log Files to be collected for given log type. For example -lf=/var/log/syslog"
	log $ECHO_PRINT "	-automation=false            Disable IT Automation Module in the server agent"
	log $ECHO_PRINT "	-plugins=false               Disable Plugin Module in the server agent"
	log $ECHO_PRINT "	-location=<value>                        Add location tag to the server monitor"
	log $ECHO_PRINT "	-mysql='<mysql_configuration>'           Integrate MySQL Monitor along with Agent Installation"
	log $ECHO_PRINT "	-prometheus='<prometheus_configuration>' Integrate Prometheus along with Agent Installation"
	log $ECHO_PRINT "	-statsd='<statsd_configuration>'         Integrate Statsd along with Agent Installation"
	log $ECHO_PRINT "	-proxy                       	Set proxy to connect to the site24x7 server, if needed.
					EXAMPLE: -proxy=username:password@host:port, if there is no username and passowrd for proxy server then use -proxy=host:port"
	log $ECHO_PRINT ""
	log $ECHO_PRINT "For more command line installation configurations, refer more parameters at https://www.site24x7.com/help/admin/adding-a-monitor/command-line-installation.html"
	log $ECHO_PRINT ""
	exit $FAILURE
}

main() {
	for arg in $SITE24X7_AGENT_INSTALL_PARAMS
	do
        KEY=`echo $arg | awk -F= '{print $1}'`
        VALUE=`echo $arg | awk -F= '{print $2}'`
        case $KEY in
			-h|--help)
				usage
			;;
			-nr|-nonroot)
				SITE24X7_AGENT_NONROOT='1'
			;;
			-i)
				SITE24X7_AGENT_INSTALL_INPUT=$INSTALL
			;;
			-ri)
            	SITE24X7_AGENT_INSTALL_INPUT=$REINSTALL
            ;;
			-u)
				SITE24X7_AGENT_INSTALL_INPUT=$UNINSTALL
			;;
			-key)
				MON_AGENT_API_KEY=$VALUE
			;;
		esac
	done
	install_agent=$BOOL_TRUE
	if [ "$SITE24X7_AGENT_INSTALL_INPUT" = "$REINSTALL" ]; then
		install_agent=$BOOL_TRUE
		printf "Reinstallation in Progress \n"
	elif [ "$MON_AGENT_API_KEY" = "" ] || [ "$SITE24X7_AGENT_INSTALL_INPUT" = "" ]; then
		install_agent=$BOOL_FALSE
	fi
	if [ "$install_agent" = "$BOOL_TRUE" ]; then
		installAgent
		if [ "$OS_NAME" = "Linux" ]; then
			printf "\n"
			print_green "Have more servers? Try our bulk installation techniques. Refer link : https://www.site24x7.com/app/client#/admin/inventory/monitors-configure/SERVER/bulk"
			printf "\n"
		fi
	else
		usage
	fi
}

#removing nbsp character if appended
SITE24X7_AGENT_INSTALL_PARAMS=`echo $@ | sed 's/\xc2\xa0/ /g'` 

main

#!/usr/bin/env bash

LOG="/root/kv-script.sh.out"
# Saves file descriptors for later being restored
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
# Redirect stdout and stderr to a log file
exec 1>$LOG 2>&1

# Help display
usage='Usage:  
 kv-script.sh [OPTIONS]

OPTIONS:
\n --cloud=<cloud>
\t Cloud name to identify the results - REQUIRED
\n -i 
\t to install minimum amount of software to mount cvmfs  
'

# From now on, normal stdout output should be appended with ">&3". e.g.:
echo '
  #######################################
  ###    CERN Benchmarking Script     ###
  ###				      ###
  ### Based on the  ATLAS software    ###
  ### and Kit Validation engine	      ###
  ### as documented in [1].	      ###
  ### 			              ###
  ### Contacts:		              ###
  ###  domenico.giordano@cern.ch      ###
  ###  cristovao.cordeiro@cern.ch     ###
  ###  luis.villazon.esteban@cern.ch  ###
  ###  alessandro.di.girolamo@cern.ch ###
  #######################################
  [1] http://iopscience.iop.org/1742-6596/219/4/042037/pdf/1742-6596_219_4_042037.pdf
  #######################################
  Final log: '$LOG'
  #######################################
' >&3

# Exit when any command fails. To allow failing commands, add "|| true"
set -o errexit

echo "`date`: Starting benchmark..."

# Check kernel release. KV has el6 as base reference configuration
kernel=`uname -r`

if [[ $kernel == *"el7"* ]]; then
    echo -e "\nWARNING:
Your kernel release is el7!
The KV script is based on a el6 reference configuration.
Do you wish to continue anyway? (y/n)" >&3

    read -p "Run in el7?" -n 1 -r

    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo -e "\n" >&3
        echo -e "\n
!!!!!!!!!!!!!!!!!!!!!!
!!! Running on el7 !!!
!!!!!!!!!!!!!!!!!!!!!!
KERNEL-RELEASE = $kernel\n"
        el7=1
    else
        echo -e "\nAborted by the user."
        exit 1
    fi
else
    el7=0
fi

# Global parameters
KVTAG="KV-PROC-" 		        # KV tag name
KVTHR=`grep -c processor /proc/cpuinfo`	# Number of KV threads depends on number of CPUs
MEM=`free -m |awk '/^Mem:/{print $2}'`	# Total memory in MB

RATIO_THRESHOLD=1800			# At least MEM (MB) = 1.8*numCPUS. Desired ratio would be 2 but physical memory might vary 
let r="MEM/KVTHR"
if [ $r -lt $RATIO_THRESHOLD ]
then
    echo -e "
\t\tWARNING: computing requirements are not satisfied.
\t\tTo run this benchmark, the machine needs to have PHYSICAL MEMORY (GB) ~= 2 * number of CPUS
\t\tDetected MEMORY=${MEM} ; number of CPUs=${KVTHR}
\t\tThe script will now be terminated!
" >&3
    echo "
WARNING: ratio between total MEMORY and number of CPUs is not satisfied
MEMORY = ${MEM}
Number of CPUs = ${KVTHR}

Stopping script
" && exit 1 
fi

KVBMK="KVbmk.xml"       		# XML dump
RUNINSTALL=0            		# Install required software

while [ "$1" != "" ]; do
    case $1 in
        -i         )   RUNINSTALL=1
                       ;;
        --cloud=* )    CLOUD=${1#*=}; 
	               ;;	            
        * )         echo -e "${usage}" >&3
                    exit 1
    esac
    shift
done

# CLOUD must be defined
if [ -z $CLOUD ] || [ $CLOUD == "" ];then
    echo -e "${usage}" >&3 
    echo -e '\n\nFAILED. Cloud parameter should be defined. Exiting without finishing.\n' >&3 && exit 1
fi

echo -e "YOUR CLOUD NAME: $CLOUD" >&3

# Set and trap a function to be called in always when the scripts exits in error
END=0
function onEXIT {
  if [ $END -eq 0 ]; then
      echo -e "\n
!! ERROR !!: The script encountered a problem. Exiting without finishing.
Log snippet ($LOG):
***************************\n" >&3
      tail -5 $LOG >&3
      echo -e "\n***************************
" >&3
      cd
      tar -czf KV_error.tgz /scratch/KV $LOG
  else
      echo -e "\nExiting...\n" >&3
  fi
}
trap onEXIT EXIT


echo -e "\n\tSTEP 1 OUT OF 5: Prepare environment..." >&3 

echo "Kernel release is ${kernel}"

KVTAG="${KVTAG}${CLOUD}"
echo "KVTAG is ${KVTAG}"

# Define working directory
DIR=/scratch/KV
mkdir -p $DIR
echo "Created $DIR area"

KVBMK="$DIR/$KVBMK"	# Re-define KVBMK according to DIR
echo "KVBMK is ${KVBMK}"

# Get VM's IP address 
export V_IP_ADDRESS=`/sbin/ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
hostname ${V_IP_ADDRESS}

echo "IP Address is ${V_IP_ADDRESS}. The hostname has been set accordingly"



function dump_default_kvxml(){
    echo "
  ###################################
  # Dumping default XML file for KV #
  # `date`
  ###################################
"

    [ ! -e $DIR ] && mkdir $DIR

    cat > $DIR/KVbmk.xml << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE unifiedTestConfiguration SYSTEM "http://www.hep.ucl.ac.uk/atlas/AtlasTesting/DTD/unifiedTestConfiguration.dtd">

<unifiedTestConfiguration>

<kv>
    <kvtest name='AtlasG4SPG' enabled='true'>
      <release>ALL</release>
      <priority>20</priority>
      <kvsuite>KV2012</kvsuite>
      <trf>AtlasG4_trf.py</trf>
      <desc>Single Muon Simulation</desc>
      <author>Alessandro De Salvo [Alessandro.DeSalvo@roma1.infn.it]</author>
      <outpath>${T_DATAPATH}/SimulHITS-${T_RELEASE}</outpath>
      <outfile>${T_PREFIX}-SimulHITS-${T_RELEASE}.pool.root</outfile>
      <logfile>${T_PREFIX}-SimulHITS-${T_RELEASE}.log</logfile>
      <kvprestage>http://kv.roma1.infn.it/KV/input_files/simul/preInclude.SingleMuonGenerator.py</kvprestage>
      <signature>
        outputHitsFile="${T_OUTFILE}" maxEvents=100 skipEvents=0 preInclude=KitValidation/kv_reflex.py,preInclude.SingleMuonGenerator.py geometryVersion=ATLAS-GEO-16-00-00 conditionsTag=OFLCOND-SDR-BS7T-04-03
      </signature>
      <copyfiles>
        ${T_OUTFILE} ${T_LOGFILE} PoolFileCatalog.xml metadata.xml jobInfo.xml
      </copyfiles>
      <checkfiles>${T_OUTPATH}/${T_OUTFILE}</checkfiles>
    </kvtest>
</kv>
</unifiedTestConfiguration>
EOF

    echo '
  #####################################
  # Finished dumping default XML file #
  #####################################
'
}


function install_dependencies( ){
    echo "
  ###########################
  # Installing dependencies #
  # `date`
  ###########################
"
    
    if yum list installed wget; then
        :
    else
        yum -y install wget
    fi

    if [ $el7 -eq 1 ]; then
      install_dependencies_centos7
    else
      install_dependencies_centos6
    fi
 
    echo '
  ####################################
  # Finished installing dependencies #
  ####################################
'
}

function install_dependencies_centos6(){
    wget http://cern.ch/lfield/hn/condor-8.0.3-174914.rhel6.3.x86_64.rpm 
    yum -y localinstall condor-8.0.3-174914.rhel6.3.x86_64.rpm 

    wget http://cvmrepo.web.cern.ch/cvmrepo/yum/cernvm.repo -O /etc/yum.repos.d/cernvm.repo 
    wget http://cvmrepo.web.cern.ch/cvmrepo/yum/RPM-GPG-KEY-CernVM -O /etc/pki/rpm-gpg/RPM-GPG-KEY-CernVM 

    rpm --import http://emisoft.web.cern.ch/emisoft/dist/EMI/3/RPM-GPG-KEY-emi 

    cat << EOF >  /etc/yum.repos.d/slc6-extras.repo
[slc6-extras]
name=Scientific Linux CERN 6 (SLC6) add-on packages
baseurl=http://linuxsoft.cern.ch/cern/slc6X/x86_64/yum/extras/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cern
gpgcheck=0
enabled=1
protect=1
EOF

    yum -y update 
    yum -y install http://linuxsoft.cern.ch/wlcg/sl6/x86_64/HEP_OSlibs_SL6-1.0.16-0.el6.x86_64.rpm 
    yum --nogpgcheck -y install yum-priorities yum-protectbase 
    yum -y install cvmfs 
    yum -y install cvmfs-init-scripts 

    yum -y install epel-release 
    yum -y install redhat-lsb-core 
    yum -y install glibmm24 
    yum -y install openssl098e 
    yum -y install castor-devel 
    yum -y install xrootd-client 
    yum -y install xrootd-fuse 
}


function install_dependencies_centos7(){
    # Download the last version of condor compatible with centOS7
    wget http://research.cs.wisc.edu/htcondor/yum/repo.d/htcondor-stable-rhel7.repo -O /etc/yum.repos.d/htcondor-stable-rhel7.repo
  
    wget http://cvmrepo.web.cern.ch/cvmrepo/yum/cernvm.repo -O /etc/yum.repos.d/cernvm.repo 
    wget http://cvmrepo.web.cern.ch/cvmrepo/yum/RPM-GPG-KEY-CernVM -O /etc/pki/rpm-gpg/RPM-GPG-KEY-CernVM 

    rpm --import http://emisoft.web.cern.ch/emisoft/dist/EMI/3/RPM-GPG-KEY-emi 

    cat << EOF >  /etc/yum.repos.d/slc7-extras.repo
[slc7-extras]
name=Scientific Linux CERN 7 (SLC7) add-on packages
baseurl=http://linuxsoft.cern.ch/cern/centos/7/extras/x86_64/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cern
gpgcheck=0
enabled=1
protect=1
EOF

  yum -y update
  yum -y install condor
  yum -y install http://linuxsoft.cern.ch/wlcg/centos7/x86_64/HEP_OSlibs-7.0.1-0.el7.cern.x86_64.rpm
  yum --nogpgcheck -y install yum-priorities yum-protectbase 
  yum -y install cvmfs 
  yum -y install cvmfs-init-scripts
  yum -y install epel-release 
  yum -y install redhat-lsb-core 
  yum -y install glibmm24 
  yum -y install openssl098e 
  yum --enablerepo=epel -y install xrootd-client
  yum --enablerepo=epel -y install xrootd-fuse
  yum -y localinstall http://linuxsoft.cern.ch/cern/slc61/i386/yum/extras/castor-lib-2.1.14-15.slc6.i686.rpm
  yum -y localinstall http://linuxsoft.cern.ch/cern/slc61/i386/yum/extras/castor-devel-2.1.14-15.slc6.i686.rpm 

}


function mount_cvmfs(){
    echo "
  ###############
  # Mount CVMFS #
  # `date`
  ###############
"

    # Deploy CVMFS configuration
cat <<EOF >/etc/cvmfs/default.local
CVMFS_REPOSITORIES=atlas.cern.ch,atlas-condb.cern.ch,grid.cern.ch
CVMFS_QUOTA_LIMIT=6000
CVMFS_CACHE_BASE=/scratch/cache/cvmfs2
CVMFS_MOUNT_RW=yes
CVMFS_HTTP_PROXY="http://squid.cern.ch:8060|http://ca-proxy.cern.ch:3128;DIRECT"
EOF

    # Disable SELinux
    [ -d /selinux ] && echo 0 > /selinux/enforce
  	
    #TODO: Possible solution to resolve the cvmfs stuck
    mounted_cvmfs=`mount | grep "cvmfs2" | wc -l`
    autofs_inactive=`service autofs status | grep Active | grep inactive | wc -l`
    if [[ $mounted_cvmfs != 0 && $autofs_inactive != 0 ]]; then
      umount /cvmfs/atlas.cern.ch
      umount /cvmfs/atlas-condb.cern.ch
      umount /cvmfs/grid.cern.ch
    fi
    
    # TODO: if run script more than once, CVMFS gets stuck while pausing repositories
    cvmfs_config setup 
    cvmfs_config reload 
    service autofs restart 
    chkconfig autofs on

    # Try mounting CVMFS
    echo "Mounting CVMFS..."
    cvmfs_probe=`cvmfs_config probe | grep "Failed" | wc -l`
    if [ $cvmfs_probe != 0 ]; then
        # autofs is not working, try to mount cvmfs manually
        echo "cvmfs_probe has failed. Trying to mount CVMFS manually..."
        service autofs stop 
        chmod g+rw /dev/fuse
        mkdir -p /cvmfs/atlas.cern.ch 
        mkdir -p /cvmfs/atlas-condb.cern.ch 
        mkdir -p /cvmfs/grid.cern.ch 

        mount -t cvmfs atlas.cern.ch /cvmfs/atlas.cern.ch 
        mount -t cvmfs atlas-condb.cern.ch /cvmfs/atlas-condb.cern.ch 
        mount -t cvmfs grid.cern.ch /cvmfs/grid.cern.ch 

        cvmfs_probe=`cvmfs_config probe | grep "Failed" | wc -l`
        if [ $cvmfs_probe != 0 ]; then
            echo 'FAILED to mount CVMFS. Stopping script!' && exit 1
        fi
    fi

    echo '
  ###########################
  # Finished mounting CVMFS #
  ###########################
'
}

function run_kvkit(){
    echo "
  ##########
  # Run KV #
  # `date`
  ##########
"

    cd $DIR

    echo "Downloading sw-mgr..."
    wget https://kv.roma1.infn.it/KV/sw-mgr --no-check-certificate -O sw-mgr
    chmod u+x sw-mgr

    # Only for ATLAS
    export VO_ATLAS_SW_DIR=/cvmfs/atlas.cern.ch/repo/sw
 
    echo "Loading information from CVMFS"

    # Hardcoded env sourcing. TODO: parametrize it
    source /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0/cmtsite/asetup.sh --dbrelease=current AtlasProduction 17.8.0.9 opt gcc46 slc6 64 || true

    SW_MGR_START=`date +"%y-%m-%d %H:%M:%S"`
    echo "Start KV Test ${SW_MGR_START}"

    KVSUITE=`grep -i "<kvsuite>" $KVBMK | head -1 | sed -E "s@.*>(.*)<.*@\1@"`
    KVBMK="file://$KVBMK"

    echo "-- Start KV --"
    ./sw-mgr -a 17.8.0.9-x86_64 --test 17.8.0.9 --no-tag -p /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0 --kv-disable ALL --kv-enable $KVSUITE --kv-conf $KVBMK --kv-keep --kvpost --kvpost-tag $KVTAG --tthreads $KVTHR 
    [ $? -ne 0 ] && echo "KV test FAILED. Please check log" >&3  && exit 1

    TESTDIR=`ls -tr | grep kvtest_ | tail -1`
    SW_MGR_STOP=`date +"%y-%m-%d %H:%M:%S"`
    echo "-- End KV Test ${SW_MGR_STOP} --"

    PERFMONLOG=PerfMon_summary_`date +\%y-\%m-\%d_\%H:\%M:\%S`.out
    echo "host_ip: `hostname`" >> $PERFMONLOG
    echo "start sw-mgr ${SW_MGR_START}">> $PERFMONLOG
    echo "end sw-mgr ${SW_MGR_STOP}" >> $PERFMONLOG
    grep -H PerfMon $TESTDIR/KV.thr.*/data/*/*log >> $PERFMONLOG

    echo -e "\nBenchmark INFO for $CLOUD on $kernel" >&3
    grep -A1 "INFO Statistics for 'evt'" $TESTDIR/KV.thr.*/data/*/*log | grep "<cpu>" | awk 'BEGIN{amin=1000000;amax=0;}{count+=1; val=int($5)/1000.; sum+=val; if(amax<val) amax=val; if(amin>val) amin=val}END{print "\n***************************************************************************************************\nKV cpu performance [sec/evt]: avg " sum/count " over " count " threads. Min Value " amin " Max Value " amax "\n***************************************************************************************************"}' | tee -a $PERFMONLOG >&3
	
    echo '
  ###############
  # Finished KV #
  ###############
'
    echo "`date`: END OF SCRIPT"
}


# MAIN

echo -e "\tSTEP 2 OUT OF 5: Install (if needed) all necessary dependencies to run the benchmark..." >&3
echo -e "\t\tThis step could take up to 20 minutes! It is skipped when running cernVM. Check progress in ${LOG}" >&3


if [[ $kernel != *"cernvm"* ]]; then
    if [ $RUNINSTALL -ne 1 ]; then
        echo -e "\nWARN: The option -i was not specified\n"
        echo -e "\n------------------------------------------------
WARNING: -i was not specified
  You are not running CernVM.
  The -i option is highly recommended for non-CernVM instances.
  If you want to continue, the script will assume that all the required software and CVMFS configurations have already been applied in this machine.
  Continue KV benchmark without installing dependencies? (y/n)
------------------------------------------------" >&3

        read -p "Continue without installing dependencies?" -n 1 -r

        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            echo -e "\n" >&3
            echo -e "\n
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! Not installing dependencies !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
\n"
        else
            echo -e "\n\t\tInstalling dependencies..." >&3
            # Sensitive function as it returns error when packages are already installed
            time install_dependencies  || true      # | tee -a /root/run_install.out
            EXITSTATUS=$PIPESTATUS
            [ $EXITSTATUS -gt 0 ] && echo 'FAILED install dependencies. Stopping test' && exit 1 
        fi
    else
        # Sensitive function as it returns error when packages are already installed
        time install_dependencies  || true      # | tee -a /root/run_install.out
        EXITSTATUS=$PIPESTATUS
        [ $EXITSTATUS -gt 0 ] && echo 'FAILED install dependencies. Stopping test' && exit 1
    fi
fi


echo -e "\tSTEP 3 OUT OF 5: Mounting CernVM File System..." >&3
mount_cvmfs

echo -e "\tSTEP 4 OUT OF 5: Dumping necessary XML files to run KV benchmark..." >&3
dump_default_kvxml
#dump_Zjet_kvxml

echo -e "\tSTEP 5 OUT OF 5: Running KV benchmark!" >&3
echo -e "\t\tThis step can take 10-20 minutes." >&3
run_kvkit

cd
tar -czf KV_success.tgz /scratch/KV $LOG

echo "
#################
# END OF SCRIPT #
#################
Log at ${LOG}
" >&3
END=1
#!/usr/bin/env bash

# User requires sudo rights
BASE_FOLDER="EBI_cloud_testing"
DATA_FOLDER="data"

# Add pts and freebayes/bin to local path
PATH="$PATH:$HOME/$BASE_FOLDER/phoronix-test-suite"
PATH="$PATH:$HOME/$BASE_FOLDER/freebayes/bin"

#Define format string for the time command output
#UserModeTime:KernelModeTime:ElapsedRealTimeSec:CPUPercentage:NumSwappedOut:
#ContextSwitchedInvoluntarily
TIME_FORMAT_STRING="%U;%S;%e;%P;%W;%c"

function install_dependencies() {
  #Update yum cache
  sudo yum makecache fast

  #Phoronix
  sudo yum -y install git php php-xml xdg-utils bc epel-release

  #Freebayes (needs to be compiled)
  sudo yum -y group install "Development Tools"
  sudo yum -y install zlib-devel cmake

  #GridFTP
  sudo yum -y install udt

  #Time and wget packages
  sudo yum -y install time wget
}

function install_phoronix() {
  printf "PHORONIX: Cloning Phoronix git repo...\n" | tee -a $LOG >&3
  # get the latest stable version of phoronix test suite
  git clone https://github.com/phoronix-test-suite/phoronix-test-suite.git
  cd phoronix-test-suite || exit
  git checkout tags/v5.8.1
  cd ..

  printf "PHORONIX: Preparing Phoronix for batch tests...\n" | tee -a $LOG >&3
  # Accept terms of pts (Y)
  echo "Y" | phoronix-test-suite batch-setup

  # Collect information about local system
  phoronix-test-suite system-info > $RESULTS_FOLDER/$LOG_PREFIX"_system-info"

  # Configure pts to run in batch mode
  sed -i \
  -e 's/<SaveResults>FALSE/<SaveResults>TRUE/' \
  -e 's/<OpenBrowser>TRUE/<OpenBrowser>FALSE/' \
  -e 's/<UploadResults>TRUE/<UploadResults>FALSE/' \
  -e 's/<PromptForTestIdentifier>TRUE/<PromptForTestIdentifier>FALSE/' \
  -e 's/<PromptForTestDescription>TRUE/<PromptForTestDescription>FALSE/' \
  -e 's/<PromptSaveName>TRUE/<PromptSaveName>FALSE/' \
  -e 's/<RunAllTestCombinations>FALSE/<RunAllTestCombinations>TRUE/' \
  -e 's/<Configured>FALSE/<Configured>TRUE/' \
  ~/.phoronix-test-suite/user-config.xml
}

function run_phoronix() {
  printf "PHORONIX: Running tests (this will take up to 2hrs, depending on the VM performance)\n" | tee -a $LOG >&3
  # Run chosen phoronix tests
  TEST_RESULTS_NAME="phoronixtests" phoronix-test-suite batch-benchmark smallpt build-linux-kernel c-ray sqlite fourstones pybench

  #Export results in JSON
  phoronix-test-suite result-file-to-json "phoronixtests" > $RESULTS_FOLDER/$LOG_PREFIX"_phoronix_results.json"
}

function install_freebayes() {
  printf "FREEBAYES: Cloning Freebayes repo and compiling it\n" | tee -a $LOG >&3
  # Clone freebayes repo
  git clone --recursive git://github.com/ekg/freebayes.git
  cd freebayes || exit
  git checkout tags/v0.9.21
  git submodule update --recursive
  cd ..

  # Compile it
  cd freebayes || exit
  make

  # Move to $DATA_FOLDER
  cd ../$DATA_FOLDER || exit

  # Get reference for chr20
  printf "FREEBAYES: Downloading chr20 from Ensembl\n" | tee -a $LOG >&3
  curl -O "ftp://ftp.ensembl.org/pub/release-82/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.chromosome.20.fa.gz" && gunzip Homo_sapiens.GRCh38.dna.chromosome.20.fa.gz

  # Back to $BASE_FOLDER
  cd ..

  # Get low cov 1MB BAM file for chr20 from EBI server
  printf "FREEBAYES: Copying BAM/BAI from EBI servers...\n" | tee -a $LOG >&3
  /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$LOG_PREFIX"_grid_bam.csv" globus-url-copy -vb "sshftp://$SERVER:$PORT/~/CEUTrio.NA12878.chr20.1MB.bam" "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/CEUTrio.NA12878.chr20.1MB.bam"
  /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$LOG_PREFIX"_grid_bai.csv" globus-url-copy -vb "sshftp://$SERVER:$PORT/~/CEUTrio.NA12878.chr20.1MB.bam.bai" "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/CEUTrio.NA12878.chr20.1MB.bam.bai"
}

function run_freebayes() {
   #Run Freebayes
   printf "FREEBAYES: Calling variants with Freebayes (this will take a while, ~20 mins)\n" | tee -a $LOG >&3
   /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$LOG_PREFIX"_freebayes.csv" ./freebayes/bin/freebayes --fasta $DATA_FOLDER/Homo_sapiens.GRCh38.dna.chromosome.20.fa $DATA_FOLDER/CEUTrio.NA12878.chr20.1MB.bam -v $RESULTS_FOLDER/variants.vcf
}

function install_gridftp() {
    # Add Globus GridFTP repos
    sudo rpm -U  --replacepkgs https://downloads.globus.org/toolkit/gt6/stable/installers/repo/rpm/globus-toolkit-repo-latest.noarch.rpm

    # Install GridFTP
    sudo yum -y install globus-gridftp

    mkdir -p ~/.ssh
    cat <<EOF > ~/.ssh/config

    Host $SERVER
      StrictHostKeyChecking no
      User          $USERNAME
      HostName      $SERVER
      IdentityFile  $KEYPAIR
      Port          $PORT
EOF

    # Set ~/.ssh/config permissions
    chmod 600 ~/.ssh/config

  }

function run_gridftp() {
  printf "GRIDFTP: Running GridFTP speed test...\n" | tee -a $LOG >&3
  printf "GRIDFTP: Moving data in...\n" | tee -a $LOG >&3
  /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$LOG_PREFIX"_grid_test_time_in.csv" globus-url-copy -vb "sshftp://$SERVER:$PORT/~/test_file.dat" "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/test_file.dat" > $RESULTS_FOLDER/$LOG_PREFIX"_grid_test_in.log"
  printf "GRIDFTP: Done.\n" | tee -a $LOG >&3
  printf "GRIDFTP: Moving data out...\n" | tee -a $LOG >&3
  /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$LOG_PREFIX"_grid_test_time_out.csv" globus-url-copy -vb "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/test_file.dat" "sshftp://$SERVER:$PORT/~/test_file2.dat"> $RESULTS_FOLDER/$LOG_PREFIX"_grid_test_out.log"
  printf "GRIDFTP: Moving in-memory data out\n" | tee -a $LOG >&3
  printf "GRIDFTP: Creating the file to be transferred\n" | tee -a $LOG >&3
  dd if=/dev/urandom of=$HOME/$BASE_FOLDER/$DATA_FOLDER/in-memory.dat bs=1G count=1
  printf "GRIDFTP: Transferring\n" | tee -a $LOG >&3
  /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$LOG_PREFIX"_grid_mtest_time_out.csv" globus-url-copy -vb "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/in-memory.dat" "sshftp://$SERVER:$PORT/~/in-memory.dat"> $RESULTS_FOLDER/$LOG_PREFIX"_grid_mtest_out.log"
  rm $HOME/$BASE_FOLDER/$DATA_FOLDER/in-memory.dat
  printf "GRIDFTP: GridFTP speed test completed.\n" | tee -a $LOG >&3
}

function call_home() {
  #Compress $RESULTS_FOLDER
  printf "CALLHOME: Compressing results...\n" | tee -a $LOG >&3
  archive_name="$LOG_PREFIX"_$(date +'%y-%m-%d_%H%M%S')_results.tar.gz
  tar -zcvf "$archive_name" $RESULTS_FOLDER > /dev/null

  printf "CALLHOME: Calling home...\n" | tee -a $LOG >&3
  #Send everything back home via GridFTP
  globus-url-copy "file:///$HOME/$BASE_FOLDER/$archive_name" "sshftp://$SERVER:$PORT/~/$archive_name"
  printf "CALLHOME: Hanging up...\n" | tee -a $LOG >&3
  printf "CALLHOME: Done!\n" | tee -a $LOG >&3
}

# MAIN
# Help display
usage='Usage:
 ebi-cloud-testing.sh [OPTIONS]

OPTIONS:
--cloud=<cloud>
Cloud name to identify the results - REQUIRED
--flavor=<flavor>
Flavor name to identify the results - REQUIRED
--user=<user>
User to connect with to the EBI GridFTP instance - REQUIRED
--keypair=<key_path>
Absolute path to key needed for SSH auth - REQUIRED
--server=<server>
Hostname of the remote EBI server to use for network testing - REQUIRED
--port=<port>
Network port of the remote EBI server to use for network testing - REQUIRED
--call-home
Enables call-home: test results will be sent back to EMBL-EBI.
'

printf '
  #######################################
  ###  EBI Cloud Benchmarking script  ###
  ###				      ###
  ### Contacts:		              ###
  ###  gianni@ebi.ac.uk               ###
  ###  dario@ebi.ac.uk                ###
  #######################################
'


while [ "$1" != "" ]; do
    case $1 in
        --cloud=* )      CLOUD=${1#*=};
	               ;;
        --flavor=* )     FLAVOR=${1#*=};
         	       ;;
        --server=* )     SERVER=${1#*=};
         	       ;;
        --port=* )       PORT=${1#*=};
        	       ;;
        --user=* )       USERNAME=${1#*=};
       	         ;;
        --keypair=* )    KEYPAIR=${1#*=};
                 ;;
        --call-home)     CALL_HOME=true;
                 ;;
        * )         printf "${usage}"
                    exit 1
    esac
    shift
done

# CLOUD must be defined
if [ -z $CLOUD ] || [ $CLOUD == "" ];then
  printf "%s" "${usage}"
  printf '\n\nERROR: please provide a cloud name. Exiting now.\n' && exit 1
fi

if [ -z $FLAVOR ] || [ $FLAVOR == "" ];then
  printf "%s" "${usage}"
  printf '\n\nERROR: please provide a flavor name. Exiting now.\n' && exit 1
fi

if [ -z $SERVER ] || [ $SERVER == "" ];then
  printf "%s" "${usage}"
  printf "\n\nERROR: please provide the server name SSH should connect to. Exiting now.\n" && exit 1
fi

# USERNAME must be defined
if [ -z $USERNAME ] || [ $USERNAME == "" ];then
  printf "%s" "${usage}"
  printf "\n\nERROR: please provide a username to set SSH config with. Exiting now.\n" && exit 1
fi

# KEYPAIR must be defined
if [ -z $KEYPAIR ] || [ $KEYPAIR == "" ];then
  printf "%s" "${usage}"
  printf "\n\nERROR: please provide a keypair to set SSH config with. Exiting now.\n" && exit 1
fi

# Check that KEYPAIR is an absolute path
KEYPAIR="${KEYPAIR/#\~/$HOME}"
if [[ "$KEYPAIR" != /* ]]
  then
    printf "\n\nERROR: please provide an ABSOLUTE path to the keypair. Exiting now.\n" && exit 1
fi

# PORT must be defined
if [ -z $PORT ] || [ $PORT == "" ];then
  printf "%s" "${usage}"
  printf "\n\nERROR: please provide a port to set SSH config with. Exiting now.\n" && exit 1
fi

printf "\n\nUsing cloud name %s, flavor %s\n\n" "$CLOUD" "$FLAVOR"
LOG_PREFIX="$CLOUD"_"$FLAVOR"
RESULTS_FOLDER="$LOG_PREFIX"_results

# Check kernel release. Must be el7.
kernel=`uname -r`

if [[ $kernel != *"el7"* ]]; then
  printf "\nWARNING:
  Your kernel release is different from el7!\n
  This benchmarking script is based on a el7 reference configuration.\n
  "
fi

# Exit when any command fails. To allow failing commands, add "|| true"
set -o errexit

if [ -d "$HOME/$BASE_FOLDER" ]; then
  printf "WARNING: base folder already exists! (%s). Getting rid of it.\n" "$BASE_FOLDER"
  rm -rf ~/$BASE_FOLDER
fi
# Create folders structure.
mkdir -p ~/$BASE_FOLDER/$DATA_FOLDER
mkdir -p ~/$BASE_FOLDER/$RESULTS_FOLDER

LOG="$HOME/$BASE_FOLDER/$RESULTS_FOLDER/$LOG_PREFIX"_`date +\%y-\%m-\%d_\%H:\%M:\%S`.log
printf "Complete log of this run is available at: %s\n" "$LOG"

if [ -d "$HOME/.phoronix-test-suite" ]; then
  printf "WARNING: ~/.phoronix-test-suite folder already exists! Getting rid of it.\n"
  rm -rf ~/phoronix-test-suite
fi

# Saves file descriptors for later being restored
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
# Redirect stdout and stderr to a log file
exec 1>>$LOG 2>&1

# From now on, normal stdout output should be appended with ">&3". We use tee
# to redirect both to stdout and the general log file
printf "\n\n---\nSTEP 1 - Installation\n---\n\n\n" | tee -a $LOG >&3
cd $BASE_FOLDER || exit
printf "Installing dependencies\n" | tee -a $LOG >&3
install_dependencies
printf "Installing GridFTP-Lite\n" | tee -a $LOG >&3
install_gridftp
printf "\nInstalling Phoronix Test Suite\n" | tee -a $LOG >&3
install_phoronix
printf "\nInstalling Freebayes and getting benchmarking data\n" | tee -a $LOG >&3
install_freebayes

printf "\n\n---\nSTEP 2 - Run tests\n---\n" | tee -a $LOG >&3
run_gridftp
run_phoronix
run_freebayes

printf "\n\n---\nSTEP 3 - Call home!\n---\n" | tee -a $LOG >&3
if [ "$CALL_HOME" = true ]; then
  call_home
  printf "Results were successfully sent to EMBL-EBI!"
else
  printf "\n\n---\nCall home is disabled for this run. Keeping data local.\n---\n" | tee -a $LOG >&3
fi

printf "DONE!\n"

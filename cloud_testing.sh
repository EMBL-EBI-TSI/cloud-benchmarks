#!/usr/bin/env bash

# User requires sudo rights

#TODO: use an ad-hoc folder named after the cloud we're testing, or add a
#prefix to all files
BASE_FOLDER="EBI_cloud_testing"
DATA_FOLDER="data"

#Define format string for the time command output
#UserModeTime:KernelModeTime:ElapsedRealTimeSec:CPUPercentage:AverageTotMemory:
#NumSwappedOut:ContextSwitchedInvoluntarily
TIME_FORMAT_STRING="%U;%S;%e;%P;%K;%W;%c"

function install_dependencies() {
  #Update yum cache
  sudo yum makecache fast

  #Phoronix
  sudo yum -y install git php php-xml xdg-utils

  #Freebayes (needs to be compiled)
  sudo yum -y group install "Development Tools"
  sudo yum -y install zlib-devel cmake
}

function install_phoronix() {
  # get the latest stable version of phoronix test suite
  git clone https://github.com/phoronix-test-suite/phoronix-test-suite.git

  # Add pts to local path
  PATH="$PATH:$HOME/$BASE_FOLDER/phoronix-test-suite"

  # Accept terms of pts (Y)
  echo "Y" | phoronix-test-suite batch-setup

  # Collect information about local system
  # phoronix-test-suite system-info

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
  # Run chosen phoronix tests
  # TEST_RESULTS_NAME=phoronix_tests phoronix-test-suite batch-benchmark smallpt build-linux-kernel c-ray sqlite fourstones pybench
  TEST_RESULTS_NAME=phoronixtests phoronix-test-suite batch-benchmark sqlite

  #Export results in JSON
  phoronix-test-suite result-file-to-json phoronixtests > $HOME/$BASE_FOLDER/$CLOUD"_phoronix_results.json"
}

function install_freebayes() {
  # Clone freebayes repo
  git clone --recursive git://github.com/ekg/freebayes.git

  # Compile it
  cd freebayes || exit
  make

  # Add freebayes/bin to $PATH
  PATH="$PATH:$HOME/$BASE_FOLDER/freebayes/bin"

  # Move to $DATA_FOLDER
  cd ../$DATA_FOLDER || exit

  # Get reference for chr20
  curl -O "http://hgdownload.cse.ucsc.edu/goldenPath/hg38/chromosomes/chr20.fa.gz" && gunzip chr20.fa.gz

  # chr20 -> 20
  sed -i 's/chr20/20/g' chr20.fa

  # Get low cov 1MB BAM file for chr20
  globus-url-copy -dbg "sshftp://$HOST:$PORT/~/CEUTrio.NA12878.chr20.1MB.bam" "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/CEUTrio.NA12878.chr20.1MB.bam"
  globus-url-copy -dbg "sshftp://$HOST:$PORT/~/CEUTrio.NA12878.chr20.1MB.bam.bai" "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/CEUTrio.NA12878.chr20.1MB.bam.bai"

  # Got the data. Go back to $BASE_FOLDER
  cd ..
}

function run_freebayes() {
   #Run freebayes
   echo "Calling variants with Freebayes"
   ./freebayes/bin/freebayes --fasta data/chr20.fa data/CEUTrio.NA12878.chr20.1MB.bam -v variants.vcf
}

function install_gridftp() {
    # Add Globus GridFTP repos
    sudo rpm -U  --replacepkgs http://toolkit.globus.org/ftppub/gt6/installers/repo/globus-toolkit-repo-latest.noarch.rpm

    # Install GridFTP
    sudo yum -y install globus-gridftp

    cat <<EOF > ~/.ssh/config

    Host $HOST
      User          $USER
      Hostname      $HOST
      IdentityFile  $KEYPAIR
      Port          $PORT
EOF

    # Set ~/.ssh/config permissions
    chmod 600 ~/.ssh/config

  }

# MAIN
# Help display
usage='Usage:
 ebi-cloud-testing.sh [OPTIONS]

OPTIONS:
\n --cloud=<cloud>
\t Cloud name to identify the results - REQUIRED
\n --user=<user>
\t User to connect with to EBI GridFTP instance - REQUIRED
\n --keypair=<key_path>
\t Absolute path to key needed for SSH auth - REQUIRED
'

echo '
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
        --cloud=* )    CLOUD=${1#*=};
	               ;;
        --host=* )     HOST=${1#*=};
         	       ;;
        --port=* )     PORT=${1#*=};
        	       ;;
        --user=* )     USER=${1#*=};
       	         ;;
        --keypair=* )  KEYPAIR=${1#*=};
                 ;;
        * )         echo -e "${usage}"
                    exit 1
    esac
    shift
done

# CLOUD must be defined
if [ -z $CLOUD ] || [ $CLOUD == "" ];then
    echo -e "${usage}"
    echo -e '\n\nERROR: please provide a cloud name. Exiting now.\n' && exit 1
fi

if [ -z $HOST ] || [ $HOST == "" ];then
    echo -e "${usage}"
    echo -e '\n\nERROR: please provide the hostname SSH should connect to. Exiting now.\n' && exit 1
fi

# USER must be defined
if [ -z $USER ] || [ $USER == "" ];then
    echo -e "${usage}"
    echo -e '\n\nERROR: please provide a username to set SSH config with. Exiting now.\n' && exit 1
fi

# KEYPAIR must be defined
if [ -z $KEYPAIR ] || [ $KEYPAIR == "" ];then
    echo -e "${usage}"
    echo -e '\n\nERROR: please provide a keypair to set SSH config with. Exiting now.\n' && exit 1
fi

# PORT must be defined
if [ -z $PORT ] || [ $PORT == "" ];then
    echo -e "${usage}"
    echo -e '\n\nERROR: please provide a port to set SSH config with. Exiting now.\n' && exit 1
fi

echo -e "Using cloud name: $CLOUD"

# Exit when any command fails. To allow failing commands, add "|| true"
set -o errexit

if [ -d "$HOME/$BASE_FOLDER" ]; then
  echo "WARNING: base folder already exists! ($BASE_FOLDER). Getting rid of it."
  rm -rf ~/$BASE_FOLDER
fi

if [ -d "$HOME/.phoronix-test-suite" ]; then
  echo "WARNING: ~/.phoronix-test-suite folder already exits! Getting rid of it."
  rm -rf ~/phoronix-test-suite
fi

# Create folders structure in one go.
mkdir -p ~/$BASE_FOLDER/$DATA_FOLDER

LOG="$HOME/$BASE_FOLDER/cloud_testing_`date +\%y-\%m-\%d_\%H:\%M:\%S`.log"

# Saves file descriptors for later being restored
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
# Redirect stdout and stderr to a log file
exec 1>$LOG 2>&1

# From now on, normal stdout output should be appended with ">&3". e.g.:
echo "STEP 1 - Install tools and dependencies"
echo "INSTALLING DEPENDENCIES"
cd $BASE_FOLDER || exit
install_dependencies
# echo "INSTALLING PHORONIX TEST SUITE"
# install_phoronix
# echo "INSTALL FREEBAYES AND GET DATA"
# install_freebayes
echo "INSTALL GRIDFTP-LITE"
install_gridftp

#echo "STEP 2 - Running tests"
#run_phoronix

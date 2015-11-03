#!/usr/bin/env bash

# User requires sudo rights

#TODO: use an ad-hoc folder named after the cloud we're testing, or add a
#prefix to all files
BASE_FOLDER="ebi_cloud_testing"
LOG="$HOME/$BASE_FOLDER/cloud_testing_`date +\%y-\%m-\%d_\%H:\%M:\%S`.log"

#File descriptors redirects
exec 3>&1 4>&2

#Redirect STDOUT to log file
exec 1>$LOG 2>&1



function install_dependencies() {
  #Update yum cache
  sudo yum makecache fast

  #Phoronix
  sudo yum -y install git php php-xml xdg-utils
}

function install_phoronix() {
  # get the latest stable version of phoronix test suite
  git clone https://github.com/phoronix-test-suite/phoronix-test-suite.git

  # Add pts to local path
  PATH="$PATH:$HOME/phoronix-test-suite"

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

  # Install the dependency for the test
}

function run_phoronix() {
  #Run chosen phoronix tests
  TEST_RESULTS_NAME=test_result phoronix-test-suite batch-benchmark smallpt build-linux-kernel c-ray sqlite fourstones pybench

  #Write results in JSON
  phoronix-test-suite result-file-to-json test_result > ~/test_result.json
}

function install_freebayes() {
  #Clone freebayes repo
  git clone --recursive git://github.com/ekg/freebayes.git
  #Get reference for chr20
  wget "http://hgdownload.cse.ucsc.edu/goldenPath/hg38/chromosomes/chr20.fa.gz" && gunzip chr20.fa.gz

  #Get low cov 1MB BAM file for chr20
  #TODO: how to get this?

}

# function run_freebayes() {
#   #Run freebayes
#
# }

# MAIN
# Help display
usage='Usage:
 ebi-cloud-testing.sh [OPTIONS]

OPTIONS:
\n --cloud=<cloud>
\t Cloud name to identify the results - REQUIRED
'

# From now on, normal stdout output should be appended with ">&3". e.g.:
echo '
  #######################################
  ###  EBI Cloud Benchmarking script  ###
  ###				      ###
  ### Contacts:		              ###
  ###  gianni@ebi.ac.uk               ###
  ###  dario@ebi.ac.uk                ###
  #######################################
  Final log: '$LOG'
  #######################################
' >&3

while [ "$1" != "" ]; do
    case $1 in
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
    echo -e '\n\nERROR: please provide a cloud name. Exiting now.\n' >&3 && exit 1
fi

echo -e "Using cloud name: $CLOUD" >&3

# Exit when any command fails. To allow failing commands, add "|| true"
set -o errexit

if [ -d "$HOME/$BASE_FOLDER/cloud_testing" ]; then
  echo "WARNING: old cloud_testing logs found. Getting rid of them"
  rm -r ~/cloud_testing
fi

if [ -d "$HOME/phoronix-test-suite" ]; then
  echo "WARNING: old phoronix-test-suite folder found. Getting rid of it."
  rm -rf ~/phoronix-test-suite
fi

if [ -d "$HOME/.phoronix-test-suite" ]; then
  echo "WARNING: old ~.phoronix-test-suite folder found. Getting rid of it."
  rm -rf ~/phoronix-test-suite
fi

mkdir ~/cloud_testing




echo "STEP 1 - Install tools and dependencies"
echo "INSTALLING DEPENDENCIES"
install_dependencies
echo "INSTALLING PHORONIX TEST SUITE"
install_phoronix
echo "INSTALL FREEBAYES AND GET DATA"
install_freebayes

echo "STEP 2 - Running tests"
run_phoronix

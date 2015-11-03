#!/usr/bin/env bash

# User requires sudo rights

#TODO: use an ad-hoc folder named after the cloud we're testing, or add a
#prefix to all files
LOG="$HOME/cloud_testing/cloud_testing.log"

if [ -d "$HOME/cloud_testing" ]; then
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

#Redirect STDOUT to log file
exec 1>$LOG 2>&1

# Exit when any command fails. To allow failing commands, add "|| true"
set -o errexit


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
  TEST_RESULTS_NAME="test_folder" phoronix-test-suite batch-benchmark smallpt build-linux-kernel c-ray sqlite fourstones pybench

  #Write results in JSON
  phoronix-test-suite result-file-to-json cloudtests > ~/cloudtests.json
}

# MAIN
echo "STEP 1 - Install tools and dependencies"
echo "INSTALLING DEPENDENCIES"
install_dependencies
echo "INSTALLING PHORONIX TEST SUITE"
install_phoronix
run_phoronix

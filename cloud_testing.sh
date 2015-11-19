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
  sudo yum -y install git php php-xml xdg-utils bc

  #Freebayes (needs to be compiled)
  sudo yum -y group install "Development Tools"
  sudo yum -y install zlib-devel cmake

  #Time and wget packages
  sudo yum -y install time wget
}

function install_phoronix() {
  printf "PHORONIX: Cloning Phoronix git repo...\n" >&3
  # get the latest stable version of phoronix test suite
  git clone https://github.com/phoronix-test-suite/phoronix-test-suite.git
  cd phoronix-test-suite || exit
  git checkout tags/v5.8.1
  cd ..

  # Add pts to local path
  PATH="$PATH:$HOME/$BASE_FOLDER/phoronix-test-suite"

  printf "PHORONIX: Preparing Phoronix for batch tests...\n" >&3
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
  printf "PHORONIX: Running tests (this will take a while, ~30mins)\n" >&3
  # Run chosen phoronix tests
  # TEST_RESULTS_NAME=phoronix_tests phoronix-test-suite batch-benchmark smallpt build-linux-kernel c-ray sqlite fourstones pybench
  TEST_RESULTS_NAME=phoronixtests phoronix-test-suite batch-benchmark sqlite

  #Export results in JSON
  phoronix-test-suite result-file-to-json phoronixtests > $RESULTS_FOLDER/$CLOUD"_phoronix_results.json"
}

function install_freebayes() {
  printf "FREEBAYES: Cloning Freebayes repo and compiling it\n" >&3
  # Clone freebayes repo
  git clone --recursive git://github.com/ekg/freebayes.git
  cd freebayes || exit
  git checkout tags/v0.9.21
  cd ..

  # Compile it
  cd freebayes || exit
  make

  # Add freebayes/bin to $PATH
  PATH="$PATH:$HOME/$BASE_FOLDER/freebayes/bin"

  # Move to $DATA_FOLDER
  cd ../$DATA_FOLDER || exit

  # Get reference for chr20
  printf "FREEBAYES: Downloading chr20 from Ensembl\n" >&3
  curl -O "ftp://ftp.ensembl.org/pub/release-82/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.chromosome.20.fa.gz" && gunzip Homo_sapiens.GRCh38.dna.chromosome.20.fa.gz

  # Back to $BASE_FOLDER
  cd ..

  # Get low cov 1MB BAM file for chr20 from EBI server
  printf "FREEBAYES: Copying BAM/BAI from EBI servers...\n" >&3
  /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$CLOUD"_grid_bam.csv" globus-url-copy -vb "sshftp://$HOST:$PORT/~/CEUTrio.NA12878.chr20.1MB.bam" "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/CEUTrio.NA12878.chr20.1MB.bam"
  /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$CLOUD"_grid_bai.csv" globus-url-copy -vb "sshftp://$HOST:$PORT/~/CEUTrio.NA12878.chr20.1MB.bam.bai" "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/CEUTrio.NA12878.chr20.1MB.bam.bai"
}

function run_freebayes() {
   #Run Freebayes
   printf "FREEBAYES: Calling variants with Freebayes (this will take a while, ~20 mins)\n" >&3
   /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$CLOUD"_freebayes.csv" ./freebayes/bin/freebayes --fasta $DATA_FOLDER/Homo_sapiens.GRCh38.dna.chromosome.20.fa $DATA_FOLDER/CEUTrio.NA12878.chr20.1MB.bam -v $RESULTS_FOLDER/variants.vcf
}

function install_gridftp() {
    # Add Globus GridFTP repos
    sudo rpm -U  --replacepkgs http://toolkit.globus.org/ftppub/gt6/installers/repo/globus-toolkit-repo-latest.noarch.rpm

    # Install GridFTP
    sudo yum -y install globus-gridftp

    cat <<EOF > ~/.ssh/config

    Host $HOST
      StrictHostKeyChecking no
      User          $USER
      Hostname      $HOST
      IdentityFile  $KEYPAIR
      Port          $PORT
EOF

    # Set ~/.ssh/config permissions
    chmod 600 ~/.ssh/config

  }

function run_gridftp() {
  printf "GRIDFTP: Running GridFTP speed test...\n" >&3
  printf "GRIDFTP: Moving data in...\n" >&3
  /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$CLOUD"_grid_test_time_in.csv" globus-url-copy -vb "sshftp://$HOST:$PORT/~/test_file.dat" "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/test_file.dat" > $RESULTS_FOLDER/$CLOUD"_grid_test_in.csv"
  printf "GRIDFTP: Done.\n" >&3
  printf "GRIDFTP: Moving data out...\n" >&3
  /usr/bin/time -f $TIME_FORMAT_STRING -o $RESULTS_FOLDER/$CLOUD"_grid_test_time_out.csv" globus-url-copy -vb "file:///$HOME/$BASE_FOLDER/$DATA_FOLDER/test_file.dat" "sshftp://$HOST:$PORT/~/test_file2.dat"> $RESULTS_FOLDER/$CLOUD"_grid_test_out.csv"
  printf "GRIDFTP: GridFTP speed test completed.\n" >&3
}

function call_home() {
  #Compress $RESULTS_FOLDER
  printf "CALLHOME: Compressing results...\n" >&3
  archive_name=$CLOUD-"$(date +'%y-%m-%d_%H%M%S')"_results.tar.gz
  tar -zcvf "$archive_name" $RESULTS_FOLDER > /dev/null

  printf "CALLHOME: Calling home...\n" >&3
  #Send everything back home via GridFTP
  globus-url-copy "file:///$HOME/$BASE_FOLDER/$archive_name" "sshftp://$HOST:$PORT/~/$archive_name"
  printf "CALLHOME: Hanging up...\n" >&3
  printf "CALLHOME: Done!\n" >&3
}

# MAIN
# Help display
usage='Usage:
 ebi-cloud-testing.sh [OPTIONS]

OPTIONS:
\n --cloud=<cloud>
\t Cloud name to identify the results - REQUIRED
\n --user=<user>
\t User to connect with to the EBI GridFTP instance - REQUIRED
\n --keypair=<key_path>
\t Absolute path to key needed for SSH auth - REQUIRED
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
        * )         printf -e "${usage}"
                    exit 1
    esac
    shift
done

# CLOUD must be defined
if [ -z $CLOUD ] || [ $CLOUD == "" ];then
  printf "%s" "${usage}"
  printf '\n\nERROR: please provide a cloud name. Exiting now.\n' && exit 1
fi

if [ -z $HOST ] || [ $HOST == "" ];then
  printf "%s" "${usage}"
  printf "\n\nERROR: please provide the hostname SSH should connect to. Exiting now.\n" && exit 1
fi

# USER must be defined
if [ -z $USER ] || [ $USER == "" ];then
  printf "%s" "${usage}"
  printf "\n\nERROR: please provide a username to set SSH config with. Exiting now.\n" && exit 1
fi

# KEYPAIR must be defined
if [ -z $KEYPAIR ] || [ $KEYPAIR == "" ];then
  printf "%s" "${usage}"
  printf "\n\nERROR: please provide a keypair to set SSH config with. Exiting now.\n" && exit 1
fi

# PORT must be defined
if [ -z $PORT ] || [ $PORT == "" ];then
  printf "%s" "${usage}"
  printf "\n\nERROR: please provide a port to set SSH config with. Exiting now.\n" && exit 1
fi

printf "\n\nUsing cloud name: %s\n\n" "$CLOUD"
RESULTS_FOLDER=$CLOUD"_results"

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

LOG="$HOME/$BASE_FOLDER/$RESULTS_FOLDER/cloud_testing_`date +\%y-\%m-\%d_\%H:\%M:\%S`.log"
printf "Complete log of this run is available at: %s" "$LOG"

if [ -d "$HOME/.phoronix-test-suite" ]; then
  printf "WARNING: ~/.phoronix-test-suite folder already exits! Getting rid of it.\n"
  rm -rf ~/phoronix-test-suite
fi

# Saves file descriptors for later being restored
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
# Redirect stdout and stderr to a log file
exec 1>$LOG 2>&1

# From now on, normal stdout output should be appended with ">&3". e.g.:
printf "\n\n---\nSTEP 1 - Installation\n---\n\n\n" >&3
cd $BASE_FOLDER || exit
printf "Installing dependencies\n" >&3
install_dependencies
printf "Installing GridFTP-Lite\n" >&3
install_gridftp
printf "\nInstalling Phoronix Test Suite\n" >&3
install_phoronix
printf "\nInstalling Freebayes and getting benchmarking data\n" >&3
install_freebayes

printf "\n\n---\nSTEP 2 - Run tests\n---\n" >&3
# run_phoronix
# run_freebayes
# run_gridftp

printf "\n\n---\nSTEP 3 - Call home!\n---\n" >&3
call_home

printf "DONE!\n"
printf "Results were successfully sent to EMBL-EBI!"

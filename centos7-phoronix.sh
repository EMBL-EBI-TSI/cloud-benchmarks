# install dependencies
sudo yum -y install git
sudo yum -y install php
sudo yum -y install php-xml
sudo yum -y install xdg-utils

# get the latest stable version of phoronix test suite
git clone https://github.com/phoronix-test-suite/phoronix-test-suite.git

# install pts
cd phoronix-test-suite/
./install-sh ~/pts
cd ~/pts

# Add pts to local path 
PATH="$PATH:~/pts/bin"

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
-e 's/<PromptSaveName>FALSE/<PromptSaveName>TRUE/' \
-e 's/<RunAllTestCombinations>FALSE/<RunAllTestCombinations>TRUE/' \
-e 's/<Configured>FALSE/<Configured>TRUE/' \
~/.phoronix-test-suite/user-config.xml

# Install the dependency for the test
sudo ~/pts/bin/phoronix-test-suite install sqlite
# Run the test and save the results as batch_tests
echo "cloudtests" | phoronix-test-suite batch-benchmark sqlite
# Run more benchmarks in a run
# echo "cloudtests" | phoronix-test-suite batch-benchmark smallpt build-linux-kernel c-ray sqlite fourstones pybench 
# Export results in json file (use cvs if php < 5.4, i.e. Centos 6)
phoronix-test-suite  result-file-to-json cloudtests > ~/cloudtests.json

# Information about significant tests:
# smallpt
# Processor. Smallpt is a C++ global illumination renderer written in less than 100 lines of code.
# Time: 6 minutes

# build-linux-kernel
# This test times how long it takes to build the Linux 3.18 kernel.
# Time: 7 minutes

# c-ray
# This is a test of C-Ray, a simple raytracer designed to test the floating-point CPU performance.
# Time: 2 minutes

# sqlite
# This is a simple benchmark of SQLite.
# Time: 1 minute

# fourstones
# Processor - This integer benchmark solves positions in the game of connect-4, as played on a vertical 7x6 board.
# Time: 7 minutes

# pybench
# This test profile reports the total time of the different average timed test results from PyBench. 
# Time: 3 minutes

# pts/iozone
# The IOzone benchmark tests the hard disk drive / file-system performance.
# Time: 4 Hours

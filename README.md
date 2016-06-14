# EMBL-EBI Cloud Benchmarking script


## Introduction
The [EMBL-EBI](http://www.ebi.ac.uk/) Cloud benchmarking script is used by EMBL-EBI to establish a number of metrics that can be used to assess a cloud provider for running EMBL-EBI use cases.

The script is made by a stand-alone bash script that leverages several tests to understand the performances of the underlying infrastructure. At the time of writing, the following tests are included:

- [Phoronix Test Suite](http://www.phoronix-test-suite.com/) to deliver a set of strictly IT-related tests with a particular focus on stressing CPUs.
- Network connectivity via [GridFTP](http://toolkit.globus.org/toolkit/docs/latest-stable/gridftp/) transfers from and to an EBI server.
- As a proxy for bioinformatic-specific workloads, variants are called on a publicly available 1MB-long chunk of the Human Chr20 with [FreeBayes](https://github.com/ekg/freebayes).

***

## The details

### Requirements

All the tools are automatically installed and executed by the benchmarking script, which assumes (and verifies) to be executed in a CentOS 7 environment. The user running it **must have sudo rights** and its password will be asked to escalate privileges, unless the user has also NOPASSWD rights.

**No other OS is currently supported** and failure to comply may alter or block tests execution. It is recommended to update the system to the latest packages via `yum update` prior to execution.

Network connectivity of the Cloud Provider towards EMBL-EBI data centers is tested via GridFTP transfers. To achieve this, some form of authentication is needed. This benchmarking script adopts [GridFTP lite](http://toolkit.globus.org/toolkit/data/gridftp/) to overcome the limitations given by the certificates needed to empower full-blown GridFTP servers, as it exploits SSH to carry out authentication. To allow EBI staff to properly authorize in advance the connection, prospect users must provide the public part of a SSH keypair to be used in the SSH authentication mechanism. `Hostname` and `port` to be used for the connection, as well as the assigned `username`, will be provided by EBI staff as soon as the `public key` is be uploaded to the server and the relevant user/permission established. Ports from `50000` to `50100` must accept TCP traffic from the outside to allow for GridFTP connections. The benchmarking process require `20GB` of available space in the root partition of the virtual machine running it.

The script can be freely downloaded from [here](https://github.com/EMBL-EBI-TSI/cloud-benchmarks). It does need a number of options specified at launch time to correctly carry out the test, as follows:

### Options

Mandatory options | Description
---- | ----
`--cloud <value>` | The name of the cloud provider running the test, this is chosen by the cloud provider itself.<p> It may or may not coincide with the username assigned by EMBL-EBI
`--flavor <value>` | The flavor of the VM the test is running on.<p> Please note that, as part of the test, statistics regarding available resources are acquired
`--keypair <value>` | The absolute path to the cloud provider private key.<p> This should match the public key provided to EMBL-EBI for authentication
`--port <value>` | The port of the EMBL-EBI server to connect to during the test.<p> This information will be provided by EMBL-EBI staff
`--server <value>` | The hostname of the EMBL-EBI server to o connect to during the test.<p> This information will be provided by EMBL-EBI staff
`--user <value>` | The username provided by EMBL-EBI that will be used for SSH authentication

Optional | Description
 ---- | ----
`--call-home` | If specified, test results will be sent back to the EMBL-EBI benchmark server


With all the options correctly specified, the full command to launch the script should resemble the following:

    ./cloud_testing.sh --cloud=<cloud_name> --flavor=<flavor_name>  --keypair=</path/to/keypair> \
      --port=<server_port_number> --server=<hostname> --user=<username> [--call-home]

When started, the script will proceed installing all the needed components, both from the official CentOS/EPEL repos and from code available on GitHub repositories. Once this preliminary step is completed, the tests will begin. The process can be followed directly in the terminal or using the verbose log file available at the path printed by the script itself at startup ("Complete log of this run is available at: \<path\>”). The exact execution time is difficult to predict, due to the intrinsic performance heterogeneity of different cloud providers, but is expected to be ~1.5hrs.

If the flag `--call-home` is specified, all the log files and test results will be automatically compressed and sent back to EMBL-EBI for analysis. Test results and logs can locally be found in the `$CLOUD_$FLAVOR` folder, within the main results folder `EBI_cloud_testing`.

It is obviously possible to re-run the script several times. However, to provide the same identical environment in each run, the script takes care of erasing compiled software left from the previous iteration at launch. This does not apply to packaged softwares (i.e. GridFTP executables provided by Globus’s repos), which is not reinstalled every time.

###  Executing the benchmark

It could be useful to install and use `screen` in order to avoid accidental benchmark interruption, caused by the disconnection of the shell/network:

    sudo yum -y install screen
    screen -R bench
Execute the benchmark in the new window:

    ./cloud_testing.sh --cloud=<cloud_name> --flavor=<flavor_name>  --keypair=</path/to/keypair> \
      --port=<server_port_number> --server=<hostname> --user=<username> [--call-home]
Press:  
`CONTROL`+ **a** + **d**  
to exit to the screen session, and:

    screen -R bench
to restore it.

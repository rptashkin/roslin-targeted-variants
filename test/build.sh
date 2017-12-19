#!/bin/bash
# path to lsf commands
# Set LSF env
export LSF_LIBDIR=/common/lsf/9.1/linux2.6-glibc2.3-x86_64/lib
export LSF_SERVERDIR=/common/lsf/9.1/linux2.6-glibc2.3-x86_64/etc
export LSF_BINDIR=/common/lsf/9.1/linux2.6-glibc2.3-x86_64/bin
export LSF_ENVDIR=/common/lsf/conf
export PATH=$PATH:/common/lsf/9.1/linux2.6-glibc2.3-x86_64/etc:/common/lsf/9.1/linux2.6-glibc2.3-x86_64/bin 
# Set python env
export PATH=/opt/common/CentOS_6-dev/python/python-2.7.10/bin/:/opt/common/CentOS_6-dev/bin/current/:$PATH
#Script will exit if a command exits with nonzero exit value
set -e
# genrate id for test build
printf "\n----------Starting----------\n"
#UUID=$(cat /proc/sys/kernel/random/uuid)
#printf "$UUID\n"
printf "Starting Build $BUILD_NUMBER"
# dynamically add it to the vagrant file
cp ../Vagrantfile ../Vagrantfile_test
sed -i '$ d' ../Vagrantfile_test
# set the config to point to the right workspace
installDir=/ifs/work/pi/roslin-test/targeted-variants/$BUILD_NUMBER
coreDir=$installDir/roslin-core
sed -i "s|/ifs/work/pi/roslin-pipelines|${installDir}/roslin-pipelines|g" config.variant.yaml
printf "  config.vm.provision \"shell\", run: \"always\", path: \"./test/build-images-and-cwl.sh\", args: \"%s\", privileged: false\nend" "$BUILD_NUMBER" >> ../Vagrantfile_test
## set vagrant path correctly
currentDir=$PWD
parentDir="$(dirname "$currentDir")"
export VAGRANT_CWD=$parentDir
export VAGRANT_VAGRANTFILE=Vagrantfile_test
# Set tmp and test directory
export TMPDIR="/srv/scratch/"
export TMP="/srv/scratch/"
export TOIL_LSF_ARGS='-S 1'
TempDir=/srv/scratch/$BUILD_NUMBER
TestDir=test_output/$BUILD_NUMBER
# Start vagrant to build the pipeline
printf "\n----------Building----------\n"
vagrant up
# check if build did not fail
cd ..
if [ $(ls $TestDir | grep -c "EXIT") -gt 0 ]
then
exit 1
fi
printf "\n----------Compressing----------\n"
# Compress pipeline
python test/compress.py $BUILD_NUMBER > $TestDir/compress_stdout.txt 2> $TestDir/compress_stderr.txt
printf "\n----------Setting up workspace----------\n"
# Create the test dir where the pipeline will be installed
mkdir $installDir
mkdir $coreDir
printf "\n----------Installing Core----------\n"
source core/config/settings.sh
# Set test specific core
sed -i 's|'${ROSLIN_CORE_ROOT}'|'${coreDir}'|g' core/config/settings.sh
# Load roslin core and pipeline
source core/config/settings.sh
source setup/config/settings.sh
# install core
cd core/bin/install
./install-core.sh
cd $currentDir
# Deploy
printf "\n----------Deploying----------\n"
pipeline_name="roslin-${ROSLIN_PIPELINE_NAME}-pipeline-v${ROSLIN_PIPELINE_VERSION}.tgz"
mkdir $TempDir
mv $pipeline_name $TempDir
cd $TempDir
export PATH=$ROSLIN_CORE_BIN_PATH/install:$PATH
install-pipeline.sh -p $TempDir/$pipeline_name > $parentDir/$TestDir/deploy_stdout.txt 2> $parentDir/$TestDir/deploy_stderr.txt
cd $ROSLIN_CORE_BIN_PATH
# Create workspace
./roslin-workspace-init.sh -v $ROSLIN_PIPELINE_NAME/$ROSLIN_PIPELINE_VERSION -u jenkins
# Run test
printf "\n----------Running Test----------\n"
cp $parentDir/test/run-example.sh.template $parentDir/$TestDir/run-example.sh
sed -i "s/PIPELINE_NAME/$ROSLIN_PIPELINE_NAME/g" $parentDir/$TestDir/run-example.sh
sed -i "s/PIPELINE_VERSION/$ROSLIN_PIPELINE_VERSION/g" $parentDir/$TestDir/run-example.sh
cd $installDir/roslin-pipelines/$ROSLIN_PIPELINE_NAME/$ROSLIN_PIPELINE_VERSION/workspace/jenkins/examples/Proj_DEV_0002
cp $parentDir/$TestDir/run-example.sh .
#pipelineJobId=$(./run-example.sh | grep '[0-9a-zA-Z]\{8\}-[0-9a-zA-Z]\{4\}-[0-9a-zA-Z]\{4\}-[0-9a-zA-Z]\{4\}-[0-9a-zA-Z]\{12\}')
#source /ifs/work/pi/roslin-test/.pyenv/bin/activate
export PATH=$ROSLIN_CORE_BIN_PATH:$PATH
#Set nodejs path
#export PATH=$PATH:/opt/common/CentOS_6-dev/nodejs/node-v6.10.1/bin
export NVM_DIR=/ifs/work/pi/roslin-test/.nvm
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
#export HOME=$parentDir/$TestDir
function store_test_logs {
cd $installDir/roslin-pipelines/$ROSLIN_PIPELINE_NAME/$ROSLIN_PIPELINE_VERSION/outputs
cd $(ls -d */|head -n 1)
cd $(ls -d */|head -n 1)
cp stderr.log $parentDir/$TestDir/test_stderr.txt
cp stdout.log $parentDir/$TestDir/test_stdout.txt
}
pipelineLeaderId=$(./run-example.sh | egrep -o -m 1 '[0-9]{8}')
printf "$pipelineLeaderId\n"
runningBool=1
while [ $runningBool != 0 ]
do
leaderStatus=$(bjobs $pipelineLeaderId | awk '{print $3}' | tail -1)
printf "$leaderStatus\n"
  if [ "$leaderStatus" == "DONE" ]
    then
    printf "Job Finished successfully\n"
    store_test_logs
    runningBool=0
  elif [ "$leaderStatus" == "EXIT" ]
    then
    printf "Job Failed\n"
    store_test_logs
    exit 1
  fi
  sleep 1m
done

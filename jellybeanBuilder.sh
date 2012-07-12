#!/bin/bash
## Set your work and out directories ##
WORKDIR=~/development/androidJB
OUTDIR=~/development/out

## Update script ##
SCRIPTDIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPTDIR
echo -e "\nSyncing script...\n"
git pull

mkdir -p $WORKDIR
mkdir -p $OUTDIR
cd $WORKDIR
REPO=$WORKDIR/repo
CPU=`grep -e 'processor' /proc/cpuinfo | wc -l`
let WORKERS=$CPU+1

echo -e "\n ::: SAMSUNG GALAXY TAB 10.1 - ANDROID 4.1.1 'JELLY BEAN' BUILDER SCRIPT ::: \n"

## Definition of the working directory and device models ##
TARGET=(p4 p4wifi)
MODELS=(GT-P7500 GT-P7510)

## Device selection menu ##
echo -e "\n Select your device:"
echo -e "\n [1] 10.1 3G (GT-P7500)"
echo -e "\n [2] 10.1 Wi-Fi only (GT-P7510)"

read -s -p "" -n 1 OPTION

if [[ $OPTION =~ [1-2]$ ]]; then
   let OPTION=$OPTION-1
   echo -e "\n You selected ${MODELS[$OPTION]}\n"
else
   echo -e "\n\nWrong choice. Run the script again"
   exit 1
fi

if [ ! -f $REPO ]; then
    echo -e "\n Downloading repo script...\n"
    curl https://dl-ssl.google.com/dl/googlesource/git-repo/repo > $REPO
    chmod a+x $REPO
fi

if [ ! -d $WORKDIR/.repo ]; then
    echo -e "\n Initialazing Jelly Bean repo. Set your identity if necessary \n"
    $REPO init -u https://android.googlesource.com/platform/manifest -b android-4.1.1_r1
fi

if [ ! "$(cat $WORKDIR/.repo/manifests.git/FETCH_HEAD | grep android-4.1.1_r1)" ]; then
    echo -e "\n Initialazing Jelly Bean repo. Set your identity if necessary \n"
    repo init -b android-4.1.1_r1
fi

cp $SCRIPTDIR/cfgFiles/local_manifest.xml $WORKDIR/.repo/

## Confirm repo update ##
echo -e "\n"
read -s -p "Sync repo now? (If this is the first sync, it will download around 9GiB) [Y/n]" -n 1 REPOUPDATE
if [[ $REPOUPDATE =~ ^[Yy]$ ]]; then
    echo -e "\n\nSyncing repos...\n"
    repo sync -j16
fi

## Initialize specific variables for build ##
. build/envsetup.sh  > /dev/null 2>&1
croot > /dev/null 2>&1
echo -e "\n"
lunch full_${TARGET[$OPTION]}-userdebug

## Java exports, this can be adjusted to fit the system ##
export JAVA_HOME=~/development/jdk1.6.0_27
export PATH=$PATH:~/development/jdk1.6.0_27/bin

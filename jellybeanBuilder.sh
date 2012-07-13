#!/bin/bash
## Set your work and out directories ##
WORKDIR=~/development/androidJB
OUTDIR=~/development/out
VERSION=jellybean-alpha

## Update script ##
SCRIPTDIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPTDIR
echo -e "\nSyncing script...\n"
git pull

mkdir -p $WORKDIR
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

## Copy modified files ##
cp $SCRIPTDIR/cfgFiles/local_manifest.xml $WORKDIR/.repo/
cp $SCRIPTDIR/cfgFiles/kernel.mk  $WORKDIR/build/core/tasks/
cp $SCRIPTDIR/cfgFiles/init.rc $WORKDIR/system/core/rootdir/
sed -i 's/CONFIG_SEC_KEYBOARD_DOCK=y/CONFIG_SEC_KEYBOARD_DOCK=n/' $WORKDIR/kernel/samsung/arch/arm/configs/pershoot_samsung_${TARGET[$OPTION]}-ics_defconfig

## Confirm repo update ##
echo -e "\n"
read -s -p "Sync repo now? (If this is the first sync, it will download around 9GiB) [Y/n]" -n 1 REPOUPDATE
if [[ $REPOUPDATE =~ ^[Yy]$ ]]; then
    echo -e "\n\nSyncing repos..."
    repo sync -j16
fi
echo -e "\n\n"
## Confirm compilation ##
read -s -p "Compile now? [Y/n]" -n 1 COMPNOW
if [[ ! $COMPNOW =~ ^[Yy]$ ]]; then
   echo -e "\n"
   exit 0
fi
echo -e "\n"

## Clean build ##
read -s -p "Do you want to make a clean build? [y/N]" -n 1 MKCLEAN
if [[ $MKCLEAN =~ ^[Yy]$ ]]; then make clean > /dev/null 2>&1; fi

## Compile kernel every time a build is made ##
if [ -f $OUTDIR/${TARGET[$OPTION]}/obj/KERNEL_OBJ/.version ]; then
   rm $OUTDIR/${TARGET[$OPTION]}/obj/KERNEL_OBJ/.version
fi

## Initialize specific variables for build ##
. build/envsetup.sh  > /dev/null 2>&1
croot > /dev/null 2>&1
echo -e "\n"
lunch full_${TARGET[$OPTION]}-userdebug

## Java exports, this can be adjusted to fit the system ##
export JAVA_HOME=~/development/jdk1.6.0_27
export PATH=$PATH:~/development/jdk1.6.0_27/bin

## Start build ##

echo -e "\n\nStarting compilation (this will take a considerable amount of time) ...\n"
time make -j$WORKERS otapackage

if [ $? -ne 0 ]; then
    beep -r 3
    echo -e "\nCompilation failed\n"
#    read -s -p "Would you like to see the error log? [n/Y]" -n 1 ERROR
#    if [[ $ERROR =~ ^[Yy]$ ]]; then
#	echo -e "\n"
#	cat /tmp/JBROMerrors.log | grep -v warning
#	exit 0
#    fi
#    exit 1
fi

echo -e "\nCompilation succeeded\n"
beep -r 1

## Prepare ROM ##
echo -e "\nPreparing ROM...\n"
TODAY=$(date +"%d-%m-%y.%H-%M")
mkdir -p $OUTDIR/tmp
mkdir -p $OUTDIR/{lastbuild,oldbuilds}/${TARGET[$OPTION]}

## Move the last build to oldbuilds ##
if [ -f  $OUTDIR/lastbuild/${TARGET[$OPTION]}/*.zip ]; then
    mv $OUTDIR/lastbuild/${TARGET[$OPTION]}/*.zip $OUTDIR/oldbuilds/${TARGET[$OPTION]}
fi

## Copy raw ROM ##
cp $WORKDIR/out/target/product/${TARGET[$OPTION]}/*.zip $OUTDIR/

## Unzip and mod files to get final ROM
cd $OUTDIR
unzip -q *.zip -d tmp/
rm *.zip
rm -rf tmp/recovery
cp $SCRIPTDIR/cfgFiles/updater-script tmp/META-INF/com/google/android/
sed -i s/p4wifi/"${TARGET[$OPTION]}"/ tmp/META-INF/com/google/android/updater-script
cp $SCRIPTDIR/system/ tmp/ -r
cd tmp
zip -qr $TODAY-$VERSION-${TARGET[$OPTION]}.zip *

## Sign final ROM ##
echo -e "\nSigning ROM...\n"
java -Xmx2048m -jar $WORKDIR/out/host/linux-x86/framework/signapk.jar -w $WORKDIR/build/target/product/security/testkey.x509.pem $WORKDIR/build/target/product/security/testkey.pk8 $TODAY-$VERSION-${TARGET[$OPTION]}.zip $TODAY-$VERSION-${TARGET[$OPTION]}-sig.zip

## Move final ROM ##
mv $OUTDIR/tmp/$TODAY-$VERSION-${TARGET[$OPTION]}-sig.zip $OUTDIR/lastbuild/${TARGET[$OPTION]}

## Clean tmp directory ##
rm -rf $OUTDIR/tmp/*

## echo the location of the final ROM ##
echo -e "\nROM ready at $OUTDIR/lastbuild/${TARGET[$OPTION]}/$TODAY-$VERSION-${TARGET[$OPTION]}-sig.zip\n\n"

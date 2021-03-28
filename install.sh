#!/bin/sh

# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
# addon name
MY_ADDON_NAME=ptcMerlin
# Github repo name
GIT_REPO="ptcMerlin"
# Github repo branch - modify to pull different branch 
# (fetch will overwrite local changes)
if [ -z "$1" ]
then
    GIT_REPO_BRANCH=master
else
    GIT_REPO_BRANCH=development
fi
# Github dir
GITHUB_DIR="https://raw.githubusercontent.com/h0me5k1n/$GIT_REPO/$GIT_REPO_BRANCH"
# Local repo dir
LOCAL_REPO="/jffs/scripts/$MY_ADDON_NAME"

# functions
errorcheck(){
 echo "$SCRIPTSECTION reported an error..."
 exit 1
}

# use to download the files from github
GetFiles(){
 echo "downloading $GIT_REPO using $GIT_REPO_BRANCH branch"
 GETFILENAME=.quirecfg-sample
 SCRIPTSECTION=get_$GETFILENAME
 [ -f "$LOCAL_REPO/$GETFILENAME" ] && rm "$LOCAL_REPO/$GETFILENAME"
 wget -O "$LOCAL_REPO/$GETFILENAME" "$GITHUB_DIR/$GETFILENAME" >/dev/null 2>&1 || errorcheck
 chmod 755 "$LOCAL_REPO/$GETFILENAME"

 GETFILENAME=.rtmcfg-sample
 SCRIPTSECTION=get_$GETFILENAME
 [ -f "$LOCAL_REPO/$GETFILENAME" ] && rm "$LOCAL_REPO/$GETFILENAME"
 wget -O "$LOCAL_REPO/$GETFILENAME" "$GITHUB_DIR/$GETFILENAME" >/dev/null 2>&1 || errorcheck
 chmod 755 "$LOCAL_REPO/$GETFILENAME"

 GETFILENAME=LICENSE
 SCRIPTSECTION=get_$GETFILENAME
 [ -f "$LOCAL_REPO/$GETFILENAME" ] && rm "$LOCAL_REPO/$GETFILENAME"
 wget -O "$LOCAL_REPO/$GETFILENAME" "$GITHUB_DIR/$GETFILENAME" >/dev/null 2>&1 || errorcheck
 chmod 755 "$LOCAL_REPO/$GETFILENAME"

 GETFILENAME=ptcMerlin.sh
 SCRIPTSECTION=get_$GETFILENAME
 [ -f "$LOCAL_REPO/$GETFILENAME" ] && rm "$LOCAL_REPO/$GETFILENAME"
 wget -O "$LOCAL_REPO/$GETFILENAME" "$GITHUB_DIR/$GETFILENAME" >/dev/null 2>&1 || errorcheck
 chmod 755 "$LOCAL_REPO/$GETFILENAME"

 GETFILENAME=quire_commands.sh
 SCRIPTSECTION=get_$GETFILENAME
 [ -f "$LOCAL_REPO/$GETFILENAME" ] && rm "$LOCAL_REPO/$GETFILENAME"
 wget -O "$LOCAL_REPO/$GETFILENAME" "$GITHUB_DIR/$GETFILENAME" >/dev/null 2>&1 || errorcheck
 chmod 755 "$LOCAL_REPO/$GETFILENAME"

 GETFILENAME=README.md
 SCRIPTSECTION=get_$GETFILENAME
 [ -f "$LOCAL_REPO/$GETFILENAME" ] && rm "$LOCAL_REPO/$GETFILENAME"
 wget -O "$LOCAL_REPO/$GETFILENAME" "$GITHUB_DIR/$GETFILENAME" >/dev/null 2>&1 || errorcheck
 chmod 755 "$LOCAL_REPO/$GETFILENAME"

 GETFILENAME=rtm_commands.sh
 SCRIPTSECTION=get_$GETFILENAME
 [ -f "$LOCAL_REPO/$GETFILENAME" ] && rm "$LOCAL_REPO/$GETFILENAME"
 wget -O "$LOCAL_REPO/$GETFILENAME" "$GITHUB_DIR/$GETFILENAME" >/dev/null 2>&1 || errorcheck
 chmod 755 "$LOCAL_REPO/$GETFILENAME"

 GETFILENAME=tag2mac_lookup-sample
 SCRIPTSECTION=get_$GETFILENAME
 [ -f "$LOCAL_REPO/$GETFILENAME" ] && rm "$LOCAL_REPO/$GETFILENAME"
 wget -O "$LOCAL_REPO/$GETFILENAME" "$GITHUB_DIR/$GETFILENAME" >/dev/null 2>&1 || errorcheck
 chmod 755 "$LOCAL_REPO/$GETFILENAME"

 SCRIPTSECTION=
}

# Check this is an Asus Merlin router
nvram get buildinfo | grep merlin >/dev/null 2>&1
if [ $? != 0 ]
then
    echo "This script is only supported on an Asus Router running Merlin firmware!"
    exit 5
fi

# Does the firmware support addons?
nvram get rc_support | grep -q am_addons
if [ $? != 0 ]
then
    echo "This firmware does not support addons!"
    logger "$MY_ADDON_NAME addon" "This firmware does not support addons!"
    exit 5
fi

# Check jffs is enabled
JFFS_STATE=$(nvram get jffs2_on)
if [ $JFFS_STATE != 1 ]
then
    echo "This addon requires jffs to be enabled!"
    logger "$MY_ADDON_NAME addon" "This addon requires jffs to be enabled!"
    exit 5
fi

# create local repo folder
mkdir -p "$LOCAL_REPO"

# Get files
GetFiles

echo "installation complete... visit https://github.com/h0me5k1n/$GIT_REPO for usage information"
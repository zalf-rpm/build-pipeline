#!/bin/sh

VERSION_FOLDER=$1
BUILD_FOLDER=$2
UNSTASH_FOLDER=$3
MOUNTED_ARCHIV=$4
mkdir -p $MOUNTED_ARCHIV/$VERSION_FOLDER/$BUILD_FOLDER
cp -r $UNSTASH_FOLDER/. $MOUNTED_ARCHIV/$VERSION_FOLDER/$BUILD_FOLDER

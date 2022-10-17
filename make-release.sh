#!/bin/bash

# Sets you up to make a hotfix.  Pass in release name, no prefixed `v`.

export RELEASE_OR_HOTFIX=$1
VERSION=$2

if [[ $RELEASE_OR_HOTFIX == "release" || ($RELEASE_OR_HOTFIX == "hotfix") ]]
then
    echo "You have selected $RELEASE_OR_HOTFIX"
else
    echo "usage: You must specify one of release or hotfix. eg $0 release 3.0.0"
    exit -1
fi

if [ -z $VERSION ]
then
    echo "usage: Pass in hotfix name, no prefixed 'v'."
    exit -1
fi

# Going forward, the globally installed Swift 5.x or later is sufficient for testing for the myriad of versions that will come after 4.2.
SWIFT5_OR_LATER_LOCATION=/Applications/Xcode.app/Contents/Developer/

set -x
set -e

# confirm that git flow is present:
git flow version

# confirm that working directory has no untracked stuff:
git diff-index --quiet HEAD --

# make sure remote is refresh:
git fetch origin

git checkout master

# destroy master state!
git reset --hard origin/master

git checkout develop

# destroy develop state!
git reset --hard origin/develop

echo "Making $RELEASE_OR_HOTFIX branch for: $VERSION"

if [ $RELEASE_OR_HOTFIX == "hotfix" ]
then
    echo "Assuming hotfix branch already exists."
    git checkout hotfix/$VERSION
    echo "Verifying SDK with Xcode."
    pod lib lint RoverCampaigns.podspec
    pod lib lint RoverAppExtensions.podspec
else
    git checkout develop
    echo "Verifying SDK with Xcode."
    pod lib lint RoverCampaigns.podspec
    pod lib lint RoverAppExtensions.podspec

    git flow $RELEASE_OR_HOTFIX start $VERSION
fi

echo "Edit your version numbers (podspec, README, Meta.swift) and press return!"
read -n 1

git commit --allow-empty -a -m "Releasing $VERSION."

git flow $RELEASE_OR_HOTFIX finish $VERSION

git push origin master
git push origin develop

git push origin v$VERSION

echo "Now run 'pod trunk push RoverCampaigns.podspec && pod trunk push RoverAppExtensions.podspec'"

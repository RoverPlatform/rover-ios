#!/bin/bash

# Sets you up to make a release.  Pass in release name, no prefixed `v`.
if [ -z $1 ]
then
    echo "Pass in release name, no prefixed 'v'."
    exit -1
fi

# Swift 4.2 uses the old ABI, so we want to confirm that our stuff actually *builds* with the old compiler.
SWIFT42_LOCATION=/Applications/Xcode\ 10.1.app/Contents/Developer/
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

echo "Verifying SDK with Xcode 10.1 / Swift 4.2"
DEVELOPER_DIR=$SWIFT42_LOCATION pod lib lint Rover.podspec --swift-version=4.2

echo "Verifying SDK with Xcode 10.2 (or later) / Swift 5 (or later)."
DEVELOPER_DIR=$SWIFT5_OR_LATER_LOCATION pod lib lint Rover.podspec --swift-version=5.0


echo "Making release branch for: $1"

git flow release start $1

echo "Update your version numbers, commit, then do 'git flow release finish $1'"
echo "Then push your branches and do 'pod trunk push Rover.podspec'."

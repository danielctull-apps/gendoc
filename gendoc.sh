#!/bin/bash

# From an original script by Daniel Tull
# Somewhat mangled by Sam Deane

# Run this script from the root of your project.
# It makes a temporary directory and generates appledoc documentation for your
# project in that directory.
# It then makes a local clone of your documentation branch (called gh-pages, by default)
# copies the generated appledoc html into a folder in the branch (called Documentation by default)
# commits the new documentation and pushes it back to the project repo.
#
# Note that it doesn't push from the project repo, so the new documentation doesn't leave
# your machine - you need to manually 'git push origin gh-pages:gh-pages' (or whatever) to
# actually publish the gh-pages branch to the wider world.

# This script assumes:
# - the name of the root folder is the name of the project
# - your appledoc templates are in "$SCRIPTROOT/appledoc"
# - you have a GlobalSettings.plist file in your appledoc templates folder
# - you've set values in GlobalSettings.plist for --project-company, --company-id

git=`xcrun --find git`
originaldirectory=`git rev-parse --show-toplevel`
codebranch=`$git rev-parse --abbrev-ref HEAD`
docbranch="gh-pages"
projectname=`basename $PWD`
docdirectory="Documentation"
defaultcommitmessage="Update documentation."
docsetutil=`xcrun --find docsetutil`
tempdir=/tmp/gendoc

# if we're on the documentation branch, something's gone wrong
if [[ "$codebranch" == "gh-pages" ]]
then
    echo "You seem to be on the gh-pages branch. Checkout a code branch instead."
    exit 1
fi

echo "Generating documentation for $projectname"

# make a clean temp directory
rm -rf "$tempdir"
mkdir -p -v "$tempdir"


# generate and install a docset in xcode
appledoc --create-docset --install-docset --docsetutil-path "$docsetutil" --project-name $projectname -o "$tempdir" "$@" ./

# generate html version
appledoc --templates ~/.appledoc --create-html --no-create-docset --docsetutil-path "$docsetutil" --project-name $projectname -o "$tempdir" "$@" ./

# only proceed if appledoc actual worked
if [ $? == 0 ];
then

# clone doc branch of current repo into temporary location
$git clone $originaldirectory "$tempdir/branch" --quiet
cd "$tempdir/branch"

if $git show-ref --tags --quiet --verify -- "refs/heads/$docbranch"
then
	echo "Creating $docbranch branch"
	$git checkout -b $docbranch
else
	echo "Checking out $docbranch branch"
	$git checkout $docbranch
fi

$git clean -dfx

mkdir "$tempdir/branch/$docdirectory"

echo "$tempdir/branch"

# make sure stale docs are removed - re-adding will cause an update
$git rm -rf "$docdirectory"

# move the generated docs to docdirectory and cleanup
mv -v ../html "$docdirectory"

# add directory and commit with default message, allowing editing
$git add -f -v "$docdirectory"
$git commit -e -m "$defaultcommitmessage"

# push changes back to our repo
$git push origin $docbranch

# remove temporary directory
rm -rf "$tempdir"

fi

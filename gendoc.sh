#!/bin/bash

# From an original script by Daniel Tull
# Somewhat mangled by Sam Deane

# This script assumes:
# - your appledoc templates are in ~/.appledoc
# - you have a GlobalSettings.plist file in there
# - you've set values in there for --project-company, --company-id

codebranch=`git rev-parse --abbrev-ref HEAD`
docbranch="gh-pages"
projectname=$(pwd | sed "s/^.*\///g")
docdirectory="Documentation"
defaultcommitmessage="Update documentation."
docsetutil=`xcrun --find docsetutil`

# if we're on the documentation branch, something's gone wrong
echo $codebranch
if [[ "$codebranch" == "gh-pages" ]]
then
    echo "You seem to be on the gh-pages branch. Checkout a code branch instead."
    exit 1
fi

# assume we're on the branch containing the code we're going to generate documentation for
# but don't allow anything to happen if there are outstanding changes...
status=`git status -s`
if [ "${status}" != "" ]
then
    echo "Git has outstanding changes - commit or revert them first."
    exit 1
fi



echo "Generating documentation for $projectname"

# generate and install a docset in xcode
rm -r /tmp/gendoc/
mkdir -p -v /tmp/gendoc/
appledoc --templates ~/.appledoc --create-docset --install-docset --docsetutil-path "$docsetutil" --project-name $projectname -o /tmp/gendoc/ "$@" ./

# generate html version
rm -r /tmp/gendoc/
mkdir -p -v /tmp/gendoc/
appledoc --templates ~/.appledoc --create-html --no-create-docset --docsetutil-path "$docsetutil" --project-name $projectname -o /tmp/gendoc/ "$@" ./

# only proceed if appledoc actual worked
if [ $? == 0 ];
then

# if docbranch exists
if git show-ref --tags --quiet --verify -- "refs/heads/$docbranch"
then
	# switch to doc branch
	git checkout $docbranch
else 
	echo "Creating $docbranch branch"
	# create the docbranch (explained on http://pages.github.com/)
	git symbolic-ref HEAD "refs/heads/$docbranch"
	rm .git/index
	git clean -fdx
fi

# make sure stale docs are removed - re-adding will cause an update
git rm -r $docdirectory
mkdir $docdirectory

# move the generated docs to docdirectory and cleanup
mv -v /tmp/gendoc/html/* "$docdirectory"
rm -r /tmp/gendoc/

# add directory and commit with default message, allowing editing
git add -f -v "$docdirectory"
git commit -e -m "$defaultcommitmessage"

# switch back to the original branch
git checkout $codebranch

fi
#!/bin/bash

# Original script by Daniel Tull, with additions by Sam Deane

# Run this script from the root of your project.
# It makes a temporary directory and generates appledoc documentation for your
# project in that directory.
# It then makes a local clone of your documentation branch (called gh-pages, by default)
# copies the generated appledoc html into a folder in the branch (called Documentation by default)
# commits the new documentation and pushes it back to the project repo.
#
# Note that it doesn't push from the project repo, so the new documentation doesn't leave
# your machine - but it echos the git command that you'll need to execute to do the push.

# This script assumes:
# - the name of the root folder is the name of the project
# - your appledoc templates are in ~/.appledoc (can be a symlink)
# - you have a GlobalSettings.plist file in your appledoc templates folder
# - you've set values in GlobalSettings.plist for --project-company, --company-id

# The script looks at the remotes configured in the repo to try to work out what your github
# user name is, so that it can generate the correct urls for a docset feed.
# It looks for the first remote with the pattern: git@github.com:yourname/

git=`xcrun --find git`
docsetutil=`xcrun --find docsetutil`
originaldirectory=`git rev-parse --show-toplevel`
codebranch=`$git rev-parse --abbrev-ref HEAD`
docbranch="gh-pages"
projectname=`basename $PWD`
docdirectory="documentation"
initialdefaultcommitmessage="Initial documentation"
updatedefaultcommitmessage="Update documentation"
defaultcommitmessage=$updatedefaultcommitmessage
tempdir=/tmp/gendoc

# find real templates location (.appledoc might be a link)
pushd $HOME > /dev/null
link=`readlink ".appledoc"`
if [[ $link != "" ]];
then
cd $link
else
cd ".appledoc"
fi
templates=`pwd`
popd > /dev/null

# try to fish out the github user from the git remotes - we use the first one that seems to be a github repo that we can write to
# (this logic may be flawed!)
remotes=`git remote -v`
pattern="([a-z]*).git@github.com:([a-zA-Z0-9]+)\/"
[[ $remotes =~ $pattern ]]
githubrepo=${BASH_REMATCH[1]}
githubuser=${BASH_REMATCH[2]}

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


# generate docset and html, install docset in xcode, create atom feed and downloadable package
appledoc \
    --templates "$templates" \
    --keep-intermediate-files \
    --create-html \
    --create-docset \
    --install-docset \
    --publish-docset \
    --docsetutil-path "$docsetutil" \
    --docset-atom-filename "docset.atom" \
    --docset-feed-url "http://$githubuser.github.com/$projectname/$docdirectory/%DOCSETATOMFILENAME" \
    --docset-package-url "http://$githubuser.github.com/$projectname/$docdirectory/%DOCSETPACKAGEFILENAME" \
    --docset-fallback-url "http://$githubuser.github.com/projectname/$docdirectory/" \
    --project-name $projectname \
    -o "$tempdir" "$@" ./

# clone doc branch of current repo into temporary location
$git clone "$originaldirectory" "$tempdir/branch"

if $git show-ref --tags --quiet --verify -- "refs/heads/$docbranch"
then
    cd "$tempdir/branch"
    echo "Checking out $docbranch branch"
    $git checkout $docbranch
else
    cd "$tempdir/branch"
    echo "Creating $docbranch branch"
    defaultcommitmessage=$initialdefaultcommitmessage
    $git symbolic-ref HEAD "refs/heads/$docbranch"
    rm .git/index
    $git clean -fdx
fi

# make sure stale docs are removed - re-adding will cause an update
$git rm -rf "$docdirectory" --quiet

# move the generated docs to docdirectory and cleanup
mkdir "$docdirectory"
mv -v ../html/* "$docdirectory"
mv -v ../publish/* "$docdirectory"

# add directory and commit with default message, allowing editing
$git add -f -v "$docdirectory"
$git commit -e -m "$defaultcommitmessage"

# push changes back to our repo
$git push origin $docbranch

# remove temporary directory
rm -rf "$tempdir"

echo "Feed URL is at http://$githubuser.github.com/$projectname/$docdirectory/docset.atom"
echo "To push the documentation changes, do:"
echo "git push $githubrepo $docbranch:$docbranch"

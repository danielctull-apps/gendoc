#!/bin/bash

# From an original script by Daniel Tull
# Somewhat mangled by Sam Deane

# See README.md for an explanation of what this script does and how to use it.

git=`xcrun --find git`
docsetutil=`xcrun --find docsetutil`
originaldirectory=`git rev-parse --show-toplevel`
codebranch=`$git rev-parse --abbrev-ref HEAD`
docbranch="gh-pages"
projectname=`basename "$PWD"`
docdirectory="Documentation"
initialdefaultcommitmessage="Initial documentation"
updatedefaultcommitmessage="Update documentation"
defaultcommitmessage=$updatedefaultcommitmessage
tempdir=/tmp/gendoc
publish=true
open=false
editcommit=false

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

# include settings file if it's present
if [ -e ./.appledoc.plist ]; then
    echo "Found appledoc settings file"
    settings=./.appledoc.plist
fi

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
    -o "$tempdir" "$@" $settings ./

# clone doc branch of current repo into temporary location
$git clone "$originaldirectory" "$tempdir/branch"

if $git show-ref --tags --quiet --verify -- "refs/heads/$docbranch"
then
    pushd "$tempdir/branch" > /dev/null
    echo "Checking out $docbranch branch"
    $git checkout $docbranch
else
    pushd "$tempdir/branch" > /dev/null
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

# add directory and commit with default message
$git add -f -v "$docdirectory"
if $editcommit; then
    $git commit -e -m "$defaultcommitmessage"
else
    $git commit -m "$defaultcommitmessage"
fi

# push changes back to our repo
$git push origin $docbranch

# remove temporary directory
rm -rf "$tempdir"

popd > /dev/null

# if publishing is on, push the documentation pages, otherwise echo out the command that would push them
if $publish ; then
    git push $githubrepo $docbranch:$docbranch
else
    echo "To push the documentation changes, do:"
    echo "git push $githubrepo $docbranch:$docbranch"
fi

# echo info on the location of the feed
echo "Feed URL is at http://$githubuser.github.com/$projectname/$docdirectory/docset.atom"
echo "Documentation changes may take a while to filter through..."

# open the top of the documentation pages in the browser
if $open ; then
    open "http://$githubuser.github.com/$projectname/$docdirectory"
fi


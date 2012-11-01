Run the gendoc script from the root of your project.

It makes a temporary directory and generates appledoc documentation for your project in that directory.

It then makes a local clone of your documentation branch (called gh-pages, by default), copies the generated appledoc html into a folder in the branch (called Documentation by default), commits the new documentation and pushes it back to the project repo.

Note that it doesn't push from the project repo, so the new documentation doesn't leave
your machine - but it echos the git command that you'll need to execute to do the push.

This script assumes:
- the name of the root folder is the name of the project
- your appledoc templates are in ~/.appledoc (can be a symlink)
- you have a GlobalSettings.plist file in your appledoc templates folder
- you've set values in GlobalSettings.plist for --project-company, --company-id

The script looks at the remotes configured in the repo to try to work out what your github
user name is, so that it can generate the correct urls for a docset feed.
It looks for the first remote with the pattern: git@github.com:yourname/

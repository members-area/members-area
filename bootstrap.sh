#!/bin/bash
# bootstrap.sh
#
# This script is designed to get you developing for the members-area as quickly
# as possible.  It's very simple - it just installs the members area and a
# bunch of plugins and links then up in a way that makes development very easy.
#
# It runs `npm link` a lot, so you need to be able to `npm install -g` without 
# needing `sudo`. A simple way to do this is to change your npm prefix to a
# folder in your home directory, add the bin directory to your $PATH and you're
# good to go. See: https://www.npmjs.org/doc/files/npmrc.html
#
# Improvements to this file are very welcome! Initial setup is quite slow as it
# uses the quickstart method of the members area and then undoes a lot of it
# and redoes it using local dependences :/
#
# To run, simply
#
#     $ bash bootstrap.sh


# You can edit this list of plugins (we only support github repos):
PLUGINS="benjie/members-area-theme-somakeit LeoAdamek/members-area-theme-shh"


################################################
###          DON'T EDIT BELOW HERE!          ###
###            Unless you want to            ###
################################################


set -e
set -u

# Make sure we're doing this in a blank folder
mkdir -p MembersArea
cd MembersArea

# Clone members-area into ./members-area/ and then install the dependencies and link it
git clone git@github.com:members-area/members-area.git
cd members-area
mkdir -p node_modules
npm install
npm link
cd ..

# Clone each plugin in turn, install dependencies, `npm link` it and link the `members-area` checkout above for ease of development
for PLUGIN in $PLUGINS; do
  git clone git@github.com:$PLUGIN.git
  NAME=$(basename $PLUGIN)
  cd $NAME
  mkdir -p node_modules
  npm install
  npm link
  cd node_modules
  ln -s ../../members-area members-area
  cd ../..
done

# Create a new instance for us, bootstrap it
mkdir -p instance
cd instance
members init
members migrate
members seed

# Replace the members-area module and each plugin module with links to the checked out plugins above
npm link members-area
for PLUGIN in $PLUGINS; do
  NAME=$(basename $PLUGIN)
  npm link $NAME
  node <<SCRIPT
var fs = require('fs');
var pkg = require('./package.json');
pkg.dependencies["$NAME"] = "*";
fs.writeFileSync('./package.json', JSON.stringify(pkg, null, 2));
SCRIPT
done

# The ./watch.sh script will monitor all the modules (plugins) for changes and restart as necessary
npm install nodemon
cat > watch.sh <<EOF
#!/bin/sh
ARGS="--watch ../members-area"
for I in ../members-area-*; do
  ARGS="\$ARGS --watch \$I";
done
./node_modules/.bin/nodemon --ignore node_modules/ --ignore public/ --ignore db/ --ignore views/ --ignore app/views/ --ignore app/db/ --ignore scripts/ --ignore sessions/ --ignore log/ \$ARGS --watch . index.coffee
EOF
chmod +x watch.sh

# Run it!
./watch.sh

#!/bin/bash

clean() {
    git reset --hard
    git clean -fdx
}

update() {
    git pull
    git submodule init
    git submodule sync
}

if [[ $# < 1 ]]
then
    echo "Usage: $0 /path/to/ssh.key"
    echo "This script should be run from the blog repo"
    exit 1

elif [[ $# < 2 ]]
then
    ssh-add $1
    clean
    update

    # recurse
    $0 $1 true

else
    hugo -s blog -d /var/www/lsxnr/public
fi


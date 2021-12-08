#!/usr/bin/env bash
set -e

[ -d repo ] || mkdir -v repo
[ "$1" == "" ] && exit 1

rsync -av --delete "$1"/ ./repo/
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"
git status
if [ -n "$(git status --porcelain)" ]; then
    git add .
    git commit -m "Update maps repo"
    git push
else
    echo "No changes to commit"
fi


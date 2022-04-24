#!/usr/bin/env bash
set -e

git reset
for item in ${@}; do
  if ! [ -z $(git diff --name-only ${item}) ]; then
    commit_ids=$(git log --pretty=format:"%h" --reverse ${item})
    base_commit_id=$(echo ${commit_ids} | awk '{ print $1 }')
    for commit_id in ${commit_ids}; do
      if [ ${base_commit_id} != ${commit_id} ]; then
        base_message=$(git log --pretty=format:"%s" -1 ${base_commit_id})
        message=$(git log --pretty=format:"%s" -1 ${commit_id})
        if [ "${message}" == "fixup! ${base_message}" ]; then
          # echo >>/dev/stderr "[-] Forward commit for ${item}"
          base_commit_id=${commit_id}
        else
          echo >>/dev/stderr "[-] Invalid log for ${item}"
          exit 1
        fi
      fi
    done
    git reset
    git add ${item}
    git commit --fixup ${base_commit_id}
  fi
done

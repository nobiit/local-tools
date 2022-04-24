#!/usr/bin/env bash
set -e

namespace=${1}

if [ -z ${namespace} ]; then
  exit 1
fi

function _ready_time() {
  kubectl get ${1} -n ${namespace} -o json | jq -r '.items[] | select(.metadata.ownerReferences | map(select(.kind == "'${2}'")) | map(select(.name == "'${3}'")) | length > 0)'
}

function ready_time() {
  if [[ ${1} =~ ^(StatefulSet|DaemonSet|ReplicaSet)$ ]]; then
    _ready_time Pod ${1} ${2} | jq -r '.status.conditions[] | select(.type == "Ready") | select(.status == "True") | .lastTransitionTime'
  elif [ ${1} == Deployment ]; then
    for name in $(_ready_time ReplicaSet ${1} ${2} | jq -r .metadata.name); do
      ready_time ReplicaSet ${name}
    done
  fi
}

declare -A timeline
for item in StatefulSet DaemonSet Deployment; do
  for name in $(kubectl get ${item}s.apps -n ${namespace} -o json | jq -r .items[].metadata.name); do
    time=$(ready_time ${item} ${name} | sort -r | head -n 1)
    x=0
    while ! [ -z "${timeline[${time}-${x}]}" ]; do
      x=$(expr ${x} + 1)
    done
    timeline[${time}-${x}]="kubectl rollout status ${item,,}s -n ${namespace} ${name}"
  done
done

for time in $(echo ${!timeline[@]} | xargs -n 1 | sort); do
  note=''
  if [ ${SHOW_TIME:-0} == 1 ]; then
    note="# ${time}"
  fi
  echo ${timeline[${time}]} ${note}
done

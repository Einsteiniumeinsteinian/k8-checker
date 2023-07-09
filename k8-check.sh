#!/bin/bash

# run value
# ./k8-check.sh -o=test.txt  -n=default

#Functions
#Check if a cluster is configured properly
function createDebugLogFile() {
    echo "creating log file"
    touch $outputFile && echo "$(tput setaf 2)Log File Created Successfully $(tput sgr0)"
    echo >> $outputFile
    date >> $outputFile

}

# Validate Input Parameters
validate_parameters() {
    echo "Validating Parameter"
    if [[ -z "$outputFile" ]]; then
        echo "$(tput setaf 1) Output path Not Provided. Include output path with -o=<output-path>.$(tput sgr0)"
        exit 1
    fi

    if [[ -z "$namespace" ]]; then
        echo "$(tput setaf 1) Namespace Not Provided. Include Namespace with -n=<namespace>.$(tput sgr0)"
        exit 1
    fi
    echo "$(tput setaf 2)All Parameters Validated $(tput sgr0)"
}

#Kubectl Functions
#Check if Kubectl is Configured Properly
function validateDependencies() {
    echo Checking Dependencies
    if ! command -v kubectl &>/dev/null; then
        echo "$(tput setaf 1)Error: kubectl is not installed. Please install kubectl.$(tput sgr0)"
        exit 2
    fi

    if ! command -v jq &>/dev/null; then
        echo "$(tput setaf 1)Error: jq is not installed. Please install jq.$(tput sgr0)"
        exit 2
    fi

    if ! kubectl config current-context &>/dev/null; then
        echo "$(tput setaf 1)Error: kubectl is not connected to a Kubernetes cluster.$(tput sgr0)"
        exit 2
    fi

    echo "$(tput setaf 2)kubectl is connected to a Kubernetes cluster.$(tput sgr0)"
    echo "$(tput setaf 2)jq is installed correctlly$(tput sgr0)"
    echo "$(tput setaf 2)kubectl is not installed correccly.$(tput sgr0)"
}

#Verify Resource Function
function verifyPodInstallation() {
    echo "checking pods"
    local name="PODS"
    local restartingPods=$(kubectl get po -n $namespace | awk '$4>3' | grep -v NAME)
    local incompletePods=$(kubectl get po -n $namespace | grep -Ev 'Running|Completed|NAME')
    local failedMessage1="Some Pods are still incomplete"
    local failedMessage2="Some Pods are restarting please check log files"
    errorHandler "${restartingPods[@]}" "$failedMessage2" "$name"
    errorHandler "${incompletePods[@]}" "$failedMessage1" "$name"
}

function verifyDeploymentStatus() {
    echo "checking Deployments"
    local name="DEPLOYMENT"
    local failedMessage1="some Deployments failed test"
    local failedDeployments=$(kubectl get deployment -n $namespace | grep -v NAME | awk '{split($2, arr, "/"); if (arr[1] != $3 || arr[1] != $4 || arr[1] != arr[2]) print}')
    errorHandler "${failedDeployments[@]}" "$failedMessage1" "$name"
}

function verifyJobsStatus() {
    echo "checking JOBS"
    local name="JOBS"
    local failedMessage1="some Jobs failed test"
    local failedJobs=$(kubectl get jobs -n $namespace | grep -v NAME | awk '{split($2, arr, "/"); if (arr[1] != arr[2] && ($4 ~ /m/ || $4 ~ /h/ || $4 ~ /d/)) print}')
    errorHandler "${failedJobs[@]}" "$failedMessage1" "$name"
}

function verifyServiceEndpoints() {
    echo "checking services"
    local name="SERVICES"
    local failedMessage1='some Services are Pending'
    local failedMessage2="some services have no endpoints"
    local pendingService=$(kubectl get svc -n $namespace | grep -v NAME | grep -i pending)
    local serviceWithoutEndPoint=$(kubectl get ep -n $namespace -o json | jq '.items[] | select(.subsets | length == 0) | .metadata.name')
    errorHandler "${pendingService[@]}" "$failedMessage1" "$name"
    errorHandler "${serviceWithoutEndPoint[@]}" "$failedMessage2" "$name"
}

function verifystatefulSet() {
    echo "checking statefulset"
    local name="STATEFULSET"
    local failedMessage1='some statefulset failed tests'
    local failedStatefulset=$(kubectl get deployment -n $namespace | grep -v NAME | awk '{split($2, arr, "/"); if (arr[1] != arr[2]) print}')
    errorHandler "${failedStatefulset[@]}" "$failedMessage1" "$name"
}

function verifyDaemonSet() {
    echo "checking daemonset"
    local name="DAEMONSET"
    local failedMessage1='some Daemonset failed test'
    local failedDaemonSet=$(kubectl get ds -n $namespace | grep -v NAME | awk '{ if ($3 != $2 || $3 != $4 || $3 != $5 || $3 != $6) print}')
    errorHandler "${failedDaemonSet[@]}" "$failedMessage1" "$name"
}

function errorHandler() {
    local failedComponents=$1
    local message=$2
    local name=$3
    local issues=0
    if ! [[ -z $failedComponents ]]; then
        echo "$message"
        echo "$name:" | tee -a $outputFile
        printf '%s\n' "${failedComponents[@]}" | tee -a $outputFile
        ((issues++))
    fi
    [[ $issues -gt 0 ]] && echo "$(tput setaf 1)$issues issues found in $name.$(tput sgr0)" || echo "$(tput setaf 2)$issues issues found in $name.$(tput sgr0)"
    
    totalIssuesFound=$(($issues + $totalIssuesFound))
}

function runDebugger() {
    printf "\n\n"
    createDebugLogFile
    printf "\n\n"
    verifyPodInstallation
    printf "\n\n"
    verifyDeploymentStatus
    printf "\n\n"
    verifyJobsStatus
    printf "\n\n"
    verifyServiceEndpoints
    printf "\n\n"
    verifystatefulSet
    printf "\n\n"
    verifyDaemonSet
    printf "\n\n"
    sendEmail
}

function sendEmail() {
    #send mail
    if [[ $totalIssuesFound != 0 ]]; then
        printf "$(tput setaf 3)Warning:\n$totalIssuesFound issue(s) found\n $outputFile for more info\n$(tput sgr0)"
        local errorMsg="Error Found by Debugger"
        # sendToAllTeamMembers $errorMsg
    else
        local successMsg="No Errors seen by debugger"
        echo "$(tput setaf 2)No Errors Found By Debugger $(tput sgr0)"
        echo $successMsg >>$outputFile
        # sendToAllTeamMembers $successMsg
    fi
}

totalIssuesFound=0
outputFile=$(echo "$@" | grep -oE -- "-o=[^[:space:]]+" | cut -d'=' -f2)
email=$(echo "$@" | grep -oE -- "-e=[^[:space:]]+" | cut -d'=' -f2)
namespace=$(echo "$@" | grep -oE -- "-n=[^[:space:]]+" | cut -d'=' -f2)
emailFile=$(echo "$@" | grep -oE -- "-f=[^[:space:]]+" | cut -d'=' -f2)

# Check if the script is invoked with the correct number of arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 must have atleast two arguments -o (outputfile) and -n (namespace) "
    exit 1
fi

validateDependencies
validate_parameters
runDebugger

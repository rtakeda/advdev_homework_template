#!/bin/bash
# Setup Jenkins Project

# REI uncomment before submission
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3

#GUID=e5e1
#REPO=https://github.com/rtakeda/advdev_homework_template.git
#CLUSTER=https://master.na311.openshift.opentlc.com

echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
oc project ${GUID}-jenkins
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true

# Create custom agent container image with skopeo
oc new-build -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n\ 
USER root\nRUN yum -y install skopeo && yum clean all\n\
USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
#oc create -f tasks-pipeline.yaml -n ${GUID}-jenkins
echo "apiVersion: v1
items:
- kind: BuildConfig
  apiVersion: v1
  metadata:
    name: tasks-pipeline
  spec:
    source:
      type: Git
      git:
        uri: https://github.com/rtakeda/advdev_homework_template.git
      contextDir: openshift-tasks
    strategy:
      type: JenkinsPipeline
      jenkinsPipelineStrategy:
        jenkinsfilePath: Jenkinsfile
        env:
          - name: GUID
            value: ${GUID} 
          - name: REPO
            value: ${REPO}
          - name: CLUSTER
            value: ${CLUSTER}
kind: List
metadata: []" | oc create -f - -n ${GUID}-jenkins

#oc secrets new-basicauth jenkins-secret --username=jenkins --password=redhat -n ${GUID}-jenkins
#oc create secret new-basicauth jenkins-secret --username=jenkins --password=redhat -n ${GUID}-jenkins
#oc create secret docker-registry jenkins-secret --docker-server=docker-registry.default.svc:5000 --docker-username=jenkins --docker-password=redhat
#oc secrets link jenkins jenkins-secret --for=pull
#oc set build-secret --source bc/tasks-pipeline jenkins-secret -n ${GUID}-jenkins

# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done

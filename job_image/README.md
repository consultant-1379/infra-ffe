# Jenkins Job image

# Introduction

The deploy-ffe-infra-vms.yml Ansible playbook is run in a docker container by a Jenkins job. The Jenkins job is configured to use a specific docker image registry._infra-awx-k3s.athtem.eei.ericsson.se/ffl-ansible:latest_.
The Dockerfile in this directory is used to build this image.

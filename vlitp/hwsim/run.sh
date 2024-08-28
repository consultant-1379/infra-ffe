#!/bin/sh

set -xv

DEPLOYMENT_NAME=$1
if [ -z "${DEPLOYMENT_NAME}" ] ; then
    echo "ERROR: $0 <DEPLOYMENT_NAME>"
fi

cd /hwsim/src

export PYTHONPATH=.

python3 hw_sim.py \
 --sed /hwsim/etc/MASTER_siteEngineering.txt \
 --debug \
 --deployment ${DEPLOYMENT_NAME} \
 --mediator http://localhost:5000 \
 --log /hwsim/log/hw-sim.log \
 --state /hwsim/var/state.json \
 --cert /hwsim/etc/localhost.pem &

export OS_VOLUME_API_VERSION=3.59
export FLASK_APP=mediator.py 
export FLASK_HOST=0.0.0.0
export OS_CLIENT_CONFIG_FILE=/hwsim/etc/clouds.yml

python3 -m flask run --host=0.0.0.0 &

 wait
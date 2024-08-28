from threading import Thread
import argparse
import json
import logging
from socketserver import ThreadingMixIn
import re

from ilo_sim import ilo_init
from unity_sim import unity_init
from mediatorrest import MediatorREST

def config_from_sed(sed):
    config = {
        'hosts': [],
        'unity': {}
    }

    hostsByKey = {}

    lines = []
    with open(sed, "r") as f:
        lines = f.readlines()

    for line in lines:
        if "=" in line:
            (name, value) = line.strip().split("=",1)
            if value is not None and value != "":
                match = re.match(r"(^[a-z]+)_node(\d+)_(.*)", name)
                if match:
                    cluster = match.group(1)
                    node_id = match.group(2)
                    param = match.group(3)

                    if param == "hostname":
                        host_index = len(config['hosts']) + 1
                        host = {
                            'cluster': cluster,
                            'node_id': node_id,
                            'hostname': value,
                            'host_index': host_index
                        }
                        config['hosts'].append(host)
                        hostsByKey["{}:{}".format(cluster, node_id)] = host
                    elif param == "ilo_IP":
                        hostsByKey["{}:{}".format(cluster, node_id)]['address'] = value
                elif name.startswith("LMS_"):
                    if name == "LMS_hostname":
                        host_index = len(config['hosts']) + 1
                        host = {
                            'cluster':  'lms',
                            'node_id': 1,
                            'hostname': value,
                            'host_index': host_index
                        }
                        config['hosts'].append(host)
                        hostsByKey["lms"] = host
                    elif name == "LMS_ilo_IP":
                        hostsByKey["lms"]["address"] = value
                elif name == 'san_spaIP':
                    config['unity']['ip'] = value
                elif name == 'san_poolName':
                    config['unity']['pool'] = value
    logging.debug("config_from_sed: config=%s", config)
    return config

parser = argparse.ArgumentParser()
parser.add_argument("--sed")
parser.add_argument("--mediator")
parser.add_argument("--deployment")
parser.add_argument("--extip")
parser.add_argument("--log")
parser.add_argument("--state")
parser.add_argument("--cert")

parser.add_argument('--debug', help='debug logging', action="store_true")
args = parser.parse_args()

logging_level = logging.WARN
if args.debug:
    logging_level = logging.DEBUG

logging.basicConfig(filename=args.log, filemode='w', format='%(asctime)s - %(levelname)s - %(threadName)s - %(message)s', level=logging_level)

config = config_from_sed(args.sed)

config['extip'] = args.extip
config['state_file'] = args.state
config['cert'] = args.cert

meditator = MediatorREST(args.mediator, args.deployment)
unity_init(config, meditator)
ilo_init(config, meditator)

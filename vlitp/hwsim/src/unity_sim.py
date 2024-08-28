from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import logging
import ssl
import os.path
import urllib.parse
import re
from threading import Thread
from mediatorrest import MediatorREST
from threading import Thread
from datetime import datetime, timezone

unity_data = {}
state_file = None
logger = None
mediator = None
cert_file = None

#
# Public functions
#
def unity_init(config, _mediator):
    global logger
    global mediator
    global state_file, cert_file

    logger = logging.getLogger('unity_sim')
    mediator = _mediator

    state_file = config['state_file']
    cert_file = config['cert']

    loadData(config)

    Thread(name='unity-server', target=_start_server).start()


def unity_register_hba(wwn):
    for hostInitiator in unity_data["hostInitiator"]["inst"].values():
        if hostInitiator['initiatorId'].startswith(wwn):
            logger.debug("unity_register_hba: found existing hostInitiator %s for %s", hostInitiator['id'], wwn)
            return

    unity_data["hostInitiator"]["counter"] = unity_data["hostInitiator"]["counter"] + 1
    host_initiator_index = unity_data["hostInitiator"]["counter"]
    host_initiator_id = "HostInitiator_{}".format(host_initiator_index)

    initiatorId = "{}:{}".format(wwn, wwn)
    unity_data["hostInitiator"]["inst"][host_initiator_id] = {
        "id": host_initiator_id,
        "initiatorId": initiatorId,
        "isIgnored": False,
        'paths': [
            {
                'id': "{}_00:00:00:01_0".format(host_initiator_id)
            },
            {
                'id': "{}_00:00:00:02_0".format(host_initiator_id)
            }
        ]
    }

    for sp_index in range(1,3):
        host_initiator_path_id = "{}_00:00:00:{:02X}_0".format(host_initiator_id, sp_index)
        if sp_index == 1:
            sp = 'a'
        else:
            sp = 'b'
        unity_data["hostInitiatorPath"]["inst"][host_initiator_path_id] = {
            'id': host_initiator_path_id,
            'fcPort': {
                'id': "sp{}_iom_0_fc0".format(sp)
            }
        }
    saveData()

def unity_get_luns(wwn):
    logger.debug("unity_get_luns: wwn=%s", wwn)
    host_id = None
    for hostInitiator in unity_data['hostInitiator']['inst'].values():
        if hostInitiator['initiatorId'].startswith(wwn) and 'host' in hostInitiator:
            host_id = hostInitiator['host']['id']
            logger.debug("unity_get_luns: matched host_id %s", host_id)

    if host_id is None:
        logging.info("No match for WWN {}".format(wwn))
        return []

    results = []
    host = get_inst('host', host_id)
    logger.debug("unity_get_luns: host=%s", host)
    if 'hostLUNs' in host:
        for entry in host['hostLUNs']:
            hostLUN = get_inst('hostLUN', entry['id'])
            logger.debug("get_attached: hostLUN=%s", hostLUN)
            lun = get_inst('lun', hostLUN['lun']['id'])
            logger.debug("get_attached: lun=%s", lun)
            # As this lun is attached to to this host, hostAccess has to exist
            shared = len(lun['hostAccess']) > 1
            results.append({
                'name': lun['name'],
                'id': lun['wwn'],
                'hlu': hostLUN['hlu'],
                'shared': shared
            })

    return results


#
# Private functions
#
def _start_server():
    global unity_data, cert_file
    server = HTTPServer((unity_data['_ip'], 443), UnityHandler)

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=cert_file)
    server.socket = context.wrap_socket(
        server.socket,
        server_side=True
    )

    server.serve_forever()

def saveData():
    global unity_data, state_file

    with open(state_file, 'w') as outfile:
        json.dump(unity_data, outfile)

def loadData(config):
    global unity_data, state_file

    if os.path.isfile(state_file):
        with open(state_file, 'r') as infile:
            unity_data = json.load(infile)
    else:
        unity_data = {
            "_volumes": {},
            "_snapshots": {},
            "alert": {
                "inst": {}
            },
            "host" : {
                "counter": 0,
                "inst": {}
            },
            "hostInitiator": {
                "counter": 0,
                "inst": {}
            },
            "hostInitiatorPath": {
                "counter": 0,
                "inst": {}
            },
            "pool": {
                "counter": 1,
                "inst": {
                    "pool_1": {
                        "id": "pool_1",
                        "name": config['unity']['pool'],
                        "raidType": 1,
                        "tiers": [
                            {
                                "diskCount": 15,
                            }
                        ],
                        "sizeFree": 4772245536768,
                        "sizeSubscribed": 31992933548032,
                        "sizeTotal": 21696832602112
                    }
                }
            },
            "lun": {
                "counter": 0,
                "inst": {}
            },
            "snap": {
                "counter": 0,
                "inst": {}
            },
            "hostLUN": {
                "inst": {}
            },
            "user": {
                "inst": {
                    "user_admin": {}
                }
            },
            "metricService": {
                "inst": {
                    "0": {
                        "id": 0,
                        "isHistoricalEnabled": True
                    }
                }
            }
        }

    unity_data['_ip'] = config['unity']['ip']


def parse_path(path):

    args_kv = {}
    if "?" in path:
        (path,args) = path.split('?')
        args = urllib.parse.unquote(args).split("&")
        for arg in args:
            (key,value) = arg.split("=",1)
            args_kv[key] = value

    path_parts = path.split('/')
    path_parts = path_parts[2:]
    if path_parts[-1] == '':
        path_parts.pop()

    return (path_parts, args_kv)


def get_inst(type_name, id):
    global unity_data

    if type_name not in unity_data or id not in unity_data[type_name]["inst"]:
        return None

    return unity_data[type_name]["inst"][id]

def getInstance(type_name, id):
    global unity_data

    logger.debug("getInstance: type_name=%s id=%s", type_name, id)

    if type_name == 'storageResource':
        type_name = 'lun'

    if type_name not in unity_data:
        return None

    instance = None
    if id in unity_data[type_name]["inst"]:
        instance = unity_data[type_name]["inst"][id]
    elif id.startswith("name:"):
        name = id.split(":")[1]
        for inst in unity_data[type_name]["inst"].values():
            logger.debug("getInstance: checking inst=%s", inst)
            if inst["name"] == name:
                instance = inst

    logger.debug("getInstance: instance=%s", instance)
    return instance

def getInstances(path):
    (path_parts, args_kv) = parse_path(path)

    logger.debug("getInstances: path_parts=%s, args=%s", path_parts, args_kv)

    response_code = 403
    instance = getInstance(path_parts[1], path_parts[2])
    if instance is not None:
        response_code = 200

    return response_code, { "content": instance }

def createHost(data):
    global unity_data

    host_id = "Host_{}".format(unity_data["host"]["counter"])
    unity_data["host"]["counter"] = unity_data["host"]["counter"] + 1

    if data['name'] in unity_data["host"]["inst"]:
        return None

    host = {
        "type": data['type'],
        "name": data['name'],
        "id": host_id
    }

    logger.debug("createHost: host=%s", host)

    unity_data["host"]["inst"][host["id"]] = host

    return host["id"]

def removeHost(instance):
    host_id = instance['id']

    for hostInitiator in unity_data['hostInitiator']['inst'].values():
        if 'host' in hostInitiator and hostInitiator['host']['id'] == host_id:
            del hostInitiator['host']
            logger.debug("removeHost: removing host_id %s from %s", host_id, hostInitiator['id'])

def removeSnapshot(instance):
    snapshot = unity_data["_snapshots"][instance['id']]

    if "fake_snapshot" not in unity_data["_snapshots"][instance['id']]:
        mediator.request("/snapshot/{}".format(snapshot['mid']), method="DELETE")
    del unity_data["_snapshots"][instance['id']]

def restoreSnapshot(path,data):
    global unity_data

    (path_parts, args) = parse_path(path)
    snap = getInstance("snap", path_parts[2])
    if snap is None:
        logger.warning("restoreSnapshot: get could find snap %s", path_parts[2])
        return None

    if snap['id'] not in unity_data['_snapshots']:
        logger.warning("restoreSnapshot: get could find snapshot for snap %s", snap)
        return None
    snapshot = unity_data['_snapshots'][snap['id']]

    lun = getInstance("lun", snapshot["lun_id"])
    volume = unity_data["_volumes"][lun['name']]

    revert_param = { "snapshot_id": snapshot['mid'] }
    try:
        revert_result = mediator.request("/volume/{}/revert".format(volume['mid']), method="POST", data=revert_param)
    except Exception as exp:
        logger.error("volume revert failed", exp)
        return None

    logger.info("revert result %s", revert_result)
    if not revert_result['ok']:
        logger.warning("restoreSnapshot failed to revert volume %s", revert_result)
        return None

    # Need to fake the backup snapshot
    if 'copyName' in data:
        backup_snap_name = data['copyName']
    else:
        backup_snap_name = 'backup_' . snap['name']

    unity_data["snap"]["counter"] = unity_data["snap"]["counter"] + 1
    snap_index = unity_data["snap"]["counter"]
    snap_id = "{:011d}".format(snap_index)

    snap = {
        "id": snap_id,
        "name": backup_snap_name,
        "lun": {
            "id": lun['id']
        },
        "description": "",
        "creationTime": datetime.now(timezone.utc).isoformat(timespec='milliseconds'),
        "state": 2 # Ready
    }
    unity_data["snap"]["inst"][snap_id] = snap

    # The Unity automatically creates a snapshot when you
    # restore, we don't want to fully match this so we
    # create a "fake_snapshot"
    # We'll check when delete a snapshot if it's fake, if
    # so we don't have to anything.
    unity_data["_snapshots"][snap_id] = {
        "fake_snapshot": True
    }
    return {'content': {'backup': {'id': snap_id}}}


def createLUN(data):
    global unity_data
    global mediator

    logger.debug("createLUN data=%s", data)

    for inst in unity_data["lun"]["inst"].values():
        logger.debug("createLUN inst=%s", inst)
        if inst["name"] == data['name']:
            logger.warning("createLUN name already in use in inst %s", inst)
            return None

    volume_param = { 'name': data['name'], 'size': data['lunParameters']['size'] }
    logger.info("requesting new volume %s", volume_param)
    try:
        create_result = mediator.request("/volume", 'POST', volume_param)
    except Exception as exp:
        logger.error("volume create failed", exp)
        return None

    logger.info("create result %s", create_result)
    if not create_result['ok']:
        logger.warning("createLUN failed to crete volume %s", create_result)
        return None

    unity_data["lun"]["counter"] = unity_data["lun"]["counter"] + 1
    lun_index = unity_data["lun"]["counter"]
    lun_id = "sv_{}".format(lun_index)

    unity_data["_volumes"][data["name"]] = {
        "name": data["name"],
        "mid": create_result["id"],
        "lun_id": lun_id
    }

    #www_digits = "{:06X}".format(int(lun_index))
    #wwn = ":".join(['00:00:00:00:00:00:00:00:00:00:00:00:00', www_digits[0:2], www_digits[2:4], www_digits[4:6]])

    lun = {
        "id": lun_id,
        "name": data['name'],
        "wwn": unity_data["_volumes"][data["name"]]["mid"],
        "hostAccess": []
    }

    for key, value in data['lunParameters'].items():
        logger.debug("createLUN setting %s=%s", key, value)
        lun[key] = value

    if 'defaultNode' in lun:
        lun['currentNode'] = lun['defaultNode']

    if 'size' in lun:
        lun['sizeTotal'] = lun['size']

    unity_data["lun"]["inst"][lun_id] = lun

    return lun_id

def createSnap(data):
    global unity_data
    global mediator

    logger.debug("createSnap data=%s", data)

    lun_id = data["storageResource"]["id"]
    if not lun_id in unity_data["lun"]["inst"]:
        logger.warn("Invalid lun id %s", lun_id)
        return None

    lun = unity_data["lun"]["inst"][lun_id]
    if lun['name'] not in unity_data["_volumes"]:
        logger.warn("Could not find lun %s in _volumes", lun['name'])
        return None

    volume = unity_data["_volumes"][lun['name']]

    snapshot_param = { 'name': data['name'], 'volume_id': volume['mid'] }
    logger.info("requesting new snapshot %s", snapshot_param)
    try:
        create_result = mediator.request("/snapshot", 'POST', snapshot_param)
    except Exception as exp:
        logger.error("snapshot create failed", exp)
        return None

    logger.info("create result %s", create_result)
    if not create_result['ok']:
        logger.warning("createSnap failed to create snapshot %s", create_result)
        return None

    unity_data["snap"]["counter"] = unity_data["snap"]["counter"] + 1
    snap_index = unity_data["snap"]["counter"]
    snap_id = "{:011d}".format(snap_index)

    snapshot_key = snap_id
    unity_data["_snapshots"][snapshot_key] = {
        "name": data["name"],
        "lun_id": lun_id,
        "snap_id": snap_id,
        "mid": create_result["id"]
    }

    snap = {
        "id": snap_id,
        "name": data['name'],
        "lun": {
            "id": lun_id
        },
        "description": "",
        "creationTime": datetime.now(timezone.utc).isoformat(timespec='milliseconds'),
        "state": 2 # Ready
    }
    unity_data["snap"]["inst"][snap_id] = snap

    return snap_id

def createType(path, data):
    path_parts = path.split('/')
    path_parts = path_parts[3:]
    if path_parts[-1] == '':
        path_parts.pop()
    logger.debug("createType: path_parts=%s", path_parts)

    type_name = path_parts[0]
    logger.debug("createType: type_name=%s", type_name)

    id = None
    if type_name == 'host':
        id = createHost(data)
    elif type_name == 'storageResource' and path_parts[-1] == 'createLun':
        id = createLUN(data)
    elif type_name == 'snap':
        id = createSnap(data)

    if id is not None:
        id_struct = { "id": id }
        if type_name == 'storageResource':
            content = { type_name: id_struct }
        else:
            content = id_struct
        return { 'content': content }
    else:
        return None

def getHostLunForLun(lun_id):
    logger.debug("getHostLunForLun: searching for lun_id=%s", lun_id)
    results = []
    for instance in unity_data["hostLUN"]["inst"].values():
        logger.debug("getHostLunForLun: checking instance %s", instance)
        if instance['lun']['id'] == lun_id:
            results.append(instance)
    return results

def getHostLunForHost(host_id):
    logger.debug("getHostLunForHost: searching for host_id=%s", host_id)
    results = []
    for instance in unity_data["hostLUN"]["inst"].values():
        logger.debug("getHostLunForHost: checking instance %s", instance)
        if instance['host']['id'] == host_id:
            results.append(instance)
    return results

def updateHostLUNs(host, hostlun_id, add):
    if add:
        if 'hostLUNs' not in host:
            host['hostLUNs'] = []
        host["hostLUNs"].append({ 'id': hostlun_id })
    else:
        if 'hostLUNs' not in host:
            logger.error("Tried to remove hostLUNs entry when hostLUNs doesn't exist")
            return

        updated_hostLUNs = []
        for entry in host['hostLUNs']:
            if entry['id'] != hostlun_id:
                updated_hostLUNs.append(entry)

        host['hostLUNs'] = updated_hostLUNs
        if len(host['hostLUNs']) == 0:
            del host['hostLUNs']

def modifyHostAccess(lun, data):
    global unity_data

    logger.debug("modifyHostAccess: lun=%s data=%s", lun, data)

    lun_id = lun['id']

    # dict for all the existing hostLUNs for this lun keyed by the id
    # of the host lun
    existing_hostlun_ids = {}
    for hostlun in getHostLunForLun(lun_id):
        existing_hostlun_ids[hostlun['id']] = hostlun

    # Note: at this point the hostAccess attr has already be updated to the
    # new value
    for entry in lun['hostAccess']:
        logger.debug("modifyHostAccess: processing hostAccess entry=%s", entry)
        entry['productionAccess'] = 1
        entry['snaphostAccess'] = 0

        host_id = entry['host']['id']
        hostlun_id = "_".join([host_id, lun_id, "prod"])
        logger.debug("modifyHostAccess: hostlun_id=%s", hostlun_id)

        if hostlun_id in existing_hostlun_ids:
            existing_hostlun_ids.pop(hostlun_id)
        else:
            hlus = []
            for a_hostlun in getHostLunForHost(host_id):
                hlus.append(a_hostlun['hlu'])
            hlu = 0
            while hlu in hlus:
                hlu = hlu + 1

            hostlun = {
                'id': hostlun_id,
                'type': 1,
                'hlu': hlu,
                'host': { 'id': host_id },
                'lun': { 'id': lun_id }
            }
            logger.debug("modifyHostAccess: creating hostLUN=%s", hostlun)
            unity_data["hostLUN"]["inst"][hostlun_id] = hostlun

            host = unity_data["host"]["inst"][host_id]
            updateHostLUNs(host, hostlun_id, True)

    # When we get here, all the valid entries in existing_hostlun_ids have
    # been removed, anything left needs to be deleted
    for hostlun_id in existing_hostlun_ids:
        hostlun = unity_data["hostLUN"]["inst"][hostlun_id]
        logger.debug("modifyHostAccess processing hostlun for removal %s", hostlun)
        host = unity_data["host"]["inst"][hostlun['host']['id']]
        updateHostLUNs(host, hostlun_id, False)

        # 'delete' the un-used hostLUN
        unity_data["hostLUN"]["inst"].pop(hostlun['id'])

def modifyLUN(path, data):
    global unity_data

    path_parts = path.lower().split('/')
    path_parts = path_parts[3:]
    if path_parts[-1] == '':
        path_parts.pop()

    type_name = path_parts[0]
    id = path_parts[1]
    logger.debug("modifyLUN: type_name=%s id=%s", type_name, id)

    if id not in unity_data["lun"]["inst"]:
        logger.warning("modifyLUN: %s not found", id)
        return False

    instance = unity_data["lun"]["inst"][id]
    for key, value in data['lunParameters'].items():
        logger.debug("modifyLUN setting %s=%s", key, value)
        instance[key] = value
        if key == 'hostAccess':
            modifyHostAccess(instance, data)

    return True

def modifyHostLUNs(path,data):
    global unity_data

    (path_parts, args) = parse_path(path)
    host_id = path_parts[2]

    if host_id not in unity_data["host"]["inst"]:
        return False

    lun = unity_data["host"]["inst"][host_id]

    for hostLunModify in data["hostLunModifyList"]:
        logger.debug("modifyHostLUN: hostLunModify=%s", hostLunModify)
        hostlun = unity_data["hostLUN"]["inst"][hostLunModify["hostLUN"]["id"]]
        logger.debug("modifyHostLUN: hostlun=%s", hostlun)
        hostlun["hlu"] = hostLunModify["hlu"]
        lun = unity_data["lun"]["inst"][hostlun["lun"]["id"]]
        logger.debug("modifyHostLUN: lun=%s", lun)
        for entry in lun["hostAccess"]:
            if entry["host"]["id"] == hostlun["host"]["id"]:
                logger.debug("modifyHostLUN: updating hlu in %s", entry)
                entry["hlu"] = hostLunModify["hlu"]

    return True

def modifyInstance(path, data):
    global unity_data


    (path_parts, args) = parse_path(path)

    type_name = path_parts[1]
    id = path_parts[2]
    logger.debug("modifyInstance: type_name=%s id=%s", type_name, id)

    if type_name in unity_data and id in unity_data[type_name]["inst"]:
        instance = unity_data[type_name]["inst"][id]
        logger.debug("modifyInstance: instance=%s", instance)
        for key, value in data.items():
            instance[key] = value
        return True
    else:
        logger.warning("modifyInstance: Cannot find type_name=%s with id %s", type_name, id)
        return False

def applyFilter(entries, type_name, args):
    if "filter" not in args or len(entries) == 0:
        return entries

    filter = args["filter"]
    logger.debug("applyFilter: filter=%s", filter)

    match = re.search(r'^host.id eq "(\S+)" and lun.id eq "(\S+)"$', filter)
    if match:
        results = []
        (host_id, lun_id) = match.group(1,2)
        logger.debug("applyFilter: host %s and lun %s", host_id, lun_id)
        for entry in entries:
            if entry["host"]["id"] == host_id and entry["lun"]["id"] == lun_id:
                results.append(entry)
        return results

    match = re.search(r'^id IN \( (\S+) \)$', filter)
    if match:
        results = []
        ids = match.group(1).replace('"','').split(",")
        logger.debug("applyFilter: id filter %s", ids)
        for entry in entries:
            if entry["id"] in ids:
                results.append(entry)
        return results

    match = re.search(r"^initiatorId eq \"(\S+)\"", filter)
    if match:
        initiatorId = match.group(1)
        results = []
        logger.debug("applyFilter: initiatorId filter %s", initiatorId)
        for entry in entries:
            if entry["initiatorId"] == initiatorId:
                results.append(entry)
        return results

    # enm_snapshost.sh list snapshots
    if type_name == 'lun':
        match = re.search(r"^pool.id eq \"(\S+)\"", filter)
        if match:
            pool_id = match.group(1)
            results = []
            for entry in entries:
                if entry['pool']['id'] == pool_id:
                    results.append(entry)
            return results

    raise Exception("applyFilter: unsupported filter '%s'", filter)

def getTypeInstances(path):
    global unity_data

    (path_parts, args_kv) = parse_path(path)

    logger.debug("getTypeInstances: path_parts=%s, args=%s", path_parts, args_kv)

    type_name = path_parts[1]

    response_code = 500
    entries = []
    if type_name in unity_data:
        entries = unity_data[type_name]["inst"].values()
        entries = applyFilter(entries, type_name, args_kv)
        response_code = 200
    elif type_name == 'loginSessionInfo':
        response_code = 200

    wrapped_entries = []
    for entry in entries:
        wrapped_entries.append({ 'content': entry })
    return response_code, { 'entries': wrapped_entries }



class UnityHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        global unity_data

        logger.debug("do_GET: path=%s", self.path)

        resp_headers = {}
        reply_data = { 'content': None }
        path_lower = self.path.lower()

        response_code = 500

        if path_lower.startswith("/host/getattached"):
            response_code, reply_data = get_attached(self.path)
        if path_lower.startswith("/api/instances/"):
            response_code, reply_data = getInstances(self.path)
        elif path_lower.startswith("/api/types/"):
            response_code, reply_data = getTypeInstances(self.path)

        if path_lower == "/api/types/loginsessioninfo/instances":
            resp_headers["EMC-CSRF-TOKEN"] = "TOKEN-VALUE"
            resp_headers["Set-Cookie"] = "Cookie"

        self.send_response(response_code)

        self.send_header("content-type", "application/json")
        for key, value in resp_headers.items():
            self.send_header(key, value)

        self.end_headers()

        if reply_data is not None:
            reply_data_str = json.dumps(reply_data)
            logger.debug("do_GET: reply_data_Str=%s", reply_data_str)
            self.wfile.write(bytes(reply_data_str, "utf-8"))

    def do_PUT(self):
        global unity_data
        logger.debug("do_PUT: server=%s path=%s", self.server.server_name, self.path)

        content_length = self.headers['Content-Length']
        data_str = self.rfile.read(int(content_length))
        data = json.loads(data_str)
        logger.debug("do_PUT: data=%s", data)

        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()

    def do_PATCH(self):
        global address_map
        logger.debug("do_PATCH: server=%s path=%s", self.server.server_name, self.path)
        content_length = self.headers['Content-Length']
        data_str = self.rfile.read(int(content_length))
        data = json.loads(data_str)
        logger.debug("do_PATCH: data=%s", data)

        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()

    def do_POST(self):
        global address_map
        logger.debug("do_POST: path=%s", self.path)
        content_length = self.headers['Content-Length']
        data_str = self.rfile.read(int(content_length))
        data = json.loads(data_str)
        logger.debug("do_POST: data=%s", data)

        resp_headers = {}
        response_code = 500
        reply_data = None

    	# Logout is a bit werid with an action called on a type, not an instance
        if self.path.startswith("/api/types/loginSessionInfo/action/logout"):
            response_code = 200
        elif self.path.startswith("/api/types/"):
            reply_data = createType(self.path, data)
            if reply_data is not None:
                response_code = 200
        elif self.path.startswith("/api/instances/") and self.path.endswith("action/modify"):
            if modifyInstance(self.path, data):
                response_code = 200
        elif self.path.startswith("/api/instances/storageResource/") and self.path.endswith("action/modifyLun"):
            if modifyLUN(self.path, data):
                response_code = 200
        elif self.path.startswith("/api/instances/host/") and self.path.endswith("action/modifyHostLUNs"):
            if modifyHostLUNs(self.path, data):
                response_code = 200
        elif self.path.startswith("/api/instances/snap/") and self.path.endswith("action/restore"):
            reply_data = restoreSnapshot(self.path, data)
            if reply_data is not None:
                response_code = 200

        self.send_response(response_code)
        self.send_header("Content-type", "application/json")
        for key, value in resp_headers.items():
            self.send_header(key, value)
        self.end_headers()

        if response_code == 200:
            saveData()

        if reply_data is not None:
            reply_data_str = json.dumps(reply_data)
            logger.debug("do_POST: reply_data_Str=%s", reply_data_str)
            self.wfile.write(bytes(reply_data_str, "utf-8"))

    def do_DELETE(self):
        global mediator
        global unity_data

        logger.debug("do_DELETE: server=%s path=%s", self.server.server_name, self.path)

        (path_parts, args) = parse_path(self.path)

        type_name = path_parts[1]
        id = path_parts[2]

        instance = getInstance(type_name, id)
        logger.debug("do_DELETE: instance=%s", instance)

        if type_name == 'storageResource':
            type_name = 'lun'

        if instance is not None:
            if type_name == 'lun' and instance['name'] in unity_data["_volumes"]:
                    volume = unity_data["_volumes"][instance['name']]
                    mediator.request("/volume/{}".format(volume['mid']), method="DELETE")
                    del unity_data["_volumes"][instance['name']]
            elif type_name == 'host':
                removeHost(instance)
            elif type_name == 'snap':
                removeSnapshot(instance)

            del unity_data[type_name]["inst"][instance['id']]
            response_code = 204
        else:
            logger.warning("do_DELETE: Cannot find type_name=%s with id %s", type_name, id)
            response_code = 500

        saveData()

        self.send_response(response_code)
        self.end_headers()




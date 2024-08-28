from flask import Flask, jsonify, request
import json
import logging
import openstack
import os
from openstack import utils
import time

os_conn = None
logger = None
mediator_config = None
MEDIATOR_CONFIG_FILE="/hwsim/etc/mediator_config.json"

app = Flask(__name__)

with app.app_context():
    print("Starting")
    logging.basicConfig(format='%(asctime)s - %(levelname)s - %(message)s')

    logger = logging.getLogger("mediatior")
    logger.setLevel(logging.DEBUG)

    #openstack.enable_logging(debug=True)
    os_conn = openstack.connect(cloud='openstack')

    with open(MEDIATOR_CONFIG_FILE) as mc:
        mediator_config = json.load(mc)

def get_name(deployment, name):
    return '{}_{}'.format(deployment, name)

def get_preprov_volumes(deployment, server):
    results = []
    # Look for manually created volumes
    for volume in os_conn.block_storage.volumes():
        if volume.description is not None and volume.description.startswith("{"):
            volume_data = json.loads(volume.description)
            if 'type' in volume_data and volume_data['type'] == 'preprov' and 'deployment' in volume_data and volume_data['deployment'] == deployment and 'server' in volume_data and volume_data['server'] == server:
                logger.info("Found preprov volume %s %s", volume.name, volume.id)
                results.append({
                    'name': volume.name,
                    'mid': volume.id,
                    'size': volume.size,
                })

    return results

@app.route('/image/', methods=['POST'])
def create_image():
    global os_conn
    global logger

    data = json.loads(request.data)
    logger.info("create_image, data = %s", data)

    image_via_import = False
    properties = {
        "hw_scsi_model": "virtio-scsi",
        "hw_disk_bus": "scsi",
        "hw_firmware_type": "uefi",
        "hw_machine_type": "q35",
        "architecture": "x86_64"
    }
    try:
        if image_via_import:
            image = os_conn.image.create_image(
                name = get_name(data['deployment'], data['name']),
                container_format = 'bare',
                disk_format = 'iso',
                tags = [ data['deployment'] ],
                properties = properties
            )
            result = os_conn.image.import_image(image, method='web-download', uri=data['url'])
            logger.info("create_image: import_image result = %s", result)
        else:
            filename = '/images/{}'.format(data['name'])
            if not os.path.exists(filename):
                return jsonify({ 'ok': False, "msg": "Cannot find {0}".format(filename)})

            image = os_conn.image.create_image(
                name = get_name(data['deployment'], data['name']),
                container_format = 'bare',
                disk_format = 'iso',
                tags = [ data['deployment'] ],
                properties = properties,
                filename=filename
            )

        return jsonify({ 'ok': True, "id": image.id})
    except Exception as e:
        return jsonify({ 'ok': False, 'msg': str(e)})

@app.route('/server_volumes/<string:name>', methods=['GET'])
def server_volumes(name):
    data = json.loads(request.data)
    results = get_preprov_volumes(data['deployment'], name)

    return jsonify({'ok': True, "volumes": results})

@app.route('/volume', methods=['POST'])
def create_volume():
    global os_conn
    global logger

    data = json.loads(request.data)
    logger.info("create_volume, data = %s", data)

    description = json.dumps({ "type": "mediator", "deployment": data['deployment'] })
    size_in_gb = int(data['size']/(1024*1024*1024))
    if size_in_gb == 0:
        size_in_gb = 1
    volume = os_conn.block_storage.create_volume(
        name=get_name(data['deployment'], data['name']),
        size=size_in_gb,
        description=description
    )
    logger.info("create_volume, volume = %s", volume)

    return jsonify({ 'ok': True, "id": volume.id})

@app.route('/volume/<string:mid>', methods=['DELETE'])
def delete_volume(mid):
    global os_conn

    status = ''
    count = 0
    while count < 10 and status != 'available':
        count = count + 1
        volume = os_conn.block_storage.get_volume(mid)
        status = volume.status
        logger.debug("delete_volume: %s status %s", volume.name, volume.status)
        if status != 'available':
            time.sleep(1)

    if status != 'available':
        return jsonify({ 'ok': False, "msg": "invalid volume status {} for {}".format(volume.name, status)})

    os_conn.block_storage.delete_volume(mid)
    return jsonify({ 'ok': True, "id": "mid"})

@app.route('/volume/<string:mid>/revert', methods=['POST'])
def revert_volume(mid):
    global os_conn

    data = json.loads(request.data)
    logger.info("revert_volume %s, data = %s", mid, data)

    volume = os_conn.block_storage.get_volume(mid)
    if volume.status != 'available':
        msg = "Invalid state for volume {}: {}".format(volume.name, volume.status)
        logger.warning(msg)
        return jsonify({ 'ok': False, 'msg': msg})

    #os_conn.block_storage.revert_volume_to_snapshot(mid, data['snapshot_id'])
    # Fails with version error
    resp = os_conn.session.post(
        utils.urljoin("volumes", mid, 'action'),
        json={ "revert": { "snapshot_id": data["snapshot_id"]}},
        microversion='3.59',
        microversion_service_type='volume',
        endpoint_filter={
            'service_type': 'block-storage',
            'interface': 'public',
            'min_version': '3',
            'max_version': 'latest'
        }
    )
    logging.info("revert resp %s", resp)

    return jsonify({ 'ok': True})

@app.route('/snapshot', methods=['POST'])
def create_snapshot():
    global os_conn
    global logger

    data = json.loads(request.data)
    logger.info("create_snapshot, data = %s", data)

    description = json.dumps({ "type": "mediator", "deployment": data['deployment'] })
    snapshot = os_conn.block_storage.create_snapshot(
        name=get_name(data['deployment'], data['name']),
        is_forced=True,
        volume_id=data['volume_id'],
        description=description
    )
    logger.info("create_snapshot, snapshot = %s", snapshot)

    return jsonify({ 'ok': True, "id": snapshot.id})

@app.route('/snapshot/<string:mid>', methods=['DELETE'])
def delete_snapshot(mid):
    global os_conn
    os_conn.block_storage.delete_snapshot(mid)
    return jsonify({ 'ok': True, "id": "mid"})

@app.route('/server/<string:name>', methods=['GET'])
def server_get(name):
    global os_conn
    global logger

    data = json.loads(request.data)

    server_name = get_name(data['deployment'], name)

    server = os_conn.compute.find_server(server_name)
    if server is None:
        return jsonify({ 'ok': True, "power_state": None})

    logger.info("server_power_get: name=%s server.status=%s", server_name, server.status)

    if server.status == 'ACTIVE':
        return jsonify({ 'ok': True, "power_state": 'On', "ready": True})
    elif server.status == 'BUILD':
        return jsonify({ 'ok': True, "power_state": 'On', "ready": False})
    else:
        return jsonify({ 'ok': True, "power_state": 'Off'})

@app.route('/server/<string:name>/<string:action>', methods=['POST'])
def server_power_set(name, action):
    global os_conn
    global logger

    data = json.loads(request.data)
    logger.info("server, name = %s, action = %s", name, action)

    if action == 'PowerOn':
        result = create_server(name, data)
    elif action == 'PowerOff':
        result = delete_server(name, data)
    else:
        result = { 'ok': False, "msg": "Unknown action: {} for {}".format(name, action)}

    return result

def create_server(name, data):
    global os_conn
    global logger
    global mediator_config
    flavor_name = ""
    logger.debug("from request: %s",data["flavor"])

    logger.info(mediator_config)

    try:
        flavor_name = mediator_config["flavors"][data["flavor"]]
    except KeyError as ke:
        logger.error("Flavor for %s nodes does not exist - trying default flavor",ke)
        flavor_name = mediator_config["flavors"]["default"]

    flavor = os_conn.compute.find_flavor(flavor_name)
    if flavor is None:
        logging.warning("Could not find flavour %s", flavor_name)
        return jsonify({ "ok": False, "msg": "Could not find requested flavor {}".format(flavor_name)})
    logger.info("flavor_name=%s",flavor_name)

    networks = []
    for mac in data['nics']:
        logger.info("searching for port with MAC address = %s", mac)

        port_iterator = os_conn.network.ports(mac_address=mac, tags=data['deployment'])
        ports = []
        for port in port_iterator:
            logger.debug("candiate port = %s %s", port.name, port.id)
            ports.append(port)

        selected_port = None
        if len(ports) == 1:
            selected_port = ports[0]
        else:
            # Assume we're using a trunk, need to find the parent port
            for port in ports:
                logger.debug("checking port = %s %s trunk_details = \"%s\"", port.name, port.id, port.trunk_details)
                if port.trunk_details is not None:
                    selected_port = port

        if selected_port is not None:
            logger.info("selected_port = %s %s", selected_port.name, selected_port.id)
            networks.append({'port': selected_port.id})
        else:
            logger.warning("No port found for MAC address = %s", mac)
            return jsonify({'ok': False, "msg": "Cannot find port for MAC {}".format(mac)})

    bdm = []

    for ppv in get_preprov_volumes(data['deployment'], name):
        bdm.append({
            "uuid": ppv['mid'],
            "source_type": "volume",
            "destination_type": "volume",
            "device_type": "disk",
            "disk_bus": "scsi"
        })

    for disk in data['disks']:
        logging.info("Processing disk %s hlu %s", disk['name'], disk['hlu'])
        if int(disk['hlu']) == 0:
            # Make sure the volume is bootable if it has a hlu of 0
            logging.info("setting to bootable")
            # fails with "Version 3.60 is not supported by the API. Minimum is 3.0 and maximum is 3.59"
            #os_conn.block_storage.set_volume_bootable_status(disk['id'], True)
            resp = os_conn.session.post(
                utils.urljoin("volumes", disk['id'], 'action'),
                json={ "os-set_bootable": {"bootable": True}},
                microversion='3.59',
                microversion_service_type='volume',
                endpoint_filter={
                    'service_type': 'block-storage',
                    'interface': 'public',
                    'min_version': '3',
                    'max_version': 'latest'
                }
            )
            logging.info("bootable resp %s", resp)
        elif disk['shared']:
            # Make sure the volume has a type of multiattach - note this can only be set
            # when the volume is not attached to any host
            volume = os_conn.block_storage.get_volume(disk['id'])
            logging.info("shared volume %s %s is_multiattach %s", volume.name, volume.id, volume.is_multiattach)
            if not volume.is_multiattach:
                logging.info("setting to multiattach")
                # fails with "Version 3.60 is not supported by the API. Minimum is 3.0 and maximum is 3.59"
                #os_conn.block_storage.retype_volume(disk['id'], "multiattach")
                resp = os_conn.session.post(
                    utils.urljoin("volumes", volume.id, 'action'),
                    json={'os-retype': { 'new_type': 'multiattach'}},
                    microversion='3.59',
                    microversion_service_type='volume',
                    endpoint_filter={
                        'service_type': 'block-storage',
                        'interface': 'public',
                        'min_version': '3',
                        'max_version': 'latest'
                    }
                )
                logging.info("multiattach resp %s", resp)

        bdm.append({
                "uuid": disk['id'],
                "source_type": "volume",
                "destination_type": "volume",
                "device_type": "disk",
                "disk_bus": "scsi"
        })

    logger.info("volume bdm = %s", bdm)
    if len(bdm) == 0:
        logger.warn("No volumes found for %s", data['name'])
        return jsonify({'ok': False, 'msg': 'No volumes found'})

    # Add the image if one is defined
    image_name = None
    if 'image' in data:
        image_name = get_name(data['deployment'], data['image'])
    #elif 'pxeboot' in data and data['pxeboot']:
    # In order to get UEFI boot mode, we have to have
    # an image with the properties, so always default
    # to adding the ipxe_uefi.iso
    else:
        image_name = 'vlitp_ipxe_uefi.iso'
    image_id = None

    if image_name is not None:
        image = os_conn.image.find_image(image_name)
        if image is None:
            return jsonify({'ok': False, 'msg': "Cannot find image for {}".format(image_name)})
        image_id = image.id
        bdm.insert(1, {
                "uuid": image_id,
                "source_type": "image",
                "destination_type": "volume",
                "delete_on_termination": True,
                "volume_size": int(image.size / (1024*1024*1024)) + 1,
                "device_type": "cdrom"
        })

    bdm[0]['boot_index'] = 0
    if image_name is not None:
        bdm[1]['boot_index'] = 1

    try:
        server_name = get_name(data['deployment'], data['name'])
        if image_id is None:
            server = os_conn.compute.create_server(
                    name=server_name,
                    flavor_id=flavor.id,
                    networks=networks,
                    block_device_mapping_v2=bdm
                )
        else:
            server = os_conn.compute.create_server(
                    name=server_name,
                    flavor_id=flavor.id,
                    networks=networks,
                    imageRef=image_id,
                    block_device_mapping_v2=bdm
                )

        # Don't wait for the server as this causes timeouts
        # when EDP is installing the LMS
        #server = os_conn.compute.wait_for_server(server)

        return jsonify({'ok': True, 'mid': server.id})
    except Exception as e:
        logging.exception("create server failed")
        return jsonify({'ok': False, 'msg': str(e)})


def delete_server(name, data):
    global os_conn
    global logger

    server_name = get_name(data['deployment'], data['name'])

    server = os_conn.compute.find_server(server_name)
    if server is None:
        return jsonify({ 'ok': True })

    logger.info("delete_server: name=%s server.status=%s", server_name, server.status)

    try:
        os_conn.compute.delete_server(server, force=True)
    except Exception as e:
        logging.exception("delete_server failed")
        return jsonify({'ok': False, 'msg': str(e)})

    server_on = True
    server_id = server.id
    count = 0
    while server_on:
        try:
            server = os_conn.get_server(server_id)
            logging.debug("delete_server: server=%s", server)
            if server is None:
                server_on = False
            else:
                count = count + 1
                time.sleep(1)

            if count > 20:
                server_on = False
        except  openstack.exceptions.NotFoundException as e:
            logging.exception("delete_server failed")
            server_on = False

    return jsonify({ 'ok': True })

app.run()

if __name__ == '__main__':
    app.run(debug=True)
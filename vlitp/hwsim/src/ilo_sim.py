from http.server import HTTPServer, BaseHTTPRequestHandler
import logging
import ssl
import json
import time
from threading import Thread
import paramiko
import socket
import threading
import sys

from urllib.parse import urlparse


from unity_sim import unity_get_luns, unity_register_hba
from mediatorrest import MediatorREST

handler_instance_data = {}
logger = None
mediator = None
extip = None
cert_file = None

#
# Public functions
#
def ilo_init(config,  _mediator):
    global logger, mediator, extip, cert_file

    logger = logging.getLogger('ilo_sim')
    mediator = _mediator

    extip = config['extip']
    cert_file = config['cert']

    host_key = paramiko.RSAKey.generate(bits=2048)
    for host in config['hosts']:
        if host['cluster'] != 'lms':
            for adaptor_index in range (1,3):
                for port_index in range(1,3):
                    unity_register_hba(get_hba_wwn(host['host_index'], adaptor_index, port_index))

        Thread(target=serve_redfish_on_address, name="{}-http".format(host['hostname']), args=[host]).start()
        Thread(target=serve_ssh_on_address, name="{}-ssh".format(host['hostname']), args=[host, host_key]).start()

#
#
#
class IloSshServer(paramiko.ServerInterface):
    def __init__(self):
        self.event = threading.Event()

    def check_channel_request(self, kind, chanid):
        logger.debug("check_channel_request kind = %s", kind)
        if kind == 'session':
            return paramiko.OPEN_SUCCEEDED

    def check_channel_shell_request(self, channel):
        self.event.set()
        return True

    def check_channel_pty_request(self, channel, term, width, height, pixelwidth, pixelheight, modes):
        return True

    def check_auth_password(self, username, password):
        return paramiko.AUTH_SUCCESSFUL

    def get_allowed_auths(self, username):
        return 'password'

    def check_channel_exec_request(self, channel, command):
        # This is the command we need to parse
        logger.debug("check_channel_exec_request command = %s", command)
        channel.send(" name=iLO 5")
        channel.send_exit_status(0)
        self.event.set()
        return True

#
# Private functions
#
def load_image(inst_data):
    global mediator
    global extip

    logging.debug("load_image: virtualmedia=%s", inst_data["virtualmedia"])
    iso = inst_data["virtualmedia"].split("/")[-1]
    # Now try and get the actually state
    #parsed_url = urlparse(inst_data["virtualmedia"])
    #ext_url = parsed_url._replace(netloc="{}:{}".format(extip, 8124)).geturl()
    #ext_url = "http://{}:8124/{}".format(extip, iso)
    logging.debug("load_image: iso %s", iso)
    image_def = {
        "name": iso,
    }
    try:
        response = mediator.request("/image/", method='POST', data=image_def)
        logging.debug("load_image response %s", response)
        return True
    except Exception as e:
        logger.exception("load_image: request failed")
        return False

def get_nic_macs(inst_data):
    results = []
    host_index = inst_data['host']['host_index']
    for interface_index in range(1,5):
        mac_address = ":".join(["00:00:00:00", '{:02X}'.format(int(host_index)), '{:02X}'.format(int(interface_index))])
        results.append(mac_address)

    return results

def get_hba_wwn(host_index, adaptor_index, port_index):
    return "{}:{:02X}:{:02X}".format( get_hba_wwn_base(host_index), adaptor_index, port_index)

def get_hba_wwn_base(host_index):
    fc_base = "00:00:00:00:00:{:02X}".format(host_index)

    return fc_base

def sort_by_hlu(disks):
    return sorted(disks, key=lambda d: d['hlu'])

def server_reset(inst_data, reset_type):
    global mediator

    install_boot = inst_data['virtualmedia'] is not None or inst_data['pxeboot']
    disks = sort_by_hlu(
        unity_get_luns(
            get_hba_wwn_base(inst_data['host']['host_index'])
        )
    )

    logger.debug("server_reset %s reset_type=%s install_boot=%s inst_data=%s #disks=%d", inst_data['server_name'], reset_type, install_boot, inst_data, len(disks))

    server_def = {
        'name': inst_data['server_name'],
        'flavor': inst_data['host']['cluster'],
        'nics' : get_nic_macs(inst_data),
        'disks': disks,
        'pxeboot': inst_data['pxeboot']
    }

    action = None
    if reset_type in [ 'on', 'forcerestart' ]:
        if install_boot:
            if inst_data['virtualmedia'] is not None:
                url = inst_data['virtualmedia']
                image = url.split("/")[-1]
                server_def['image'] = image
            action = 'PowerOn'

        elif len(disks) > 0:
            # Ignore power on requests when we don't have any disks
            action = 'PowerOn'
    elif reset_type == 'forceoff':
        action = 'PowerOff'

    result = True
    if action is not None:
        try:
            logger.info("server_reset: %s calling %s", inst_data['server_name'], action)
            response = mediator.request("/server/{}/{}".format(inst_data['server_name'], action), method='POST', data=server_def)
            logger.info("server_reset: %s response ok %s", inst_data['server_name'], response['ok'])
            if response['ok']:
                # On succesful install boot clear the pxeboot/virtualmedia settings
                if install_boot:
                    inst_data['pxeboot'] = False
                    inst_data['virtualmedia'] = None
            else:
                logging.warning("server_reset %s failed to power on msg=%s", inst_data['server_name'], response['msg'])
                result = False
        except Exception as e:
            logger.exception("server_reset: %s, request failed", inst_data['server_name'])
            result = False

    if reset_type in [ 'on', 'forcerestart' ]:
        logger.info("server_reset: %s setting reboot_time", inst_data['server_name'] )
        inst_data['reboot_time'] = time.time()
        inst_data['power_state'] = 'On'
    else:
        inst_data['power_state'] = 'Off'

    return result

def server_power_get(inst_data):
    global mediator

    # inst_data['power_state'] will be the "admin" power_state, i.e. what we've tried to
    # set it to
    power_state = inst_data['power_state']
    if time.time()  - inst_data['reboot_time'] < 10:
        post_state = "InPost"
    else:
        post_state = "FinishedPost"

    try:
        # Now try and get the actually state
        response = mediator.request("/server/{}".format(inst_data['server_name']), method='GET')
        logging.debug("server_power_get %s response power_state %s", inst_data["server_name"], response['power_state'])
        # If the VM doesn't exist, then power_state will be None
        # In this case we'll just use the "admin" value
        if response['power_state'] is not None:
            power_state = response['power_state']
            if 'ready' in response:
                if response['ready']:
                    post_state = "FinishedPost"
                else:
                    post_state = "InPost"

    except Exception as e:
        logger.exception("server_power: request failed")

    logging.debug(
        "server_power_get inst_data power_state=%s post_state=%s power_state=%s",
        inst_data['power_state'], post_state, power_state)

    return power_state, post_state

def config_ldrive(inst_data, data):
    if len(data['LogicalDrives']) > 0:
        # Check that we've got volumes for each logical drive
        response = mediator.request("/server_volumes/{}".format(inst_data['server_name']), method='GET')
        if not response['ok'] or len(response['volumes']) != len(data['LogicalDrives']):
            logger.debug("config_ldrive: bad response for server_volumes: %s, expected %d volumes", response, len(data['LogicalDrives']))
            return False

    inst_data['logical_drives'] = data['LogicalDrives']

    logical_index = 0
    for logical_drive in inst_data['logical_drives']:
        if 'VolumeUniqueIdentifier' not in logical_drive:
            logical_drive['VolumeUniqueIdentifier'] = response['volumes'][logical_index]['mid']
            logger.debug("config_ldrive: Updated VolumeUniqueIdentifier to %s", logical_drive['VolumeUniqueIdentifier'])
        # In the PUT we get 'DataDrives': {'DataDriveCount': 4, 'DataDriveMediaType': 'HDD', 'DataDriveInterfaceType': 'SAS'}
        # But the GET should return "DataDrives": [ "1I:1:1", "1I:1:2", "1I:1:3", "1I:1:4" ]
        if 'DataDrives' in logical_drive:
            logical_drive['DataDrives'] = [ "1I:1:1", "1I:1:2", "1I:1:3", "1I:1:4" ]

        logical_index = logical_index + 1

    logger.debug("config_ldrive: Updated logical_drives to %s", inst_data['logical_drives'])

    return True


class Handler(BaseHTTPRequestHandler):
    def getInstanceData(self):
        global handler_instance_data

        key = self.server.server_address[0]
        result = handler_instance_data[key]
        return result

    def handleChassisNetworkAdapters(self):
        path_parts = self.path.lower().split('/')
        path_parts = path_parts[5:]
        if path_parts[-1] == '':
            path_parts.pop()
        logger.debug("handleChassisNetworkAdapters: path_parts=%s", path_parts)

        if path_parts[-1] == 'settings':
            adapter_index = path_parts[1]
            port_index = path_parts[3]

            inst_data = self.getInstanceData()
            client_oct = inst_data['host']['host_index']
            wwnn = ":".join(["00:00:00:00:00", '{:02X}'.format(int(client_oct)), '{:02X}'.format(int(adapter_index)), '{:02X}'.format(int(port_index))])
            if port_index == '1':
                boot_mode = 'FibreChannel'
            else:
                boot_mode = 'Disabled'
            reply_data = {
                "BootMode": boot_mode,
                "FibreChannel": {
                    "PermanentWWNN": wwnn,
                }
            }
        elif path_parts[-1] == 'networkdevicefunctions':
            reply_data = {
                "Members" : [
                    { "@odata.id": self.path + "1/" },
                    { "@odata.id": self.path + "2/" },
                ]
            }
        elif path_parts[-1] == 'networkadapters':
            reply_data = {
                "Members" : [
                    { "@odata.id": "/redfish/v1/Chassis/1/NetworkAdapters/1" },
                    { "@odata.id": "/redfish/v1/Chassis/1/NetworkAdapters/2" },
                    { "@odata.id": "/redfish/v1/Chassis/1/NetworkAdapters/3" },
                    { "@odata.id": "/redfish/v1/Chassis/1/NetworkAdapters/4" },
                ],
                "Members@odata.count": 4
            }
        else:
            reply_data = {
                "@odata.id": self.path,
                "SKU": "SN1100Q",
                "Oem": {
                    "Hpe": {
                        "RedfishConfiguration": "Enabled"
                    }
                }
            }

        return reply_data

    def do_GET(self):
        logger.debug("do_GET: server=%s path=%s", self.server.server_address[0], self.path)

        inst_data = self.getInstanceData()

        reply_data = None
        path_lower = self.path.lower()
        if self.path == '/redfish/v1/':
            reply_data = {
                "@odata.type": "#ServiceRoot.v1_0_2.ServiceRoot",
                "Id": "RootService",
                "Name": "Root Service",
                "RedfishVersion": "1.0.2",
                "UUID": "92384634-2938-2342-8820-489239905423",
                "Systems": {
                    "@odata.id": "/redfish/v1/Systems"
                },
                "Chassis": {
                    "@odata.id": "/redfish/v1/Chassis"
                },
                "Managers": {
                    "@odata.id": "/redfish/v1/Managers"
                },
                "SessionService": {
                    "@odata.id": "/redfish/v1/SessionService"
                },
                "AccountService": {
                    "@odata.id": "/redfish/v1/AccountService"
                },
                "Links": {
                    "Sessions": {
                        "@odata.id": "/redfish/v1/SessionService/Sessions"
                    }
                },
                "Oem": {},
                "@odata.context": "/redfish/v1/$metadata#ServiceRoot.ServiceRoot",
                "@odata.id": "/redfish/v1/",
            }
        elif path_lower == '/redfish/v1/Systems'.lower():
            reply_data = {
                "@odata.type": "#ComputerSystemCollection.ComputerSystemCollection",
                "Name": "Computer System Collection",
                "Members@odata.count": 1,
                "Members": [
                    {
                        "@odata.id": "/redfish/v1/Systems/1/"
                    }
                ]
            }
        elif path_lower == '/redfish/v1/Systems/1/'.lower() or path_lower == '/redfish/v1/Systems/1'.lower():
            power_state, post_state = server_power_get(inst_data)

            if inst_data['host']['cluster'] == 'sfs':
                model = "ProLiant DL360 Gen10"
            else:
                model = "ProLiant DL360 Gen10 Plus"

            logger.debug("%s post_state = %s", self.server.server_address[0], post_state)
            reply_data = {
                "@odata.type": "#ComputerSystem.v1_1_0.ComputerSystem",
                "Id": "1",
                "Name": "VM System",
                "SystemType": "Physical",
                "AssetTag": "VMASSETTAG",
                "Manufacturer": "HPE",
                "Model": model,
                "SerialNumber": "2M2201{:>02d}SL".format(inst_data['host']['host_index']),
                "SKU": "867530",
                "PartNumber": "224071-J23",
                "Description": "VM Implementation Recipe of simple scale-out monolithic server",
                "UUID": "00000000-0000-0000-0000-0000000000{:>02d}".format(inst_data['host']['host_index']),
                "HostName": "VMHostname",
                "PowerState": power_state,
                "BiosVersion": "X00.1.2.3.4(build-23)",
                "Status": {
                    "State": "Enabled",
                    "Health": "OK"
                },
                "IndicatorLED": "Off",
                "Boot": {
                    "BootSourceOverrideEnabled": "Once",
                    "BootSourceOverrideMode": "UEFI",
                    "UefiTargetBootSourceOverride": "uefiDevicePath",
                    "BootSourceOverrideTarget": "Pxe",
                    "BootSourceOverrideTarget@Redfish.AllowableValues": [
                        "None",
                        "Pxe",
                        "Usb",
                        "Hdd",
                        "BiosSetup",
                        "UefiTarget",
                        "UefiHttp"
                    ]
                },
                "Oem": {
                    "Hpe": {
                       "PostState": post_state
                    }
                },
                "LogServices": {
                    "@odata.id": "/redfish/v1/Systems/1/LogServices"
                },
                "Links": {
                    "Chassis": [
                        {
                            "@odata.id": "/redfish/v1/Chassis/A33"
                        }
                    ],
                    "ManagedBy": [
                        {
                            "@odata.id": "/redfish/v1/Managers/bmc"
                        }
                    ],
                    "Oem": {}
                },
                "Actions": {
                    "#ComputerSystem.Reset": {
                        "target": "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset",
                        "ResetType@Redfish.AllowableValues": [
                            "On",
                            "ForceOff",
                            "GracefulShutdown",
                            "ForceRestart",
                            "Nmi",
                            "GracefulRestart",
                            "ForceOn"
                        ]
                    }
                },
                "@odata.context": "/redfish/v1/$metadata#ComputerSystem.ComputerSystem",
                "@odata.id": "/redfish/v1/Systems/1",
            }
        elif path_lower == '/redfish/v1/Systems/1/bios/settings/'.lower() or path_lower == '/redfish/v1/Systems/1/bios/settings'.lower() or path_lower == '/redfish/v1/Systems/1/bios'.lower():
            server_name = inst_data['server_name']
            reply_data = {
                "@odata.context": "/redfish/v1/$metadata#Bios.Bios",
                "@odata.etag": "W/\"3739E5D6FCD097979732B6F1D9F8E684\"",
                "@odata.id": "/redfish/v1/systems/1/bios/settings/",
                "@odata.type": "#Bios.v1_0_4.Bios",
                "AttributeRegistry": "BiosAttributeRegistryU46.v1_1_64",
                "Attributes": {
                    'BootMode': 'Uefi',
                    'WorkloadProfile': 'Virtualization-MaxPerformance',
                    'ProcHyperthreading': 'Enabled',
                    'VirtualSerialPort': 'Com1Irq4',
                    'PciSlot1Enable': 'Auto',
                    'PciSlot1LinkSpeed': 'Auto',
                    'PciSlot1OptionROM': 'Enabled',
                    'ServerName': server_name,
                    'AllowLoginWithIlo': 'Enabled',
                    "AdjSecPrefetch": "Enabled",
                    "DcuIpPrefetcher": "Enabled",
                    "DcuStreamPrefetcher": "Enabled",
                    "FCScanPolicy": "AllTargets",
                    "HwPrefetcher": "Enabled",
                    "IntelNicDmaChannels": "Enabled",
                    "MaxMemBusFreqMHz": "Auto",
                    "MemPatrolScrubbing": "Enabled",
                    "MemRefreshRate": "Refreshx1",
                    "PciSlot10Enable": "Auto",
                    "PciSlot10LinkSpeed": "Auto",
                    "PciSlot10OptionROM": "Enabled",
                    "PciSlot2Enable": "Auto",
                    "PciSlot2LinkSpeed": "Auto",
                    "PciSlot2OptionROM": "Enabled",
                    "PciSlot3Enable": "Auto",
                    "PciSlot3LinkSpeed": "Auto",
                    "PciSlot3OptionROM": "Enabled",
                    "PostDiscoveryMode": "Auto",
                    "ProcX2Apic": "Enabled",
                    "Slot10NicBoot1": "NetworkBoot",
                    "Slot10NicBoot2": "Disabled",
                    "Slot1NicBoot1": "Disabled",
                    "Slot1NicBoot2": "Disabled",
                    "Slot2NicBoot1": "NetworkBoot",
                    "Slot2NicBoot2": "Disabled",
                    "Slot3NicBoot1": "Disabled",
                    "Slot3NicBoot2": "Disabled"
                }
            }
        elif path_lower == '/redfish/v1/Managers/1/VirtualMedia/2/'.lower():
            reply_data = {
                "Inserted": False
            }
        elif path_lower == '/redfish/v1/Systems/1/EthernetInterfaces'.lower():
            reply_data = {
                "Members" : [
                    { "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/1" },
                    { "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/2" },
                    { "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/3" },
                    { "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/4" }
                ],
                "Members@odata.count": 4
            }
        elif path_lower.startswith('/redfish/v1/Systems/1/EthernetInterfaces/'.lower()):
            interface_index = self.path.split('/')[-1]
            mac_addresses = get_nic_macs(inst_data)
            reply_data = {
                "MACAddress": mac_addresses[int(interface_index) - 1]
            }
        elif path_lower == '/redfish/v1/Systems/1/BaseNetworkAdapters'.lower():
            reply_data = {
                "Members" : [
                    { "@odata.id": "/redfish/v1/Systems/1/BaseNetworkAdapters/1" },
                    { "@odata.id": "/redfish/v1/Systems/1/BaseNetworkAdapters/2" }
                ],
                "Members@odata.count": 2
            }
        elif path_lower.startswith('/redfish/v1/Systems/1/BaseNetworkAdapters/'.lower()):
            interface_index = int(self.path.split('/')[-1])
            host_index = inst_data['host']['host_index']
            reply_data = {
                "FcPorts": [
                    {
                        "PortNumber": 1,
                        "WWNN": get_hba_wwn(host_index, 0, 0),
                        "WWPN": get_hba_wwn(host_index, interface_index, 1)
                    },
                    {
                        "PortNumber": 2,
                        "WWNN": get_hba_wwn(host_index, 0, 0),
                        "WWPN": get_hba_wwn(host_index, interface_index, 2)
                    }
                ]
            }
        elif path_lower == '/redfish/v1/Managers/1'.lower():
            reply_data = {
                "Oem": {
                    "Hpe": {
                        "Firmware": {
                            "Current": {
                                "VersionString": "iLO 5 v2.72"
                            }
                        }
                    }
                }
            }
        elif path_lower == '/redfish/v1/Managers/1/LicenseService/1'.lower():
            reply_data = {
                "LicenseType": "Perpetual",
                "License": "iLO Advanced"
            }
        elif path_lower == '/redfish/v1/Managers/1/DateTime'.lower():
            reply_data = {
                "TimeZone": {
                    "Index": 1,
                    "Name": "Greenwich Mean Time, Casablanca, Monrovia",
                    "UtcOffset": "+00:00",
                    "Value": "GMT-0"
                },
                "TimeZoneList": [
                    {
                        "Index": 1,
                        "Name": "Greenwich Mean Time, Casablanca, Monrovia",
                        "UtcOffset": "+00:00",
                        "Value": "GMT-0"
                    }
                ]
            }
        elif path_lower == '/redfish/v1/Managers/1/NetworkService'.lower():
            reply_data = {
                "IPMI": {
                    "Port": 623,
                    "ProtocolEnabled": False
                }
            }
        elif path_lower.startswith('/redfish/v1/chassis/1/NetworkAdapters'.lower()):
            reply_data = self.handleChassisNetworkAdapters()
        elif path_lower == '/redfish/v1/Systems/1/SmartStorage/ArrayControllers'.lower():
            reply_data = {
                "Members": [ { "@odata.id": "/redfish/v1/Systems/1/SmartStorage/ArrayControllers/1" } ]
            }
        elif path_lower == '/redfish/v1/Systems/1/smartstorage/ArrayControllers/1/DiskDrives'.lower():
            reply_data = {
                "Members": [
                    { "@odata.id": "/redfish/v1/Systems/1/SmartStorage/ArrayControllers/1/DiskDrives/0" },
                    { "@odata.id": "/redfish/v1/Systems/1/SmartStorage/ArrayControllers/1/DiskDrives/1" },
                    { "@odata.id": "/redfish/v1/Systems/1/SmartStorage/ArrayControllers/1/DiskDrives/2" },
                    { "@odata.id": "/redfish/v1/Systems/1/SmartStorage/ArrayControllers/1/DiskDrives/3" },
                ],
                "Members@odata.count": 4
            }
        elif path_lower.startswith('/redfish/v1/Systems/1/SmartStorage/ArrayControllers/1/DiskDrives/'.lower()):
            #drive_index = int(self.path.split('/')[-1])
            reply_data = {
                "MediaType": "HDD",
                "InterfaceType": "SAS"
            }
        elif path_lower == '/redfish/v1/Systems/1/smartstorageconfig/'.lower() or path_lower == '/redfish/v1/Systems/1/smartstorageconfig/settings'.lower():
            reply_data = {
                "DataGuard": "Disabled",
                "LogicalDrives": inst_data['logical_drives'],
                "PhysicalDrives": [
                    {
                        "LegacyBootPriority": "None",
                        "Location": "1I:1:1",
                        "LocationFormat": "ControllerPort:Box:Bay"
                    },
                    {
                        "LegacyBootPriority": "None",
                        "Location": "1I:1:2",
                        "LocationFormat": "ControllerPort:Box:Bay"
                    },
                    {
                        "LegacyBootPriority": "None",
                        "Location": "1I:1:3",
                        "LocationFormat": "ControllerPort:Box:Bay"
                    },
                    {
                        "LegacyBootPriority": "None",
                        "Location": "1I:1:4",
                        "LocationFormat": "ControllerPort:Box:Bay"
                    }
                ],
            }
        else:
            logger.error("Request for unknown path %s", self.path)

        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        if reply_data is not None:
            reply_data_str = json.dumps(reply_data)
            logger.debug("do_GET: server=%s reply_data_Str=%s", self.server.server_address[0], reply_data_str)
            self.wfile.write(bytes(reply_data_str, "utf-8"))

    def do_PUT(self):
        global address_map
        global mediator

        logger.debug("do_PUT: server=%s path=%s", self.server.server_name, self.path)

        content_length = self.headers['Content-Length']
        data_str = self.rfile.read(int(content_length))
        data = json.loads(data_str)
        logger.debug("do_PUT: data=%s", data)

        inst_data = self.getInstanceData()

        if self.path.lower().startswith('/redfish/v1/Systems/1/smartstorageconfig/settings'.lower()):
            if 'LogicalDrives' in data:
                if not config_ldrive(inst_data, data):
                    self.send_response(500)
                    self.send_header("Content-type", "application/json")
                    self.end_headers()
                    return

        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()

    def do_PATCH(self):
        logger.debug("do_PATCH: server=%s path=%s", self.server.server_name, self.path)

        content_length = self.headers['Content-Length']
        data_str = self.rfile.read(int(content_length))
        data = json.loads(data_str)
        logger.debug("do_PATCH: data=%s", data)

        inst_data = self.getInstanceData()

        result = True
        if self.path.lower() == '/redfish/v1/Systems/1/bios/settings'.lower() or self.path.lower() == '/redfish/v1/Systems/1/bios/settings/'.lower():
            if 'ServerName' in data['Attributes']:
                inst_data['server_name'] = data['Attributes']['ServerName']
        elif self.path.lower() == '/redfish/v1/Managers/1/VirtualMedia/2/'.lower():
            logger.debug("setting virtualmedia")
            inst_data['virtualmedia'] = data['Image']
            if not load_image(inst_data):
                result = False
        elif self.path.lower() == '/redfish/v1/Systems/1/'.lower():
            if 'Boot' in data and 'BootSourceOverrideTarget' in data['Boot'] and data['Boot']['BootSourceOverrideTarget'] == 'Pxe':
                inst_data['pxeboot'] = True
                logger.debug("Setting pxeboot")

        if result:
            self.send_response(200)
        else:
            self.send_response(500)
        self.send_header("Content-type", "application/json")
        self.end_headers()

    def do_POST(self):
        logger.debug("do_POST: server=%s path=%s", self.server.server_address[0], self.path)
        content_length = self.headers['Content-Length']
        data_str = self.rfile.read(int(content_length))
        data = json.loads(data_str)
        logger.debug("do_POST: data=%s", data)

        inst_data = self.getInstanceData()

        resp_headers = {}
        response_code = 200
        reply_data = {}

        lower_path = self.path.rstrip('/').lower()
        if lower_path == '/redfish/v1/Systems/1/Actions/ComputerSystem.Reset'.lower():
            result = server_reset(inst_data, data['ResetType'].lower())
            logger.debug("do_POST server_reset returned %s", result)
            if not result:
                response_code = 500
        elif lower_path == '/redfish/v1/Sessions'.lower():
            response_code = 201
            resp_headers['x-auth-token'] = 'THIS-IS-A-TOKEN'
            resp_headers['location'] = ''.join(['https://', self.server.server_name, self.path, '/1'])

        logger.debug("do_POST response_code=%s", response_code)
        self.send_response(response_code)
        self.send_header("Content-type", "application/json")
        for key, value in resp_headers.items():
            self.send_header(key, value)
        self.end_headers()

        if reply_data is not None:
            reply_data_str = json.dumps(reply_data)
            logger.debug("do_POST: server=%s reply_data_Str=%s", self.server.server_address[0], reply_data_str)
            self.wfile.write(bytes(reply_data_str, "utf-8"))

    def do_DELETE(self):
        logger.debug("do_DELETE: server=%s path=%s", self.server.server_name, self.path)
        self.send_response(200)
        self.end_headers()


# openssl req -new -x509 -keyout localhost.pem -out localhost.pem -days 365 -nodes
def serve_redfish_on_address(host):
    global cert_file

    logger.info("serve_redfish_on_address %s", host)

    handler_instance_data[host['address']] = {
        'power_state': 'Off',
        'reboot_time': 0,
        'server_name': host['hostname'],
        'pxeboot': False,
        'virtualmedia': None,
        'host': host,
        'logical_drives': []
    }

    server = HTTPServer((host['address'], 443), Handler)

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=cert_file)
    server.socket = context.wrap_socket(
        server.socket,
        server_side=True
    )

    server.serve_forever()

def serve_ssh_on_address(host, host_key):
    logger.info("serve_ssh_on_address %s", host)

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        sock.bind((host['address'], 22))
    except socket.error as exc:
        logger.error(exc)
        sys.exit()

    while True:
        try:
            sock.listen()
            client, addr = sock.accept()
            t = paramiko.Transport(client)
            t.set_gss_host(socket.getfqdn(""))
            t.load_server_moduli()
            t.add_server_key(host_key)
            server = IloSshServer()
            t.start_server(server=server)
            logger.debug("started server for %s", host['hostname'])
            chan = t.accept(20)
            if chan is not None:
                chan.send("\r\n</>hpiLO->")
                f = chan.makefile("rU")
                logger.debug("read line for %s", host['hostname'])
                line = f.readline().strip("\r\n")
                logger.debug("got line = %s", line)
                chan.send("\r\n name=iLO 5\r\n")
                chan.send("</>hpiLO->")

            logger.debug("closing transport for for %s", host['hostname'])
            t.close()
        except Exception as exc:
            logger.error(exc)

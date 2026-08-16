#!/usr/bin/env python3
import socket
import sys
import subprocess
import re
import time
import argparse
import json
import threading
import queue

JSON_MODE = False
_original_print = print

def print(*args, **kwargs):
    if JSON_MODE:
        import io
        buf = io.StringIO()
        kwargs_copy = dict(kwargs)
        kwargs_copy.pop('file', None)
        _original_print(*args, **kwargs_copy, file=buf)
        sys.stderr.write(buf.getvalue())
        sys.stderr.flush()
    else:
        _original_print(*args, **kwargs)

# Protocol framing
START_PREFIX = b"\xaa\xbb\xcc"
END_SUFFIX = b"\xdd\xee\xff"

# Operation codes
OP_WRITE = 0x80
OP_READ = 0xC0
OP_RESPONSE = 0x00
OP_NOTIFY = 0x02

# Command IDs
CMD_GET_DEVICE_INFO = 2
CMD_SET_DEVICE_INFO = 8
CMD_GET_DEVICE_RUN_INFO = 9
CMD_REPORT_DEVICE_STATUS = 14
CMD_SEND_DEVICE_FILE = 18
CMD_SET_DEVICE_CONFIG = 242
CMD_GET_DEVICE_CONFIG = 243

# Attribute IDs for writing settings (Command 8)
ATTR_WRITE_AUTO_SHUTDOWN = 0
ATTR_WRITE_2DEVICES_CONNECT = 1
ATTR_WRITE_EQ_MODE = 2
ATTR_WRITE_ANC_MODE = 4
ATTR_WRITE_GAME_MODE = 5
ATTR_WRITE_AUTO_PLAY = 6
ATTR_WRITE_ANTI_LEAK = 7
ATTR_WRITE_LDAC = 8
ATTR_WRITE_MULTIPOINT = 9
ATTR_WRITE_SPATIAL_AUDIO = 10
ATTR_WRITE_SPATIAL_SCENE = 11
ATTR_WRITE_WIND_NOISE = 12
ATTR_WRITE_WEAR_DETECTION = 13

# Attribute masks for querying run info (Command 9)
MASK_QUERY_AUTO_SHUTDOWN = 32
MASK_QUERY_ANC_STATUS = 512
MASK_QUERY_GAME_MODE = 2048
MASK_QUERY_EQ_MODE = 4096
MASK_QUERY_ANTI_LEAK = 32768
MASK_QUERY_LDAC = 65536
MASK_QUERY_MULTIPOINT = 131072
MASK_QUERY_SPATIAL_AUDIO = 262144
MASK_QUERY_SPATIAL_SCENE = 524288
MASK_QUERY_WIND_NOISE = 1048576
MASK_QUERY_WEAR_DETECTION = 2097152
MASK_QUERY_WEAR_STATE = 4194304

# Attribute masks for querying device info (Command 2)
MASK_QUERY_NAME = 1
MASK_QUERY_BATTERY = 4

# Response attribute ordinals for Command 2
ORD_DEV_NAME = 0
ORD_DEV_BATTERY = 2

# Response attribute ordinals for Command 9 / 14
ORD_RUN_AUTO_SHUTDOWN = 5
ORD_RUN_ANC_STATUS = 9
ORD_RUN_GAME_MODE = 11
ORD_RUN_EQ_MODE = 12
ORD_RUN_ANTI_LEAK = 15
ORD_RUN_LDAC = 16
ORD_RUN_MULTIPOINT = 17
ORD_RUN_SPATIAL_AUDIO = 18
ORD_RUN_SPATIAL_SCENE = 19
ORD_RUN_WIND_NOISE = 20
ORD_RUN_WEAR_DETECTION = 21
ORD_RUN_WEAR_STATE = 22

# ANC Modes
ANC_MODES = {
    0: "Normal (Off)",
    1: "ANC On",
    2: "Transparency",
    3: "Wind Noise (KANG_FENG)",
    4: "Adaptive Auto-ANC"
}

# Standard 9 Presets for Liesheng devices
STANDARD_EQ_PRESETS = {
    0: "Default",
    1: "Vocal",
    2: "Rock",
    3: "Classical",
    4: "Popularity",
    5: "Bass",
    6: "Subwoofer",
    7: "Soft",
    8: "Outdoor",
    240: "Custom/Customize"
}

# S40 specific preset mappings
S40_EQ_PRESETS = {
    0: "Default",
    1: "Subwoofer",
    2: "Rock",
    3: "Soft",
    4: "Classical",
    5: "Bass",
    6: "Subwoofer",
    7: "Soft",
    8: "Custom/Customize",
    15: "Custom/Customize",
    240: "Custom/Customize"
}

S40_EQ_WRITE_MAP = {
    0: 0,
    1: 6,
    2: 2,
    3: 7,
    4: 3,
}

# Touch Gesture Definitions (Config ID 2)
GESTURE_TYPES = {
    1: "Double Tap",
    2: "Triple Tap",
    3: "Long Press"
}

GESTURE_FUNCTIONS = {
    0: "Voice Assistant",
    1: "Play / Pause",
    2: "Previous Track",
    3: "Next Track",
    4: "Volume Up",
    5: "Volume Down",
    6: "ANC Toggle",
    7: "Game Mode",
    255: "Disabled / None"
}

# Device Models & Capabilities Registry
class DeviceModel:
    def __init__(self, key, pid, name, form_factor="tws", has_anc=True, has_anc_levels=True,
                 has_spatial_audio=False, has_ldac=False, has_tws_battery=True,
                 has_gestures=True, has_wear_detection=False, has_auto_shutdown=True,
                 has_anti_leak=False, eq_type="standard"):
        self.key = key
        self.pid = pid
        self.name = name
        self.form_factor = form_factor
        self.has_anc = has_anc
        self.has_anc_levels = has_anc_levels
        self.has_spatial_audio = has_spatial_audio
        self.has_ldac = has_ldac
        self.has_tws_battery = has_tws_battery
        self.has_gestures = has_gestures
        self.has_wear_detection = has_wear_detection
        self.has_auto_shutdown = has_auto_shutdown
        self.has_anti_leak = has_anti_leak
        self.eq_type = eq_type

    def to_dict(self):
        return {
            "key": self.key,
            "pid": self.pid,
            "name": self.name,
            "form_factor": self.form_factor,
            "capabilities": {
                "has_anc": self.has_anc,
                "has_anc_levels": self.has_anc_levels,
                "has_spatial_audio": self.has_spatial_audio,
                "has_ldac": self.has_ldac,
                "has_tws_battery": self.has_tws_battery,
                "has_gestures": self.has_gestures,
                "has_wear_detection": self.has_wear_detection,
                "has_auto_shutdown": self.has_auto_shutdown,
                "has_anti_leak": self.has_anti_leak,
                "eq_type": self.eq_type,
            }
        }

KNOWN_MODELS = [
    DeviceModel("S40", 34, "Haylou S40", form_factor="headband", has_anc=True, has_anc_levels=True,
                has_spatial_audio=True, has_ldac=True, has_tws_battery=False, has_gestures=False,
                has_wear_detection=False, has_auto_shutdown=False, eq_type="s40"),
    DeviceModel("S35", 16, "Haylou S35 ANC", form_factor="headband", has_anc=True, has_anc_levels=True,
                has_spatial_audio=False, has_ldac=False, has_tws_battery=False, has_gestures=False,
                has_wear_detection=False, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("S30", 20, "Haylou S30", form_factor="headband", has_anc=True, has_anc_levels=True,
                has_spatial_audio=False, has_ldac=False, has_tws_battery=False, has_gestures=False,
                has_wear_detection=False, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("HD01", 39, "Haylou FlowLoop S33", form_factor="headband", has_anc=True, has_anc_levels=True,
                has_spatial_audio=False, has_ldac=False, has_tws_battery=False, has_gestures=False,
                has_wear_detection=False, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("X2", 18, "Haylou W1 ANC", form_factor="tws", has_anc=True, has_anc_levels=True,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("T016", 22, "Haylou Mori Pro", form_factor="tws", has_anc=True, has_anc_levels=True,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("T016P", 36, "Haylou Mori Plus", form_factor="tws", has_anc=True, has_anc_levels=True,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("T021", 37, "Haylou Flowbuds N55", form_factor="tws", has_anc=True, has_anc_levels=True,
                has_tws_battery=True, has_gestures=True, has_wear_detection=True, has_auto_shutdown=False, eq_type="standard"),
    DeviceModel("HT02", 38, "Haylou Flowbuds N50", form_factor="tws", has_anc=True, has_anc_levels=True,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=False, eq_type="standard"),
    DeviceModel("HT03", 41, "Haylou Flowbuds N70", form_factor="tws", has_anc=True, has_anc_levels=True,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=False, eq_type="standard"),
    DeviceModel("HT06", 40, "Haylou Flowbuds N10", form_factor="tws", has_anc=True, has_anc_levels=False,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=False, eq_type="standard"),
    DeviceModel("X1", 17, "Haylou X1 2023", form_factor="tws", has_anc=False, has_anc_levels=False,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("T013", 21, "Haylou X1 Plus", form_factor="tws", has_anc=False, has_anc_levels=False,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("X1L", 33, "Haylou X1 ACE", form_factor="tws", has_anc=False, has_anc_levels=False,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("BC04", 19, "Haylou Purfree Lite", form_factor="open_ear", has_anc=False, has_anc_levels=False,
                has_tws_battery=False, has_gestures=False, has_auto_shutdown=True, has_anti_leak=True, eq_type="standard"),
    DeviceModel("OW02", 32, "Haylou Earhook 1", form_factor="open_ear", has_anc=False, has_anc_levels=False,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=True, eq_type="standard"),
    DeviceModel("OW03", 25, "Haylou Airfree", form_factor="open_ear", has_anc=False, has_anc_levels=False,
                has_tws_battery=True, has_gestures=True, has_auto_shutdown=True, eq_type="standard"),
]

def identify_device_model(name="", pid=None):
    if pid is not None:
        for m in KNOWN_MODELS:
            if m.pid == pid:
                return m

    name_lower = (name or "").lower()
    if "s40" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "S40")
    if "s35" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "S35")
    if "s30" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "S30")
    if "s33" in name_lower or "flowloop" in name_lower or "hd01" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "HD01")
    if "w1" in name_lower or "t007" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "X2")
    if "mori plus" in name_lower or "t016p" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "T016P")
    if "mori" in name_lower or "t016" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "T016")
    if "n55" in name_lower or "t021" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "T021")
    if "n50" in name_lower or "ht02" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "HT02")
    if "n70" in name_lower or "ht03" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "HT03")
    if "n10" in name_lower or "ht06" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "HT06")
    if "x1 ace" in name_lower or "x1l" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "X1L")
    if "x1 plus" in name_lower or "t013" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "T013")
    if "x1" in name_lower or "t003" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "X1")
    if "purfree" in name_lower or "bc04" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "BC04")
    if "earhook" in name_lower or "ow02" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "OW02")
    if "airfree" in name_lower or "ow03" in name_lower:
        return next(m for m in KNOWN_MODELS if m.key == "OW03")

    if any(h in name_lower for h in ["headband", "headphone", "over-ear"]):
        return DeviceModel("GENERIC_HEADBAND", 0, name or "Haylou Headband", form_factor="headband",
                           has_anc=True, has_anc_levels=True, has_tws_battery=False, has_gestures=False)

    # Generic TWS Fallback
    return DeviceModel("GENERIC_TWS", 0, name or "Haylou Device", form_factor="tws",
                       has_anc=True, has_anc_levels=True, has_tws_battery=True, has_gestures=True)

# Terminal colors
COLOR_BORDER = "\033[38;2;120;81;255m"
COLOR_TITLE = "\033[38;2;254;202;87m"
COLOR_LABEL = "\033[38;2;162;171;206m"
COLOR_VAL = "\033[38;2;240;240;245m"
COLOR_ON = "\033[38;2;46;204;113m"
COLOR_OFF = "\033[38;2;231;76;60m"
COLOR_UNKNOWN = "\033[38;2;127;140;141m"
COLOR_MSG = "\033[38;2;243;156;18m"
COLOR_MENU_NUM = "\033[38;2;52;152;219m"
RESET = "\033[0m"
BOLD = "\033[1m"

# Protocol helper functions

def build_packet(op_code, cmd_id, sequence_sn, payload_data=None):
    payload_len = len(payload_data) if payload_data else 0
    total_len = payload_len + 1
    header = bytes([op_code, cmd_id]) + total_len.to_bytes(2, byteorder='big')
    packet = START_PREFIX + header + bytes([sequence_sn])
    if payload_data:
        packet += payload_data
    packet += END_SUFFIX
    return packet

def build_setting_tlv(attr_id, value_bytes):
    length = len(value_bytes) + 1
    return bytes([length, attr_id]) + value_bytes

def parse_tlv_blocks(payload, has_status_byte=False):
    if has_status_byte:
        payload = payload[1:]
    attrs = {}
    idx = 0
    while idx < len(payload):
        if idx + 2 > len(payload):
            break
        attr_len = payload[idx]
        if attr_len < 1:
            break
        attr_id = payload[idx+1]
        val_len = attr_len - 1
        if idx + 2 + val_len > len(payload):
            break
        attrs[attr_id] = payload[idx+2 : idx+2+val_len]
        idx += 2 + val_len
    return attrs

def parse_config_blocks(payload, has_status_byte=False):
    if has_status_byte:
        payload = payload[1:]
    configs = {}
    idx = 0
    while idx < len(payload):
        if idx + 3 > len(payload):
            break
        length = payload[idx]
        if length < 2:
            break
        config_id = int.from_bytes(payload[idx+1 : idx+3], byteorder='big')
        val_len = length - 2
        if idx + 3 + val_len > len(payload):
            break
        configs[config_id] = payload[idx+3 : idx+3+val_len]
        idx += 3 + val_len
    return configs

def reset_bluetooth_connection(mac_address):
    if sys.platform == 'win32':
        return False
    print("\nAttempting to reset Bluetooth link to free the resource...")
    try:
        print("Disconnecting device...")
        subprocess.check_call(["bluetoothctl", "disconnect", mac_address], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(2.0)
        print("Reconnecting device...")
        subprocess.check_call(["bluetoothctl", "connect", mac_address], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(2.0)
        print("Reset complete!\n")
        return True
    except Exception as e:
        print(f"Failed to reset: {e}\n")
        return False

# Controller implementation

class HaylouHeadphoneController:
    def __init__(self, mac_address, port=10, initial_name=None):
        self.mac_address = mac_address
        self.port = port
        self.sock = None
        self.seq = 0
        self.device_name = initial_name or "Unknown"
        self.model = identify_device_model(self.device_name)

    def connect(self):
        print(f"Connecting to RFCOMM on {self.mac_address}:{self.port}...")
        for attempt in range(4):
            try:
                self.sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
                self.sock.connect((self.mac_address, self.port))
                self.sock.settimeout(1.0)
                print("Connected successfully!")
                self._update_model_from_device()
                return True
            except OSError as e:
                if e.errno == 16:
                    if attempt < 3:
                        print(f"Port {self.port} is busy. Waiting for OS to release the socket (attempt {attempt+1}/4)...")
                        time.sleep(2.0)
                        continue
                    else:
                        print(f"\n[Errno 16] Port {self.port} remains busy after multiple retries.")
                        try:
                            choice = input("Would you like to force reset the Bluetooth link? [y/N]: ").strip().lower()
                        except (KeyboardInterrupt, EOFError):
                            choice = 'n'
                            print()
                        if choice in ['y', 'yes']:
                            if reset_bluetooth_connection(self.mac_address):
                                try:
                                    self.sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
                                    self.sock.connect((self.mac_address, self.port))
                                    self.sock.settimeout(1.0)
                                    print("Connected successfully on retry!")
                                    self._update_model_from_device()
                                    return True
                                except Exception as retry_err:
                                    print(f"Failed to connect on retry: {retry_err}")
                else:
                    print(f"Failed to connect: {e}")
                self.sock = None
                return False
            except Exception as e:
                print(f"Failed to connect: {e}")
                self.sock = None
                return False
        return False

    def _update_model_from_device(self):
        try:
            name = self.query_device_name()
            if name:
                self.device_name = name
                self.model = identify_device_model(self.device_name)
        except Exception:
            pass

    def disconnect(self):
        if self.sock:
            self.sock.close()
            self.sock = None
            print("Disconnected.")

    def get_next_seq(self):
        self.seq = (self.seq + 1) & 0xFF
        return self.seq

    def send_and_receive(self, op_code, cmd_id, payload_data=None):
        if not self.sock:
            raise RuntimeError("Not connected to headphones.")

        seq = self.get_next_seq()
        req_packet = build_packet(op_code, cmd_id, seq, payload_data)

        # Clear receive buffer
        self.sock.setblocking(False)
        try:
            while True:
                junk = self.sock.recv(1024)
                if not junk:
                    break
        except (BlockingIOError, socket.timeout):
            pass
        finally:
            self.sock.setblocking(True)

        self.sock.sendall(req_packet)

        try:
            return self.read_response_packet(cmd_id)
        except socket.timeout:
            return None

    def read_response_packet(self, target_cmd_id):
        buf = b""
        start_time = time.time()
        while time.time() - start_time < 1.5:
            try:
                chunk = self.sock.recv(1)
                if not chunk:
                    return None
                buf += chunk

                if len(buf) >= 3 and buf[-3:] == START_PREFIX:
                    header = self.sock.recv(4)
                    if len(header) < 4:
                        return None
                    op_code = header[0]
                    cmd_id = header[1]
                    length = int.from_bytes(header[2:4], byteorder='big')

                    data_len = length + 3
                    data_buf = b""
                    while len(data_buf) < data_len:
                        chunk = self.sock.recv(data_len - len(data_buf))
                        if not chunk:
                            return None
                        data_buf += chunk

                    seq_sn = data_buf[0]
                    payload = data_buf[1:-3]
                    suffix = data_buf[-3:]

                    if suffix == END_SUFFIX and cmd_id == target_cmd_id:
                        return op_code, cmd_id, seq_sn, payload

                    buf = b""
            except socket.timeout:
                break
        return None

    # Query API

    def query_device_name(self):
        mask_bytes = MASK_QUERY_NAME.to_bytes(4, byteorder='big')
        resp = self.send_and_receive(OP_READ, CMD_GET_DEVICE_INFO, mask_bytes)
        if resp:
            op_code, _, _, payload = resp
            has_status = not (op_code & 0x40)
            attrs = parse_tlv_blocks(payload, has_status_byte=has_status)
            if ORD_DEV_NAME in attrs:
                try:
                    return attrs[ORD_DEV_NAME].decode('utf-8', errors='ignore').strip('\x00')
                except Exception:
                    pass
        return None

    def query_battery(self):
        mask_bytes = MASK_QUERY_BATTERY.to_bytes(4, byteorder='big')
        resp = self.send_and_receive(OP_READ, CMD_GET_DEVICE_INFO, mask_bytes)
        if resp:
            op_code, _, _, payload = resp
            has_status = not (op_code & 0x40)
            attrs = parse_tlv_blocks(payload, has_status_byte=has_status)
            if ORD_DEV_BATTERY in attrs:
                val_bytes = attrs[ORD_DEV_BATTERY]
                if len(val_bytes) == 1:
                    return {"single": val_bytes[0]}
                elif len(val_bytes) >= 2:
                    res = {"left": val_bytes[0], "right": val_bytes[1]}
                    if len(val_bytes) >= 3:
                        res["case"] = val_bytes[2]
                    return res
        return None

    def query_run_info(self, mask):
        mask_bytes = mask.to_bytes(4, byteorder='big')
        resp = self.send_and_receive(OP_READ, CMD_GET_DEVICE_RUN_INFO, mask_bytes)
        if resp:
            op_code, _, _, payload = resp
            has_status = not (op_code & 0x40)
            return parse_tlv_blocks(payload, has_status_byte=has_status)
        return {}

    def query_eq_preset(self):
        payload = bytes([0x00, 0x07])
        resp = self.send_and_receive(OP_READ, CMD_GET_DEVICE_CONFIG, payload)
        if resp:
            op_code, _, _, response_payload = resp
            has_status = not (op_code & 0x40)
            configs = parse_config_blocks(response_payload, has_status_byte=has_status)
            if 7 in configs:
                val_bytes = configs[7]
                if val_bytes:
                    return val_bytes[0]
        return None

    def query_anc_level(self):
        payload = bytes([0x00, 0x0B])
        resp = self.send_and_receive(OP_READ, CMD_GET_DEVICE_CONFIG, payload)
        if resp:
            op_code, _, _, response_payload = resp
            has_status = not (op_code & 0x40)
            configs = parse_config_blocks(response_payload, has_status_byte=has_status)
            if 11 in configs:
                val_bytes = configs[11]
                if len(val_bytes) >= 2:
                    return val_bytes[1]
                elif len(val_bytes) >= 1:
                    return val_bytes[0]
        return None

    def query_gestures(self):
        payload = bytes([0x00, 0x02])
        resp = self.send_and_receive(OP_READ, CMD_GET_DEVICE_CONFIG, payload)
        gestures = {}
        if resp:
            op_code, _, _, response_payload = resp
            has_status = not (op_code & 0x40)
            configs = parse_config_blocks(response_payload, has_status_byte=has_status)
            if 2 in configs:
                data = configs[2]
                i = 0
                while i + 3 <= len(data):
                    g_type = data[i]
                    l_fn = data[i+1]
                    r_fn = data[i+2]
                    gestures[g_type] = {
                        "type_id": g_type,
                        "type_name": GESTURE_TYPES.get(g_type, f"Type {g_type}"),
                        "left_func": l_fn,
                        "left_name": GESTURE_FUNCTIONS.get(l_fn, f"Func {l_fn}"),
                        "right_func": r_fn,
                        "right_name": GESTURE_FUNCTIONS.get(r_fn, f"Func {r_fn}")
                    }
                    i += 3
        return gestures

    def get_status(self):
        status = {}

        name = self.query_device_name()
        if not name or name == "Unknown":
            try:
                out = subprocess.check_output(["bluetoothctl", "devices"], text=True)
                for line in out.splitlines():
                    m = re.match(r"Device\s+((?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})\s+(.*)", line)
                    if m:
                        mac, dname = m.groups()
                        if mac.lower() == self.mac_address.lower():
                            name = dname
                            break
            except Exception:
                pass
        status['device_name'] = name if name else self.device_name
        self.device_name = status['device_name']
        self.model = identify_device_model(self.device_name)
        status['model_info'] = self.model.to_dict()

        battery_data = self.query_battery()
        if battery_data:
            if "single" in battery_data:
                b_val = battery_data["single"]
                status['battery'] = f"{b_val}%"
                status['battery_left'] = None
                status['battery_right'] = None
                status['battery_case'] = None
            else:
                l_val = battery_data.get("left", 0)
                r_val = battery_data.get("right", 0)
                c_val = battery_data.get("case")
                status['battery_left'] = f"{l_val}%"
                status['battery_right'] = f"{r_val}%"
                status['battery_case'] = f"{c_val}%" if c_val is not None else None
                if c_val is not None:
                    status['battery'] = f"L: {l_val}% | R: {r_val}% | Case: {c_val}%"
                else:
                    status['battery'] = f"L: {l_val}% | R: {r_val}%"
        else:
            status['battery'] = "Unknown"
            status['battery_left'] = None
            status['battery_right'] = None
            status['battery_case'] = None

        combined_mask = (MASK_QUERY_ANC_STATUS | MASK_QUERY_GAME_MODE |
                         MASK_QUERY_MULTIPOINT | MASK_QUERY_LDAC |
                         MASK_QUERY_WIND_NOISE | MASK_QUERY_WEAR_DETECTION |
                         MASK_QUERY_WEAR_STATE | MASK_QUERY_EQ_MODE |
                         MASK_QUERY_AUTO_SHUTDOWN | MASK_QUERY_SPATIAL_AUDIO |
                         MASK_QUERY_SPATIAL_SCENE | MASK_QUERY_ANTI_LEAK)

        run_attrs = self.query_run_info(combined_mask)

        if self.model.has_anc and ORD_RUN_ANC_STATUS in run_attrs:
            anc_val = run_attrs[ORD_RUN_ANC_STATUS][0]
            status['anc_mode'] = ANC_MODES.get(anc_val, f"Unknown ({anc_val})")
        else:
            status['anc_mode'] = "Normal (Off)" if not self.model.has_anc else "Unknown"

        if self.model.has_anc_levels:
            anc_lvl_val = self.query_anc_level()
            anc_level_map = {0: "High", 1: "Medium", 2: "Low"}
            status['anc_level'] = anc_level_map.get(anc_lvl_val, "Unknown" if anc_lvl_val is None else f"Level {anc_lvl_val}")
        else:
            status['anc_level'] = "N/A"

        presets_dict = S40_EQ_PRESETS if self.model.eq_type == "s40" else STANDARD_EQ_PRESETS
        if ORD_RUN_EQ_MODE in run_attrs:
            eq_val = run_attrs[ORD_RUN_EQ_MODE][0]
            status['eq_mode'] = presets_dict.get(eq_val, f"Unknown ({eq_val})")
        else:
            eq_val = self.query_eq_preset()
            status['eq_mode'] = presets_dict.get(eq_val, f"Unknown ({eq_val})") if eq_val is not None else "Unknown"

        if ORD_RUN_GAME_MODE in run_attrs:
            status['game_mode'] = "Enabled" if run_attrs[ORD_RUN_GAME_MODE][0] == 1 else "Disabled"
        else:
            status['game_mode'] = "Unknown"

        if ORD_RUN_WIND_NOISE in run_attrs:
            status['wind_noise'] = "Enabled" if run_attrs[ORD_RUN_WIND_NOISE][0] == 1 else "Disabled"
        else:
            status['wind_noise'] = "Unknown"

        if ORD_RUN_MULTIPOINT in run_attrs:
            status['multipoint'] = "Enabled" if run_attrs[ORD_RUN_MULTIPOINT][0] == 1 else "Disabled"
        else:
            status['multipoint'] = "Unknown"

        if self.model.has_ldac:
            if ORD_RUN_LDAC in run_attrs:
                status['ldac'] = "Enabled" if run_attrs[ORD_RUN_LDAC][0] == 1 else "Disabled"
            else:
                status['ldac'] = "Unknown"
        else:
            status['ldac'] = "N/A"

        if self.model.has_wear_detection:
            if ORD_RUN_WEAR_DETECTION in run_attrs:
                status['wear_detection'] = "Enabled" if run_attrs[ORD_RUN_WEAR_DETECTION][0] == 1 else "Disabled"
            else:
                status['wear_detection'] = "Unknown"
        else:
            status['wear_detection'] = "N/A"

        if ORD_RUN_WEAR_STATE in run_attrs:
            val = run_attrs[ORD_RUN_WEAR_STATE][0]
            status['wear_state'] = "Worn" if val == 1 else "Off-Ear"
        else:
            status['wear_state'] = "Unknown"

        if self.model.has_auto_shutdown and ORD_RUN_AUTO_SHUTDOWN in run_attrs:
            val = run_attrs[ORD_RUN_AUTO_SHUTDOWN][0]
            if val == 1:
                status['auto_shutdown'] = "30 minutes"
            elif val == 2:
                status['auto_shutdown'] = "1 hour"
            elif val == 6:
                status['auto_shutdown'] = "3 hours"
            elif val == 10:
                status['auto_shutdown'] = "5 hours"
            elif val == 255:
                status['auto_shutdown'] = "Never"
            else:
                status['auto_shutdown'] = f"{val * 30} minutes" if val != 0 else "Unknown"
        else:
            status['auto_shutdown'] = "N/A" if not self.model.has_auto_shutdown else "Unknown"

        if self.model.has_spatial_audio:
            if ORD_RUN_SPATIAL_AUDIO in run_attrs:
                val = run_attrs[ORD_RUN_SPATIAL_AUDIO][0]
                if val == 0:
                    status['spatial_audio'] = "Dynamic"
                elif val == 1:
                    status['spatial_audio'] = "Static"
                elif val == 2:
                    status['spatial_audio'] = "Off"
                else:
                    status['spatial_audio'] = f"Unknown ({val})"
            else:
                status['spatial_audio'] = "Unknown"

            if ORD_RUN_SPATIAL_SCENE in run_attrs:
                scene_val = run_attrs[ORD_RUN_SPATIAL_SCENE][0]
                scenes = {0: "Music", 1: "Sport", 2: "Movie"}
                status['spatial_scene'] = scenes.get(scene_val, f"Unknown ({scene_val})")
            else:
                status['spatial_scene'] = "Unknown"
        else:
            status['spatial_audio'] = "N/A"
            status['spatial_scene'] = "N/A"

        if self.model.has_anti_leak:
            if ORD_RUN_ANTI_LEAK in run_attrs:
                status['anti_leak'] = "Enabled" if run_attrs[ORD_RUN_ANTI_LEAK][0] == 1 else "Disabled"
            else:
                status['anti_leak'] = "Unknown"
        else:
            status['anti_leak'] = "N/A"

        if self.model.has_gestures:
            status['gestures'] = self.query_gestures()
        else:
            status['gestures'] = {}

        return status

    # Control API

    def set_setting(self, attr_id, val_byte):
        tlv = build_setting_tlv(attr_id, bytes([val_byte]))
        resp = self.send_and_receive(OP_READ, CMD_SET_DEVICE_INFO, tlv)
        return resp is not None

    def set_anc_mode(self, mode):
        if not self.model.has_anc or mode not in [0, 1, 2, 3, 4]:
            return False
        return self.set_setting(ATTR_WRITE_ANC_MODE, mode)

    def set_anc_level(self, level):
        if not self.model.has_anc_levels or level not in [0, 1, 2]:
            return False
        payload = bytes([4, 0, 11, 1, level])
        resp = self.send_and_receive(OP_READ, CMD_SET_DEVICE_CONFIG, payload)
        return resp is not None

    def set_game_mode(self, enable):
        return self.set_setting(ATTR_WRITE_GAME_MODE, 1 if enable else 0)

    def set_wind_noise(self, enable):
        return self.set_setting(ATTR_WRITE_WIND_NOISE, 1 if enable else 0)

    def set_multipoint(self, enable):
        return self.set_setting(ATTR_WRITE_MULTIPOINT, 1 if enable else 0)

    def set_ldac(self, enable):
        if not self.model.has_ldac:
            return False
        return self.set_setting(ATTR_WRITE_LDAC, 1 if enable else 0)

    def set_wear_detection(self, enable):
        if not self.model.has_wear_detection:
            return False
        return self.set_setting(ATTR_WRITE_WEAR_DETECTION, 1 if enable else 0)

    def set_auto_shutdown(self, val):
        if not self.model.has_auto_shutdown:
            return False
        return self.set_setting(ATTR_WRITE_AUTO_SHUTDOWN, val)

    def set_spatial_audio(self, mode):
        if not self.model.has_spatial_audio:
            return False
        return self.set_setting(ATTR_WRITE_SPATIAL_AUDIO, mode)

    def set_spatial_scene(self, scene_idx):
        if not self.model.has_spatial_audio or scene_idx not in [0, 1, 2]:
            return False
        return self.set_setting(ATTR_WRITE_SPATIAL_SCENE, scene_idx)

    def set_anti_leak(self, enable):
        if not self.model.has_anti_leak:
            return False
        return self.set_setting(ATTR_WRITE_ANTI_LEAK, 1 if enable else 0)

    def set_auto_play(self, enable):
        return self.set_setting(ATTR_WRITE_AUTO_PLAY, 1 if enable else 0)

    def set_gesture(self, gesture_type, left_func, right_func):
        if not self.model.has_gestures or gesture_type not in (1, 2, 3):
            return False
        payload = bytes([5, 0, 2, gesture_type, left_func, right_func])
        resp = self.send_and_receive(OP_READ, CMD_SET_DEVICE_CONFIG, payload)
        return resp is not None

    def set_device_name(self, name):
        name_bytes = name.encode('utf-8')
        if len(name_bytes) > 30:
            name_bytes = name_bytes[:30]
        payload = bytes([len(name_bytes) + 2, 0, 8]) + name_bytes
        self.send_and_receive(OP_READ, CMD_SET_DEVICE_CONFIG, payload)
        time.sleep(0.15)
        curr_name = self.query_device_name()
        return curr_name == name

    def find_device(self, is_play=True, earbud_id=3):
        payload = bytes([4, 0, 9, 1 if is_play else 0, earbud_id])
        self.send_and_receive(OP_READ, CMD_SET_DEVICE_CONFIG, payload)
        return True

    def get_current_eq_preset_val(self):
        try:
            run_attrs = self.query_run_info(MASK_QUERY_EQ_MODE)
            if ORD_RUN_EQ_MODE in run_attrs:
                return run_attrs[ORD_RUN_EQ_MODE][0]
        except Exception:
            pass
        try:
            return self.query_eq_preset()
        except Exception:
            pass
        return None

    def set_eq_preset(self, preset_idx):
        if self.model.eq_type == "s40":
            write_val = S40_EQ_WRITE_MAP.get(preset_idx, preset_idx)
            valid_vals = (preset_idx, write_val)
            presets_dict = S40_EQ_PRESETS
        else:
            write_val = preset_idx
            valid_vals = (preset_idx,)
            presets_dict = STANDARD_EQ_PRESETS

        # 1. Try Attribute-based (Attr ID 2, Opcode 8)
        self.set_setting(ATTR_WRITE_EQ_MODE, write_val)
        time.sleep(0.15)
        cur_val = self.get_current_eq_preset_val()
        if cur_val in valid_vals or (cur_val is not None and presets_dict.get(cur_val) == presets_dict.get(preset_idx)):
            return True

        # 2. Fallback to Config-based (Config ID 7, Opcode 242)
        payload = bytes([3, 0, 7, write_val])
        self.send_and_receive(OP_READ, CMD_SET_DEVICE_CONFIG, payload)
        time.sleep(0.15)
        cur_val = self.get_current_eq_preset_val()
        if cur_val in valid_vals or (cur_val is not None and presets_dict.get(cur_val) == presets_dict.get(preset_idx)):
            return True

        return False

    def set_custom_eq(self, gains):
        frequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        items = []
        for i, freq in enumerate(frequencies):
            g = float(gains[i]) if i < len(gains) else 0.0
            items.append(f"1,{g:.1f},{freq},1.0")
        line = f"0.0,0.0,{len(frequencies)}," + ",".join(items) + ","
        eq_file_str = f"{line}\n{line}"
        file_bytes = eq_file_str.encode('utf-8')
        file_len = len(file_bytes)

        params_data = bytes([(file_len >> 8) & 0xFF, file_len & 0xFF, 0x01]) + file_bytes
        self.send_and_receive(OP_WRITE, CMD_SEND_DEVICE_FILE, params_data)
        time.sleep(0.15)

        return self.set_eq_preset(240)

# Device discovery & port detection

HAYLOU_NAME_REGEX = re.compile(
    r"(haylou|s40|s35|s30|s33|hd01|w1|mori|flowbuds|purfree|airfree|earhook|t003|t013|t016|t021|ht02|ht03|ht06|bc04|ow02|ow03|x1)",
    re.IGNORECASE
)

def scan_paired_devices():
    devices = []
    if sys.platform == 'win32':
        try:
            ps_cmd = 'Get-PnpDevice -Class Bluetooth -Status OK | Select-Object -Property FriendlyName, InstanceId | ConvertTo-Json -Compress'
            out = subprocess.check_output(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_cmd], text=True, stderr=subprocess.DEVNULL)
            data = json.loads(out) if out.strip() else []
            if isinstance(data, dict):
                data = [data]
            for item in data:
                name = item.get("FriendlyName", "")
                inst_id = item.get("InstanceId", "")
                m = re.search(r"DEV_([0-9A-Fa-f]{12})", inst_id)
                if m and name:
                    raw_mac = m.group(1)
                    mac = ":".join(raw_mac[i:i+2] for i in range(0, 12, 2)).upper()
                    if HAYLOU_NAME_REGEX.search(name):
                        if (mac, name) not in devices:
                            devices.append((mac, name))
        except Exception as e:
            print(f"Error scanning Windows Bluetooth devices: {e}")
        return devices
    else:
        try:
            out = subprocess.check_output(["bluetoothctl", "devices"], text=True)
            for line in out.splitlines():
                m = re.match(r"Device\s+((?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})\s+(.*)", line)
                if m:
                    mac, name = m.groups()
                    if HAYLOU_NAME_REGEX.search(name):
                        devices.append((mac, name))
            return devices
        except FileNotFoundError:
            return []
        except Exception as e:
            print(f"Error scanning devices: {e}")
            return []

def find_control_port(mac_address):
    battery_req = START_PREFIX + bytes([OP_READ, CMD_GET_DEVICE_INFO, 0x00, 0x05, 0x01, 0x00, 0x00, 0x00, 0x04]) + END_SUFFIX
    try:
        s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
        s.settimeout(0.8)
        s.connect((mac_address, 10))
        s.sendall(battery_req)
        resp = s.recv(1024)
        s.close()
        if resp and START_PREFIX in resp:
            return 10
    except Exception:
        pass

    common_ports = [1, 3, 4, 5, 2, 6, 7, 8, 9, 11, 12, 13]
    for port in common_ports:
        try:
            s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
            s.settimeout(0.6)
            s.connect((mac_address, port))
            s.sendall(battery_req)
            resp = s.recv(1024)
            s.close()
            if resp and START_PREFIX in resp:
                return port
        except Exception:
            pass

    return 10

# Terminal UI rendering

def clean_ansi(s):
    return re.sub(r'\033\[[0-9;]*m', '', s)

def draw_top_border(width=58):
    print(f"{COLOR_BORDER}┌{'─' * (width - 2)}┐{RESET}")

def draw_bottom_border(width=58):
    print(f"{COLOR_BORDER}└{'─' * (width - 2)}┘{RESET}")

def draw_separator(width=58):
    print(f"{COLOR_BORDER}├{'─' * (width - 2)}┤{RESET}")

def draw_centered_line(text, width=58):
    visible_text = clean_ansi(text)
    padding_total = width - len(visible_text) - 2
    pad_left = padding_total // 2
    pad_right = padding_total - pad_left
    print(f"{COLOR_BORDER}│{RESET}{' ' * pad_left}{text}{' ' * pad_right}{COLOR_BORDER}│{RESET}")

def draw_line(label, value_str, width=58):
    left_str = f"  {COLOR_LABEL}{label:<16}{RESET} : {value_str}"
    visible_left = clean_ansi(left_str)
    spaces_needed = width - len(visible_left) - 2
    print(f"{COLOR_BORDER}│{RESET}{left_str}{' ' * spaces_needed}{COLOR_BORDER}│{RESET}")

def draw_dashboard(status, msg=""):
    print("\033[H\033[2J", end="")

    model_info = status.get('model_info', {})
    model_name = model_info.get('name', 'HAYLOU DEVICE').upper()
    caps = model_info.get('capabilities', {})

    draw_top_border()
    draw_centered_line(f"{BOLD}{COLOR_TITLE}{model_name} CONTROL{RESET}")
    draw_separator()

    dev_name = status.get('device_name', 'Unknown')
    draw_line("Device Name", f"{COLOR_VAL}{dev_name}{RESET}")

    # Battery Rendering
    b_left = status.get('battery_left')
    b_right = status.get('battery_right')
    b_case = status.get('battery_case')
    if b_left is not None and b_right is not None:
        case_txt = f" | Case: {b_case}" if b_case else ""
        draw_line("TWS Battery", f"{COLOR_ON}L: {b_left} | R: {b_right}{case_txt}{RESET}")
    else:
        battery_str = status.get('battery', 'Unknown')
        if battery_str != 'Unknown' and '%' in battery_str:
            try:
                pct = int(battery_str.replace('%', '').strip())
                bar_len = pct // 10
                bar = "█" * bar_len + "░" * (10 - bar_len)
                lvl_color = COLOR_ON if pct > 50 else (COLOR_TITLE if pct > 20 else COLOR_OFF)
                battery_display = f"{lvl_color}[{bar}] {pct}%{RESET}"
            except ValueError:
                battery_display = f"{COLOR_UNKNOWN}{battery_str}{RESET}"
        else:
            battery_display = f"{COLOR_UNKNOWN}Unknown{RESET}"
        draw_line("Battery State", battery_display)

    wear_state = status.get('wear_state', 'Unknown')
    wear_color = COLOR_ON if wear_state == "Worn" else (COLOR_TITLE if wear_state == "Off-Ear" else COLOR_UNKNOWN)
    draw_line("Wear State", f"{wear_color}{wear_state}{RESET}")
    draw_separator()

    # ANC Display
    if caps.get('has_anc', True):
        anc = status.get('anc_mode', 'Unknown')
        anc_colors = {
            "Normal (Off)": COLOR_VAL,
            "ANC On": COLOR_ON,
            "Transparency": COLOR_MENU_NUM,
            "Wind Noise (KANG_FENG)": COLOR_TITLE,
            "Adaptive Auto-ANC": "\033[38;2;155;89;182m"
        }
        anc_col = anc_colors.get(anc, COLOR_UNKNOWN)
        draw_line("ANC Mode", f"{anc_col}{anc}{RESET}")

        if caps.get('has_anc_levels', True) and anc in ["ANC On", "Adaptive Auto-ANC"]:
            anc_lvl = status.get('anc_level', 'Unknown')
            draw_line("ANC Level", f"{COLOR_VAL}{anc_lvl}{RESET}")

    # EQ Preset Display
    eq = status.get('eq_mode', 'Unknown')
    draw_line("EQ Preset", f"{COLOR_VAL}{eq}{RESET}")

    def get_toggle_display(key):
        val = status.get(key, 'Unknown')
        if val == 'Enabled':
            return f"{COLOR_ON}[ ENABLED ]{RESET}"
        elif val == 'Disabled':
            return f"{COLOR_OFF}[ DISABLED ]{RESET}"
        elif val == 'N/A':
            return f"{COLOR_UNKNOWN}[ N/A ]{RESET}"
        return f"{COLOR_UNKNOWN}[ UNKNOWN ]{RESET}"

    draw_line("Game Mode", get_toggle_display("game_mode"))
    draw_line("Wind Noise Red.", get_toggle_display("wind_noise"))
    draw_line("Multipoint", get_toggle_display("multipoint"))

    if caps.get('has_ldac', False):
        draw_line("LDAC Support", get_toggle_display("ldac"))

    if caps.get('has_wear_detection', False):
        draw_line("Wear Detection", get_toggle_display("wear_detection"))

    if caps.get('has_anti_leak', False):
        draw_line("Anti-Sound Leak", get_toggle_display("anti_leak"))

    if caps.get('has_spatial_audio', False):
        spatial_val = status.get('spatial_audio', 'Off')
        if spatial_val == 'Off':
            spatial_display = f"{COLOR_OFF}[ OFF ]{RESET}"
        elif spatial_val in ('Static', 'Dynamic'):
            spatial_display = f"{COLOR_ON}[ {spatial_val.upper()} ]{RESET}"
        else:
            spatial_display = f"{COLOR_UNKNOWN}[ {spatial_val} ]{RESET}"
        draw_line("Spatial Audio", spatial_display)

        if spatial_val != 'Off':
            scene_str = status.get('spatial_scene', 'Unknown')
            draw_line("Spatial Scene", f"{COLOR_VAL}{scene_str}{RESET}")

    if caps.get('has_auto_shutdown', True):
        shutdown_str = status.get('auto_shutdown', 'Unknown')
        draw_line("Auto-Shutdown", f"{COLOR_VAL}{shutdown_str}{RESET}")

    # Gestures preview if TWS
    gestures = status.get('gestures', {})
    if gestures:
        draw_separator()
        draw_centered_line(f"{BOLD}Touch Gestures{RESET}")
        for g_id, g_info in gestures.items():
            t_name = g_info.get("type_name", f"Type {g_id}")
            l_fn = g_info.get("left_name", "N/A")
            r_fn = g_info.get("right_name", "N/A")
            draw_line(t_name[:16], f"{COLOR_VAL}L: {l_fn} | R: {r_fn}{RESET}")

    draw_bottom_border()

    if msg:
        print(f"\n{COLOR_MSG}» Message: {msg}{RESET}\n")
    else:
        print()

def print_menu(model):
    def print_col(left_num, left_text, right_num, right_text):
        left_str = f"  {COLOR_MENU_NUM}[{left_num:>2}]{RESET} {left_text}"
        visible_left = f"  [{left_num:>2}] {left_text}"
        spaces = 32 - len(visible_left)
        right_str = f"{COLOR_MENU_NUM}[{right_num:>2}]{RESET} {right_text}"
        print(f"{left_str}{' ' * spaces}{right_str}")

    print_col("1", "Set ANC Mode", "7", "Set EQ Preset")
    print_col("2", "Toggle Game Mode", "8", "Toggle Spatial Audio" if model.has_spatial_audio else "Set Gestures")
    print_col("3", "Toggle Wind Noise", "9", "Set Spatial Audio Scene" if model.has_spatial_audio else "Toggle Anti-Leak")
    print_col("4", "Toggle Multipoint", "10", "Set Auto-Shutdown Timer")
    print_col("5", "Toggle LDAC (Reboot)" if model.has_ldac else "Toggle Auto-Play", "11", "Rename Device")
    print_col("6", "Toggle Wear Detection", "12", "Find My Device (Ring)")
    print(f"{' ' * 4} [13] Refresh Status {' ' * 8} [0] Disconnect & Exit")

# Interactive TUI mode

def interactive_menu(controller):
    msg = ""
    while True:
        try:
            status = controller.get_status()
            draw_dashboard(status, msg)
            msg = ""
        except (socket.error, OSError, RuntimeError) as e:
            print(f"\n{COLOR_OFF}Connection lost ({e}). Reconnecting...{RESET}")
            controller.disconnect()
            reconnected = False
            while not reconnected:
                try:
                    time.sleep(3.0)
                    reconnected = controller.connect()
                except (KeyboardInterrupt, SystemExit):
                    print("\nExiting.")
                    sys.exit(0)
                except Exception:
                    pass
            msg = "Connection re-established."
            continue

        model = controller.model
        print_menu(model)

        try:
            choice = input(f"\n{BOLD}Select option [0-13]:{RESET} ").strip()
        except (KeyboardInterrupt, EOFError):
            print()
            break

        if choice == "0":
            break
        elif choice == "1":
            if not model.has_anc:
                msg = "ANC is not supported on this model."
                continue
            print("\nSelect ANC Mode:")
            print(" 0. Normal (Off)")
            print(" 1. ANC On")
            print(" 2. Transparency")
            print(" 4. Adaptive ANC (Auto)")
            try:
                mode_choice = input("Select ANC mode [0, 1, 2, 4]: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue
            if mode_choice in ['0', '1', '2', '4']:
                m = int(mode_choice)
                success = controller.set_anc_mode(m)
                msg = "ANC mode updated." if success else "Failed to update ANC mode."
            else:
                msg = "Invalid ANC mode choice."
        elif choice == "2":
            current = status.get('game_mode', 'Disabled')
            enable = (current != "Enabled")
            success = controller.set_game_mode(enable)
            msg = f"Game Mode {'enabled' if enable else 'disabled'}." if success else "Failed to update Game Mode."
        elif choice == "3":
            current = status.get('wind_noise', 'Disabled')
            enable = (current != "Enabled")
            success = controller.set_wind_noise(enable)
            msg = f"Wind Noise Reduction {'enabled' if enable else 'disabled'}." if success else "Failed to update Wind Noise."
        elif choice == "4":
            current = status.get('multipoint', 'Disabled')
            enable = (current != "Enabled")
            success = controller.set_multipoint(enable)
            msg = f"Multipoint {'enabled' if enable else 'disabled'}." if success else "Failed to update Multipoint."
        elif choice == "5":
            if model.has_ldac:
                current = status.get('ldac', 'Disabled')
                enable = (current != "Enabled")
                print(f"\nToggling LDAC to {'ON' if enable else 'OFF'}...")
                print("Headphones will reboot to apply this setting.")
                success = controller.set_ldac(enable)
                if success:
                    print("Setting accepted. Headphones are rebooting...")
                    controller.disconnect()
                    time.sleep(1.0)
                    reconnected = False
                    while not reconnected:
                        try:
                            time.sleep(3.0)
                            reconnected = controller.connect()
                        except (KeyboardInterrupt, SystemExit):
                            print("\nExiting.")
                            sys.exit(0)
                        except Exception:
                            pass
                    msg = f"Reconnected! LDAC is now {'Enabled' if enable else 'Disabled'}."
                else:
                    msg = "Failed to toggle LDAC."
            else:
                current = status.get('auto_play', 'Disabled')
                enable = (current != "Enabled")
                success = controller.set_auto_play(enable)
                msg = f"In-Ear Auto Play {'enabled' if enable else 'disabled'}." if success else "Failed to update Auto-Play."
        elif choice == "6":
            if not model.has_wear_detection:
                msg = "Wear Detection is not supported on this model."
                continue
            current = status.get('wear_detection', 'Disabled')
            enable = (current != "Enabled")
            success = controller.set_wear_detection(enable)
            msg = f"Wear Detection {'enabled' if enable else 'disabled'}." if success else "Failed to update Wear Detection."
        elif choice == "7":
            presets_map = S40_EQ_PRESETS if model.eq_type == "s40" else STANDARD_EQ_PRESETS
            print(f"\nSelect EQ Preset ({model.name}):")
            if model.eq_type == "s40":
                print(" 0. Default\n 1. Subwoofer\n 2. Rock\n 3. Soft\n 4. Classical")
                valid_opts = ['0', '1', '2', '3', '4']
            else:
                for k in range(9):
                    print(f" {k}. {presets_map.get(k)}")
                valid_opts = [str(k) for k in range(9)]
            try:
                preset_choice = input(f"Select preset [{valid_opts[0]}-{valid_opts[-1]}]: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue
            if preset_choice in valid_opts:
                idx = int(preset_choice)
                success = controller.set_eq_preset(idx)
                msg = f"EQ Preset set to {presets_map.get(idx, idx)}." if success else "Failed to set EQ Preset."
            else:
                msg = "Invalid preset choice."
        elif choice == "8":
            if model.has_spatial_audio:
                print("\nSelect Spatial Audio Mode:")
                print(" 0. Off\n 1. Static\n 2. Dynamic")
                try:
                    spatial_choice = input("Select mode [0-2]: ").strip()
                except (KeyboardInterrupt, EOFError):
                    print()
                    continue
                if spatial_choice in ['0', '1', '2']:
                    m = int(spatial_choice)
                    val_map = {0: 2, 1: 1, 2: 0}
                    success = controller.set_spatial_audio(val_map[m])
                    modes_desc = {0: "Off", 1: "Static", 2: "Dynamic"}
                    msg = f"Spatial Audio set to {modes_desc[m]}." if success else "Failed to set Spatial Audio."
                else:
                    msg = "Invalid Spatial Audio choice."
            elif model.has_gestures:
                print("\nSelect Touch Gesture to Configure:")
                print(" 1. Double Tap\n 2. Triple Tap\n 3. Long Press")
                try:
                    g_type_in = input("Select gesture [1-3]: ").strip()
                except (KeyboardInterrupt, EOFError):
                    print()
                    continue
                if g_type_in in ['1', '2', '3']:
                    g_type = int(g_type_in)
                    print("\nAvailable Gesture Actions:")
                    for f_id, f_name in GESTURE_FUNCTIONS.items():
                        print(f" {f_id:>3}. {f_name}")
                    try:
                        l_fn_in = input("Select LEFT earbud action: ").strip()
                        r_fn_in = input("Select RIGHT earbud action: ").strip()
                        l_fn = int(l_fn_in)
                        r_fn = int(r_fn_in)
                        if l_fn in GESTURE_FUNCTIONS and r_fn in GESTURE_FUNCTIONS:
                            success = controller.set_gesture(g_type, l_fn, r_fn)
                            msg = f"Updated {GESTURE_TYPES[g_type]} gesture." if success else "Failed to update gesture."
                        else:
                            msg = "Invalid function code."
                    except (ValueError, KeyboardInterrupt, EOFError):
                        msg = "Invalid action input."
                else:
                    msg = "Invalid gesture type selection."
            else:
                msg = "Option not applicable to this model."
        elif choice == "9":
            if model.has_spatial_audio:
                print("\nSelect Spatial Audio Scene:")
                print(" 0. Music\n 1. Sport\n 2. Movie")
                try:
                    scene_choice = input("Select scene [0-2]: ").strip()
                except (KeyboardInterrupt, EOFError):
                    print()
                    continue
                if scene_choice in ['0', '1', '2']:
                    idx = int(scene_choice)
                    success = controller.set_spatial_scene(idx)
                    scenes = {0: "Music", 1: "Sport", 2: "Movie"}
                    msg = f"Spatial Scene set to {scenes[idx]}." if success else "Failed to update Spatial Scene."
                else:
                    msg = "Invalid Spatial Scene choice."
            elif model.has_anti_leak:
                current = status.get('anti_leak', 'Disabled')
                enable = (current != "Enabled")
                success = controller.set_anti_leak(enable)
                msg = f"Anti-Sound Leak {'enabled' if enable else 'disabled'}." if success else "Failed to update Anti-Sound Leak."
            else:
                msg = "Option not applicable to this model."
        elif choice == "10":
            if not model.has_auto_shutdown:
                msg = "Auto-Shutdown timer is not supported on this model."
                continue
            print("\nSelect Auto-Shutdown Timer Duration:")
            print(" 0. 30 Minutes\n 1. 1 Hour\n 2. 3 Hours\n 3. 5 Hours\n 4. Never (Disabled)")
            try:
                timer_choice = input("Select duration [0-4]: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue
            timer_map = {
                '0': (1, "30 minutes"),
                '1': (2, "1 hour"),
                '2': (6, "3 hours"),
                '3': (10, "5 hours"),
                '4': (255, "Never")
            }
            if timer_choice in timer_map:
                byte_val, display_name = timer_map[timer_choice]
                success = controller.set_auto_shutdown(byte_val)
                msg = f"Auto-Shutdown set to {display_name}." if success else "Failed to update Auto-Shutdown."
            else:
                msg = "Invalid timer selection."
        elif choice == "11":
            try:
                new_name = input("\nEnter new Bluetooth name: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue
            if new_name:
                print(f"Renaming device to '{new_name}'...")
                success = controller.set_device_name(new_name)
                msg = f"Device renamed to '{new_name}'." if success else "Failed to rename device."
            else:
                msg = "Device name cannot be empty."
        elif choice == "12":
            print("\nFind My Device:")
            print(" 1. Start Ringing\n 0. Stop Ringing")
            try:
                find_choice = input("Select action [0, 1]: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue
            if find_choice in ['0', '1']:
                play = (find_choice == '1')
                success = controller.find_device(is_play=play)
                msg = f"Find device sound {'started' if play else 'stopped'}." if success else "Failed to send find device command."
            else:
                msg = "Invalid find action."
        elif choice == "13":
            msg = "Status refreshed."
        else:
            msg = "Invalid option. Please choose [0-13]."

        time.sleep(0.5)

# JSON daemon mode

def json_mode_loop(controller):
    sock_lock = threading.Lock()
    cmd_queue = queue.Queue()

    def stdin_reader():
        while True:
            try:
                line = sys.stdin.readline()
                if not line:
                    break
                cmd_queue.put(line)
            except Exception:
                break
        cmd_queue.put(None)

    reader_thread = threading.Thread(target=stdin_reader, daemon=True)
    reader_thread.start()

    with sock_lock:
        try:
            status = controller.get_status()
            status["connection_status"] = "connected"
            _original_print(json.dumps(status), flush=True)
        except Exception as e:
            _original_print(json.dumps({"connection_status": "disconnected", "error": str(e)}), flush=True)
            return

    last_poll_time = time.time()

    while True:
        try:
            line = cmd_queue.get(timeout=1.0)
            if line is None:
                break

            try:
                cmd = json.loads(line)
                action = cmd.get("action") or cmd.get("command")
                value = cmd.get("value")

                success = False
                with sock_lock:
                    if action in ("set_anc", "set_anc_mode"):
                        success = controller.set_anc_mode(int(value))
                    elif action == "set_anc_level":
                        success = controller.set_anc_level(int(value))
                    elif action == "set_game_mode":
                        success = controller.set_game_mode(bool(value))
                    elif action in ("set_wind_noise", "set_wind_noise_suppression"):
                        success = controller.set_wind_noise(bool(value))
                    elif action == "set_multipoint":
                        success = controller.set_multipoint(bool(value))
                    elif action == "set_ldac":
                        success = controller.set_ldac(bool(value))
                        if success:
                            controller.disconnect()
                    elif action == "set_wear_detection":
                        success = controller.set_wear_detection(bool(value))
                    elif action == "set_anti_leak":
                        success = controller.set_anti_leak(bool(value))
                    elif action == "set_auto_play":
                        success = controller.set_auto_play(bool(value))
                    elif action == "set_auto_shutdown":
                        success = controller.set_auto_shutdown(int(value))
                    elif action == "set_spatial_audio":
                        if isinstance(value, bool):
                            val_int = 1 if value else 2
                        else:
                            try:
                                val_int = int(value)
                            except ValueError:
                                val_str = str(value).lower()
                                if val_str == "dynamic":
                                    val_int = 0
                                elif val_str == "static":
                                    val_int = 1
                                else:
                                    val_int = 2
                        success = controller.set_spatial_audio(val_int)
                    elif action == "set_spatial_scene":
                        success = controller.set_spatial_scene(int(value))
                    elif action == "set_eq_preset":
                        success = controller.set_eq_preset(int(value))
                    elif action == "set_custom_eq":
                        gains = value if isinstance(value, list) else (cmd.get("gains", []) if isinstance(cmd, dict) else [])
                        success = controller.set_custom_eq(gains)
                    elif action == "set_gesture":
                        g_type = int(cmd.get("gesture_type", value if isinstance(value, int) else 1))
                        l_fn = int(cmd.get("left_func", cmd.get("left", 255)))
                        r_fn = int(cmd.get("right_func", cmd.get("right", 255)))
                        success = controller.set_gesture(g_type, l_fn, r_fn)
                    elif action == "get_gestures":
                        success = True
                    elif action == "find_device":
                        play = bool(value) if isinstance(value, bool) else True
                        earbud_id = int(cmd.get("earbud_id", 3)) if isinstance(cmd, dict) else 3
                        success = controller.find_device(is_play=play, earbud_id=earbud_id)
                    elif action in ("rename", "rename_device"):
                        success = controller.set_device_name(str(value))
                    elif action in ("get_status", "refresh_status"):
                        success = True
                    elif action == "disconnect":
                        controller.disconnect()
                        _original_print(json.dumps({"connection_status": "disconnected"}), flush=True)
                        return

                with sock_lock:
                    try:
                        status = controller.get_status()
                        status["connection_status"] = "connected" if controller.sock else "disconnected"
                        status["command_success"] = success
                        status["last_action"] = action
                        _original_print(json.dumps(status), flush=True)
                    except Exception as e:
                        _original_print(json.dumps({"connection_status": "disconnected", "error": str(e)}), flush=True)
                        break
            except Exception as e:
                _original_print(json.dumps({"error": f"Failed to execute command: {e}"}), flush=True)

        except queue.Empty:
            pass

        if time.time() - last_poll_time >= 10.0:
            with sock_lock:
                try:
                    if controller.sock:
                        status = controller.get_status()
                        status["connection_status"] = "connected"
                        _original_print(json.dumps(status), flush=True)
                except Exception as e:
                    _original_print(json.dumps({"connection_status": "disconnected", "error": str(e)}), flush=True)
                    break
            last_poll_time = time.time()

def main():
    global JSON_MODE
    parser = argparse.ArgumentParser(description="Control Haylou Bluetooth headphones via RFCOMM.")
    parser.add_argument("-m", "--mac", help="MAC address of paired headphones (e.g. AA:BB:CC:DD:EE:FF)")
    parser.add_argument("-p", "--port", type=int, help="RFCOMM port/channel number (defaults to auto-detection)")
    parser.add_argument("-j", "--json", action="store_true", help="Enable JSON daemon mode for stdin/stdout communication")
    args = parser.parse_args()

    mac = args.mac
    if args.json:
        JSON_MODE = True
        if not mac:
            devices = scan_paired_devices()
            if not devices:
                _original_print(json.dumps({"connection_status": "no_devices"}), flush=True)
                sys.exit(0)
            mac, name = devices[0]
            _original_print(json.dumps({"connection_status": "connecting", "mac": mac, "device_name": name}), flush=True)
        else:
            _original_print(json.dumps({"connection_status": "connecting", "mac": mac}), flush=True)

        port = args.port
        if not port:
            port = find_control_port(mac)

        controller = HaylouHeadphoneController(mac, port)
        if controller.connect():
            try:
                json_mode_loop(controller)
            finally:
                controller.disconnect()
        else:
            _original_print(json.dumps({"connection_status": "failed"}), flush=True)
            sys.exit(0)
    else:
        if not mac:
            devices = scan_paired_devices()
            if not devices:
                print("No paired Haylou headphones detected via bluetoothctl.")
                mac = input("Please enter your headphone's MAC Address manually: ").strip()
                if not mac:
                    print("Error: MAC address is required.")
                    sys.exit(1)
            elif len(devices) == 1:
                mac, name = devices[0]
                print(f"Found paired device: {name} ({mac})")
            else:
                print("\nPaired Haylou devices found:")
                for i, (d_mac, d_name) in enumerate(devices):
                    print(f" [{i+1}] {d_name} ({d_mac})")
                choice = input(f"Select device [1-{len(devices)}]: ").strip()
                try:
                    idx = int(choice) - 1
                    if 0 <= idx < len(devices):
                        mac, name = devices[idx]
                    else:
                        print("Invalid selection.")
                        sys.exit(1)
                except ValueError:
                    print("Invalid input.")
                    sys.exit(1)

        port = args.port
        if not port:
            port = find_control_port(mac)

        controller = HaylouHeadphoneController(mac, port)
        if controller.connect():
            try:
                interactive_menu(controller)
            finally:
                controller.disconnect()

if __name__ == "__main__":
    main()

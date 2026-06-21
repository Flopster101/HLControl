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

# --- Protocol Constants ---
# Framing Wrappers
START_PREFIX = b"\xaa\xbb\xcc"
END_SUFFIX = b"\xdd\xee\xff"

# OP codes
OP_WRITE = 0x80
OP_READ = 0xC0
OP_RESPONSE = 0x00
OP_NOTIFY = 0x02

# Command IDs (Opcodes)
CMD_GET_DEVICE_INFO = 2
CMD_SET_DEVICE_INFO = 8
CMD_GET_DEVICE_RUN_INFO = 9
CMD_REPORT_DEVICE_STATUS = 14

# Attribute IDs for Writing Settings (Command 8)
ATTR_WRITE_AUTO_SHUTDOWN = 0     # HOT_ATTR_DEVICE_SHUTDOWN_TIME
ATTR_WRITE_MULTIPOINT = 9        # HOT_ATTR_DEVICE_ONE_TO_TWO (1 to 2 / Multipoint)
ATTR_WRITE_ANC_MODE = 4          # HOT_ATTR_DEVICE_ANC_MODE
ATTR_WRITE_GAME_MODE = 5         # HOT_ATTR_DEVICE_GAME_MODE
ATTR_WRITE_AUTO_PLAY = 6         # HOT_ATTR_DEVICE_AUTO_PLAY
ATTR_WRITE_LDAC = 8              # HOT_ATTR_DEVICE_LDAC
ATTR_WRITE_SPATIAL_AUDIO = 10    # HOT_ATTR_DEVICE_SPATISL_AUDIO
ATTR_WRITE_SPATIAL_SCENE = 11    # HOT_ATTR_DEVICE_SPATISL_AUDIO_SCENE
ATTR_WRITE_WIND_NOISE = 12       # HOT_ATTR_DEVICE_WIND_NOISE_STATUS
ATTR_WRITE_WEAR_DETECTION = 13   # HOT_ATTR_DEVICE_WEAR_DETECTION
ATTR_WRITE_EQ_MODE = 2           # HOT_ATTR_DEVICE_EQ_MODE

# Attribute IDs/Masks for Querying Run Info (Command 9)
MASK_QUERY_AUTO_SHUTDOWN = 32     # HOT_ATTR_DEVICE_SHUTDOWN_TIME (1 << 5)
MASK_QUERY_ANC_STATUS = 512       # HOP_ATTR_TYPE_GET_ANC_STATUS
MASK_QUERY_GAME_MODE = 2048       # HOP_ATTR_DEVICE_GAME_MODE
MASK_QUERY_MULTIPOINT = 131072    # HOP_ATTR_DEVICE_LINK_SUPPORT (0x00020000)
MASK_QUERY_LDAC = 65536           # HOP_ATTR_DEVICE_LACD_SUPPORT
MASK_QUERY_SPATIAL_AUDIO = 262144  # HOP_ATTR_DEVICE_SPATIAL_AUDIO (1 << 18)
MASK_QUERY_SPATIAL_SCENE = 524288  # HOP_ATTR_DEVICE_SPATIAL_AUDIO_SCENE (1 << 19)
MASK_QUERY_WIND_NOISE = 1048576   # HOP_ATTR_DEVICE_WIND_NOISE_STATUS
MASK_QUERY_WEAR_DETECTION = 2097152 # HOP_ATTR_DEVICE_WEAR_DETECTION
MASK_QUERY_WEAR_STATE = 4194304   # HOP_ATTR_DEVICE_WEAR_STATE
MASK_QUERY_EQ_MODE = 4096         # HOP_ATTR_DEVICE_EQ_MODE (1 << 12)

# Attribute IDs for Querying Device Info (Command 2)
MASK_QUERY_NAME = 1               # HOP_ATTR_TYPE_NAME (1 << 0)
MASK_QUERY_BATTERY = 4            # HOP_ATTR_TYPE_BATTERY

# Response Attribute Ordinals for Command 2 (DeviceInfoAttr)
ORD_DEV_NAME = 0
ORD_DEV_BATTERY = 2

# Response Attribute Ordinals for Command 9/14 (DeviceRunInfoAttr)
ORD_RUN_AUTO_SHUTDOWN = 5
ORD_RUN_ANC_STATUS = 9
ORD_RUN_GAME_MODE = 11
ORD_RUN_MULTIPOINT = 17           # HOP_ATTR_DEVICE_LINK_SUPPORT (Ordinal 17)
ORD_RUN_LDAC = 16
ORD_RUN_SPATIAL_AUDIO = 18
ORD_RUN_SPATIAL_SCENE = 19
ORD_RUN_WIND_NOISE = 20
ORD_RUN_WEAR_DETECTION = 21
ORD_RUN_WEAR_STATE = 22
ORD_RUN_EQ_MODE = 12

# ANC Modes Mapping
ANC_MODES = {
    0: "Normal (Off)",
    1: "ANC On",
    2: "Transparency",
    3: "Wind Noise (KANG_FENG)",
    4: "Adaptive Auto-ANC"
}

# EQ Presets Mapping for S40 (Read value mapping)
EQ_PRESETS = {
    0: "Default",
    1: "Subwoofer",
    2: "Rock",
    3: "Soft",
    4: "Classical",
    15: "Custom/Customize",
    240: "Custom/Customize"
}

# Write value mapping for S40 presets
# Maps our menu choice / read index to the correct write value
EQ_WRITE_MAP = {
    0: 0,  # Default -> Write 0
    1: 6,  # Subwoofer -> Write 6
    2: 2,  # Rock -> Write 2
    3: 7,  # Soft -> Write 7
    4: 3,  # Classical -> Write 3
}

# --- Premium Color Palette (True Color RGB) ---
COLOR_BORDER = "\033[38;2;120;81;255m"      # Elegant Violet
COLOR_TITLE = "\033[38;2;254;202;87m"       # Soft Gold
COLOR_LABEL = "\033[38;2;162;171;206m"      # Cool Grey-Blue
COLOR_VAL = "\033[38;2;240;240;245m"        # Pure Off-white
COLOR_ON = "\033[38;2;46;204;113m"          # Emerald Green
COLOR_OFF = "\033[38;2;231;76;60m"          # Rose Red
COLOR_UNKNOWN = "\033[38;2;127;140;141m"    # Muted Slate
COLOR_MSG = "\033[38;2;243;156;18m"         # Warm Amber
COLOR_MENU_NUM = "\033[38;2;52;152;219m"    # Soft Sky Blue
RESET = "\033[0m"
BOLD = "\033[1m"

# --- Protocol Serialization Helper Functions ---

def build_packet(op_code, cmd_id, sequence_sn, payload_data=None):
    """
    Constructs a framed protocol packet.
    """
    payload_len = len(payload_data) if payload_data else 0
    total_len = payload_len + 1

    header = bytes([op_code, cmd_id]) + total_len.to_bytes(2, byteorder='big')
    packet = START_PREFIX + header + bytes([sequence_sn])
    if payload_data:
        packet += payload_data
    packet += END_SUFFIX
    return packet

def build_setting_tlv(attr_id, value_bytes):
    """
    Constructs a setting TLV block.
    """
    length = len(value_bytes) + 1
    return bytes([length, attr_id]) + value_bytes

def parse_tlv_blocks(payload, has_status_byte=False):
    """
    Parses concatenated TLV blocks from response payload.
    """
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
        val = payload[idx+2 : idx+2+val_len]
        attrs[attr_id] = val
        idx += 2 + val_len
    return attrs

def parse_config_blocks(payload, has_status_byte=False):
    """
    Parses config TLV blocks (2-byte config ID) from response payload.
    """
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
        val = payload[idx+3 : idx+3+val_len]
        configs[config_id] = val
        idx += 3 + val_len
    return configs

def reset_bluetooth_connection(mac_address):
    """
    Attempts to disconnect and reconnect the Bluetooth device to release stuck RFCOMM channels.
    """
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

# --- Bluetooth Socket Communication Wrapper ---

class HaylouHeadphoneController:
    def __init__(self, mac_address, port=10):
        self.mac_address = mac_address
        self.port = port
        self.sock = None
        self.seq = 0

    def connect(self):
        print(f"Connecting to RFCOMM on {self.mac_address}:{self.port}...")
        for attempt in range(4):
            try:
                self.sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
                self.sock.connect((self.mac_address, self.port))
                self.sock.settimeout(1.0)
                print("Connected successfully!")
                return True
            except OSError as e:
                if e.errno == 16:  # Device or resource busy
                    if attempt < 3:
                        print(f"Port {self.port} is busy. Waiting for OS to release the socket (attempt {attempt+1}/4)...")
                        time.sleep(2.0)
                        continue
                    else:
                        print(f"\n[Errno 16] Port {self.port} remains busy after multiple retries.")
                        print("This happens if another process or daemon holds the RFCOMM channel.")
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

    def disconnect(self):
        if self.sock:
            self.sock.close()
            self.sock = None
            print("Disconnected.")

    def get_next_seq(self):
        self.seq = (self.seq + 1) & 0xFF
        return self.seq

    def send_and_receive(self, op_code, cmd_id, payload_data=None):
        """
        Sends a packet and waits for the corresponding response packet.
        """
        if not self.sock:
            raise RuntimeError("Not connected to headphones.")

        seq = self.get_next_seq()
        req_packet = build_packet(op_code, cmd_id, seq, payload_data)

        # Clear receive buffer using NON-BLOCKING mode to prevent delay
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

        # Read response packet
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

    # --- Query API ---

    def query_device_name(self):
        """
        Queries the Bluetooth display name of the device (Command 2, Attribute 0).
        """
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
                return attrs[ORD_DEV_BATTERY][0]
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
        """
        Queries the current EQ preset from config ID 7.
        """
        payload = bytes([0x00, 0x07])
        resp = self.send_and_receive(OP_READ, 243, payload) # 243 = CMD_GET_DEVICE_CONFIG
        if resp:
            op_code, _, _, response_payload = resp
            has_status = not (op_code & 0x40)
            configs = parse_config_blocks(response_payload, has_status_byte=has_status)
            if 7 in configs:
                val_bytes = configs[7]
                if val_bytes:
                    return val_bytes[0]
        return None

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
        status['device_name'] = name if name else "Unknown"

        battery = self.query_battery()
        status['battery'] = f"{battery}%" if battery is not None else "Unknown"

        combined_mask = (MASK_QUERY_ANC_STATUS | MASK_QUERY_GAME_MODE |
                         MASK_QUERY_MULTIPOINT | MASK_QUERY_LDAC |
                         MASK_QUERY_WIND_NOISE | MASK_QUERY_WEAR_DETECTION |
                         MASK_QUERY_WEAR_STATE | MASK_QUERY_EQ_MODE |
                         MASK_QUERY_AUTO_SHUTDOWN | MASK_QUERY_SPATIAL_AUDIO |
                         MASK_QUERY_SPATIAL_SCENE)

        run_attrs = self.query_run_info(combined_mask)

        if ORD_RUN_ANC_STATUS in run_attrs:
            anc_val = run_attrs[ORD_RUN_ANC_STATUS][0]
            status['anc_mode'] = ANC_MODES.get(anc_val, f"Unknown ({anc_val})")
        else:
            status['anc_mode'] = "Unknown"

        if ORD_RUN_EQ_MODE in run_attrs:
            eq_val = run_attrs[ORD_RUN_EQ_MODE][0]
            status['eq_mode'] = EQ_PRESETS.get(eq_val, f"Unknown ({eq_val})")
        else:
            # Fallback to query config ID 7 directly if run info doesn't return it
            eq_val = self.query_eq_preset()
            status['eq_mode'] = EQ_PRESETS.get(eq_val, f"Unknown ({eq_val})") if eq_val is not None else "Unknown"

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

        if ORD_RUN_LDAC in run_attrs:
            status['ldac'] = "Enabled" if run_attrs[ORD_RUN_LDAC][0] == 1 else "Disabled"
        else:
            status['ldac'] = "Unknown"

        if ORD_RUN_WEAR_DETECTION in run_attrs:
            status['wear_detection'] = "Enabled" if run_attrs[ORD_RUN_WEAR_DETECTION][0] == 1 else "Disabled"
        else:
            status['wear_detection'] = "Unknown"

        if ORD_RUN_WEAR_STATE in run_attrs:
            val = run_attrs[ORD_RUN_WEAR_STATE][0]
            status['wear_state'] = "Worn" if val == 1 else "Off-Ear"
        else:
            status['wear_state'] = "Unknown"

        if ORD_RUN_AUTO_SHUTDOWN in run_attrs:
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
            status['auto_shutdown'] = "Unknown"

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

        return status

    # --- Configuration Setting API ---

    def set_setting(self, attr_id, val_byte):
        tlv = build_setting_tlv(attr_id, bytes([val_byte]))
        resp = self.send_and_receive(OP_READ, CMD_SET_DEVICE_INFO, tlv)
        return resp is not None

    def set_anc_mode(self, mode):
        if mode not in [0, 1, 2, 3, 4]:
            print("Invalid ANC mode specified.")
            return False
        return self.set_setting(ATTR_WRITE_ANC_MODE, mode)

    def set_game_mode(self, enable):
        return self.set_setting(ATTR_WRITE_GAME_MODE, 1 if enable else 0)

    def set_wind_noise(self, enable):
        return self.set_setting(ATTR_WRITE_WIND_NOISE, 1 if enable else 0)

    def set_multipoint(self, enable):
        return self.set_setting(ATTR_WRITE_MULTIPOINT, 1 if enable else 0)

    def set_ldac(self, enable):
        return self.set_setting(ATTR_WRITE_LDAC, 1 if enable else 0)

    def set_wear_detection(self, enable):
        return self.set_setting(ATTR_WRITE_WEAR_DETECTION, 1 if enable else 0)

    def set_auto_shutdown(self, val):
        return self.set_setting(ATTR_WRITE_AUTO_SHUTDOWN, val)

    def set_spatial_audio(self, mode):
        # mode can be 0 (Dynamic), 1 (Static), 2 (Off)
        return self.set_setting(ATTR_WRITE_SPATIAL_AUDIO, mode)

    def set_spatial_scene(self, scene_idx):
        if scene_idx not in [0, 1, 2]:
            return False
        return self.set_setting(ATTR_WRITE_SPATIAL_SCENE, scene_idx)

    def set_device_name(self, name):
        name_bytes = name.encode('utf-8')
        if len(name_bytes) > 30:
            name_bytes = name_bytes[:30]
        # Config ID 8. Payload: [length, config_id_high, config_id_low, value...]
        payload = bytes([len(name_bytes) + 2, 0, 8]) + name_bytes
        self.send_and_receive(OP_READ, 242, payload)
        time.sleep(0.15)
        curr_name = self.query_device_name()
        return curr_name == name

    def get_current_eq_preset_val(self):
        """
        Queries the active EQ preset value from either run info or config ID 7.
        """
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
        """
        Sets the EQ preset. Tries attribute-based (ID 2) first, verifies, and falls back to config-based (ID 7).
        """
        write_val = EQ_WRITE_MAP.get(preset_idx, preset_idx)

        # 1. Try Attribute-based (Attr ID 2, opcode 8)
        self.set_setting(ATTR_WRITE_EQ_MODE, write_val)
        time.sleep(0.15)
        if self.get_current_eq_preset_val() == preset_idx:
            return True

        # 2. Fallback to Config-based (Config ID 7, opcode 242)
        payload = bytes([3, 0, 7, write_val])
        self.send_and_receive(OP_READ, 242, payload)
        time.sleep(0.15)
        if self.get_current_eq_preset_val() == preset_idx:
            return True

        return False

# --- Automatic Device Discovery & Port Probing ---

def scan_paired_devices():
    """
    Scans Linux bluez devices list to find any compatible Haylou audio device.
    """
    print("Scanning paired Bluetooth devices...")
    try:
        out = subprocess.check_output(["bluetoothctl", "devices"], text=True)
        devices = []
        for line in out.splitlines():
            m = re.match(r"Device\s+((?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})\s+(.*)", line)
            if m:
                mac, name = m.groups()
                if any(x in name.lower() for x in ["haylou", "s40", "s35", "s30"]):
                    devices.append((mac, name))
        return devices
    except FileNotFoundError:
        return []
    except Exception as e:
        print(f"Error scanning devices: {e}")
        return []

def find_control_port(mac_address):
    """
    Probes open RFCOMM ports to locate the custom Liesheng SPP control service channel.
    """
    print(f"Detecting Liesheng control channel on {mac_address}...")

    # 1. Try default port 10 first (Liesheng standard)
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

    # 2. Probe other common ports if default fails
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
                print(f"Control service discovered on RFCOMM port {port}.")
                return port
        except Exception:
            pass

    # Default fallback
    return 10

# --- TUI Beautification Drawing & Padding Calculations ---

def clean_ansi(s):
    """
    Removes ANSI formatting escape sequences to calculate exact visible string lengths.
    """
    return re.sub(r'\033\[[0-9;]*m', '', s)

def draw_top_border(width=58):
    print(f"{COLOR_BORDER}┌{'─' * (width - 2)}┐{RESET}")

def draw_bottom_border(width=58):
    print(f"{COLOR_BORDER}└{'─' * (width - 2)}┘{RESET}")

def draw_separator(width=58):
    print(f"{COLOR_BORDER}├{'─' * (width - 2)}┤{RESET}")

def draw_centered_line(text, width=58):
    """
    Draws a centered line of text within the borders.
    """
    visible_text = clean_ansi(text)
    padding_total = width - len(visible_text) - 2
    pad_left = padding_total // 2
    pad_right = padding_total - pad_left
    print(f"{COLOR_BORDER}│{RESET}{' ' * pad_left}{text}{' ' * pad_right}{COLOR_BORDER}│{RESET}")

def draw_line(label, value_str, width=58):
    """
    Draws a left-aligned labeled value line within the borders.
    """
    left_str = f"  {COLOR_LABEL}{label:<16}{RESET} : {value_str}"
    visible_left = clean_ansi(left_str)

    # Calculate spacing needed to reach the right border
    spaces_needed = width - len(visible_left) - 2
    print(f"{COLOR_BORDER}│{RESET}{left_str}{' ' * spaces_needed}{COLOR_BORDER}│{RESET}")

def draw_dashboard(status, msg=""):
    """
    Renders a colored box-drawn TUI dashboard representing the headset states.
    """
    # Clear terminal screen
    print("\033[H\033[2J", end="")

    draw_top_border()
    draw_centered_line(f"{BOLD}{COLOR_TITLE}★ HAYLOU S40 CONTROL SYSTEM ★{RESET}")
    draw_separator()

    # Device Name Display
    dev_name = status.get('device_name', 'Unknown')
    draw_line("Device Name", f"{COLOR_VAL}{dev_name}{RESET}")

    # Battery Rendering
    battery_str = status.get('battery', 'Unknown')
    if battery_str != 'Unknown' and '%' in battery_str:
        try:
            pct = int(battery_str.replace('%', ''))
            bar_len = pct // 10
            bar = "█" * bar_len + "░" * (10 - bar_len)

            if pct > 50:
                lvl_color = COLOR_ON
            elif pct > 20:
                lvl_color = COLOR_TITLE
            else:
                lvl_color = COLOR_OFF
            battery_display = f"{lvl_color}[{bar}] {pct}%{RESET}"
        except ValueError:
            battery_display = f"{COLOR_UNKNOWN}{battery_str}{RESET}"
    else:
        battery_display = f"{COLOR_UNKNOWN}Unknown{RESET}"

    draw_line("Battery State", battery_display)

    # Wear State
    wear_state = status.get('wear_state', 'Unknown')
    wear_color = COLOR_ON if wear_state == "Worn" else (COLOR_TITLE if wear_state == "Off-Ear" else COLOR_UNKNOWN)
    draw_line("Wear State", f"{wear_color}{wear_state}{RESET}")
    draw_separator()

    # ANC Mode Display
    anc = status.get('anc_mode', 'Unknown')
    anc_colors = {
        "Normal (Off)": COLOR_VAL,
        "ANC On": COLOR_ON,
        "Transparency": COLOR_MENU_NUM,
        "Wind Noise (KANG_FENG)": COLOR_TITLE,
        "Adaptive Auto-ANC": "\033[38;2;155;89;182m"  # Soft Purple
    }
    anc_col = anc_colors.get(anc, COLOR_UNKNOWN)
    draw_line("ANC Mode", f"{anc_col}{anc}{RESET}")

    # EQ Preset Display
    eq = status.get('eq_mode', 'Unknown')
    draw_line("EQ Preset", f"{COLOR_VAL}{eq}{RESET}")

    # Helper to generate toggle labels
    def get_toggle_display(key):
        val = status.get(key, 'Unknown')
        if val == 'Enabled':
            return f"{COLOR_ON}[ ENABLED ]{RESET}"
        elif val == 'Disabled':
            return f"{COLOR_OFF}[ DISABLED ]{RESET}"
        return f"{COLOR_UNKNOWN}[ UNKNOWN ]{RESET}"

    draw_line("Game Mode", get_toggle_display("game_mode"))
    draw_line("Wind Noise Red.", get_toggle_display("wind_noise"))
    draw_line("Multipoint", get_toggle_display("multipoint"))
    draw_line("LDAC Support", get_toggle_display("ldac"))
    draw_line("Wear Detection", get_toggle_display("wear_detection"))

    # Spatial Audio Displays
    spatial_val = status.get('spatial_audio', 'Off')
    if spatial_val == 'Off':
        spatial_display = f"{COLOR_OFF}[ OFF ]{RESET}"
    elif spatial_val == 'Static':
        spatial_display = f"{COLOR_ON}[ STATIC ]{RESET}"
    elif spatial_val == 'Dynamic':
        spatial_display = f"{COLOR_ON}[ DYNAMIC ]{RESET}"
    else:
        spatial_display = f"{COLOR_UNKNOWN}[ {spatial_val} ]{RESET}"
    draw_line("Spatial Audio", spatial_display)

    if spatial_val != 'Off':
        scene_str = status.get('spatial_scene', 'Unknown')
        draw_line("Spatial Scene", f"{COLOR_VAL}{scene_str}{RESET}")
    else:
        draw_line("Spatial Scene", f"{COLOR_UNKNOWN}N/A (Disabled){RESET}")

    # Auto-Shutdown Timer
    shutdown_str = status.get('auto_shutdown', 'Unknown')
    draw_line("Auto-Shutdown", f"{COLOR_VAL}{shutdown_str}{RESET}")

    draw_bottom_border()

    if msg:
        print(f"\n{COLOR_MSG}» Message: {msg}{RESET}\n")
    else:
        print()

def print_menu():
    def print_col(left_num, left_text, right_num, right_text):
        left_str = f"  {COLOR_MENU_NUM}[{left_num}]{RESET} {left_text}"
        visible_left = f"  [{left_num}] {left_text}"
        spaces = 30 - len(visible_left)
        right_str = f"{COLOR_MENU_NUM}[{right_num}]{RESET} {right_text}"
        print(f"{left_str}{' ' * spaces}{right_str}")

    print_col("1", "Set ANC Mode", "7", "Set EQ Preset")
    print_col("2", "Toggle Game Mode", "8", "Toggle Spatial Audio")
    print_col("3", "Toggle Wind Noise", "9", "Set Spatial Audio Scene")
    print_col("4", "Toggle Multipoint", "10", "Set Auto-Shutdown Timer")
    print_col("5", "Toggle LDAC (Reboot)", "11", "Rename Device")
    print_col("6", "Toggle Wear Detection", "12", "Refresh Status")
    print(f"{' ' * 19}{COLOR_OFF}[0]{RESET} Disconnect & Exit")

# --- Interactive TUI Loop ---

def interactive_menu(controller):
    msg = ""
    while True:
        try:
            status = controller.get_status()
            draw_dashboard(status, msg)
            msg = "" # Reset message
        except (socket.error, OSError, RuntimeError) as e:
            print(f"\n{COLOR_OFF}Connection lost ({e}). Headphones may be restarting or out of range.{RESET}")
            print("Attempting to reconnect (reboot recovery mode)...")
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
            msg = "Connection re-established successfully!"
            continue

        print_menu()

        try:
            choice = input(f"\n{BOLD}Select option [0-12]:{RESET} ").strip()
        except (KeyboardInterrupt, EOFError):
            print()
            break

        if choice == "0":
            break
        elif choice == "1":
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
            current = status.get('ldac', 'Disabled')
            enable = (current != "Enabled")
            print(f"\nToggling LDAC to {'ON' if enable else 'OFF'}...")
            print("Headphones will reboot to apply this setting.")
            success = controller.set_ldac(enable)
            if success:
                print("Setting accepted. Headphones are rebooting...")
                controller.disconnect()
                time.sleep(1.0)
                print("Entering reconnection loop...")
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
        elif choice == "6":
            current = status.get('wear_detection', 'Disabled')
            enable = (current != "Enabled")
            success = controller.set_wear_detection(enable)
            msg = f"Wear Detection {'enabled' if enable else 'disabled'}." if success else "Failed to update Wear Detection."
        elif choice == "7":
            print("\nSelect EQ Preset:")
            print(" 0. Default (Flat)")
            print(" 1. Subwoofer")
            print(" 2. Rock")
            print(" 3. Soft")
            print(" 4. Classical")
            try:
                eq_choice = input("Select preset [0-4]: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue
            if eq_choice in [str(x) for x in range(5)]:
                idx = int(eq_choice)
                success = controller.set_eq_preset(idx)
                msg = f"EQ Preset updated to {EQ_PRESETS[idx]}." if success else "Failed to update EQ Preset."
            else:
                msg = "Invalid EQ Preset choice."
        elif choice == "8":
            print("\nSelect Spatial Audio Mode:")
            print(" 0. Off (Close)")
            print(" 1. Static (Spatial Audio On)")
            print(" 2. Dynamic (Head Tracking)")
            try:
                spatial_choice = input("Select mode [0-2]: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue
            if spatial_choice in ['0', '1', '2']:
                m = int(spatial_choice)
                # Map option: 0 -> 2 (Off), 1 -> 1 (Static), 2 -> 0 (Dynamic)
                val_map = {0: 2, 1: 1, 2: 0}
                success = controller.set_spatial_audio(val_map[m])
                modes_desc = {0: "Off", 1: "Static", 2: "Dynamic"}
                msg = f"Spatial Audio mode set to {modes_desc[m]}." if success else "Failed to set Spatial Audio mode."
            else:
                msg = "Invalid Spatial Audio mode choice."
        elif choice == "9":
            print("\nSelect Spatial Audio Scene:")
            print(" 0. Music (Music surround optimization)")
            print(" 1. Sport (Active sports tuning)")
            print(" 2. Movie (Theater/Cinematic surround)")
            try:
                scene_choice = input("Select scene [0-2]: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue
            if scene_choice in ['0', '1', '2']:
                idx = int(scene_choice)
                success = controller.set_spatial_scene(idx)
                scenes = {0: "Music", 1: "Sport", 2: "Movie"}
                msg = f"Spatial Scene updated to {scenes[idx]}." if success else "Failed to update Spatial Scene."
            else:
                msg = "Invalid Spatial Scene choice."
        elif choice == "10":
            print("\nSelect Auto-Shutdown Timer Duration:")
            print(" 0. 30 Minutes")
            print(" 1. 1 Hour")
            print(" 2. 3 Hours")
            print(" 3. 5 Hours")
            print(" 4. Never (Disabled)")
            try:
                timer_choice = input("Select duration [0-4]: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue

            # Map choice to timer byte values (1=30m, 2=1h, 6=3h, 10=5h, 255=Never)
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
                msg = f"Auto-Shutdown timer set to {display_name}." if success else "Failed to update Auto-Shutdown timer."
            else:
                msg = "Invalid timer selection."
        elif choice == "11":
            try:
                new_name = input("\nEnter new Bluetooth name for the device: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                continue
            if new_name:
                print(f"Renaming device to '{new_name}'...")
                success = controller.set_device_name(new_name)
                msg = f"Device successfully renamed to '{new_name}'." if success else "Failed to rename device."
            else:
                msg = "Device name cannot be empty."
        elif choice == "12":
            msg = "Status refreshed."
        else:
            msg = "Invalid option. Please choose [0-12]."

        time.sleep(0.5)

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

    # Initial status print
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
                action = cmd.get("action")
                value = cmd.get("value")

                success = False
                with sock_lock:
                    if action == "set_anc":
                        success = controller.set_anc_mode(int(value))
                    elif action == "set_game_mode":
                        success = controller.set_game_mode(bool(value))
                    elif action == "set_wind_noise":
                        success = controller.set_wind_noise(bool(value))
                    elif action == "set_multipoint":
                        success = controller.set_multipoint(bool(value))
                    elif action == "set_ldac":
                        success = controller.set_ldac(bool(value))
                        if success:
                            controller.disconnect()
                    elif action == "set_wear_detection":
                        success = controller.set_wear_detection(bool(value))
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
                    elif action == "rename":
                        success = controller.set_device_name(str(value))
                    elif action == "get_status":
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
    parser = argparse.ArgumentParser(description="Control Haylou/Liesheng Bluetooth Headphones from PC.")
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

import csv
import datetime
import os
import sys
import threading
import time

import serial
from serial.tools import list_ports


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "fingerprints")
INDEX_CSV = os.path.join(DATA_DIR, "index.csv")
EVENTS_CSV = os.path.join(DATA_DIR, "events.csv")
TEMPLATES_CSV = os.path.join(DATA_DIR, "templates.csv")


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def ensure_csv(path, header):
    if not os.path.exists(path):
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(header)


def choose_serial_port(default="COM5"):
    ports = list(list_ports.comports())
    if not ports:
        print("No serial ports detected; trying default:", default)
        return default

    print("Available serial ports:")
    for i, p in enumerate(ports):
        print(f"  [{i}] {p.device} - {p.description}")

    choice = input(f"Select port index or press Enter to use {default}: ").strip()
    if choice == "":
        return default
    try:
        return ports[int(choice)].device
    except Exception:
        print("Invalid selection, using default:", default)
        return default


def load_index():
    id_to_name = {}
    if not os.path.exists(INDEX_CSV):
        return id_to_name

    with open(INDEX_CSV, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                fid = int(row["fingerprint_id"])
            except Exception:
                continue
            id_to_name[fid] = row.get("person_name", "Unknown") or "Unknown"
    return id_to_name


def write_full_index(id_to_name):
    with open(INDEX_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["fingerprint_id", "person_name", "updated_at"])
        for fid in sorted(id_to_name.keys()):
            writer.writerow([fid, id_to_name[fid], now_iso()])


def append_event(event_type, fingerprint_id, person_name, status, raw_message):
    with open(EVENTS_CSV, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([now_iso(), event_type, fingerprint_id, person_name, status, raw_message])


def append_template_chunk(fingerprint_id, chunk_index, hex_payload):
    with open(TEMPLATES_CSV, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([now_iso(), fingerprint_id, chunk_index, hex_payload])


def run_simulation_write_test():
    os.makedirs(DATA_DIR, exist_ok=True)
    ensure_csv(INDEX_CSV, ["fingerprint_id", "person_name", "updated_at"])
    ensure_csv(EVENTS_CSV, ["timestamp", "event_type", "fingerprint_id", "person_name", "status", "raw_message"])
    ensure_csv(TEMPLATES_CSV, ["timestamp", "fingerprint_id", "chunk_index", "hex_payload"])

    demo_map = {1: "Sim_User"}
    write_full_index(demo_map)
    append_event("ENROLL", 1, "Sim_User", "OK", "ENROLL:1:OK")
    append_event("SCAN", 1, "Sim_User", "MATCH", "SCAN:1:MATCH")
    append_template_chunk(1, 0, "A1B2C3D4")
    append_event("TEMPLATE_END", 1, "Sim_User", "BYTES_4", "TEMPLATE_END:1:4")

    print("Simulation complete. Local files written:")
    print(" ", INDEX_CSV)
    print(" ", EVENTS_CSV)
    print(" ", TEMPLATES_CSV)


def parse_enroll(parts):
    if len(parts) < 2:
        return None, "BAD_FORMAT"
    try:
        fid = int(parts[1])
    except Exception:
        return None, "BAD_ID"
    status = parts[2] if len(parts) >= 3 else "UNKNOWN"
    return fid, status


def parse_scan(parts):
    if len(parts) < 2:
        return None, "BAD_FORMAT"
    try:
        fid = int(parts[1])
    except Exception:
        return None, "BAD_ID"
    status = parts[2] if len(parts) >= 3 else "UNKNOWN"
    return fid, status


def command_to_wire(cmd):
    tokens = cmd.strip().split()
    if not tokens:
        return None

    head = tokens[0].lower()
    if head == "enroll":
        return "ENROLL"
    if head == "scan":
        return "SCAN"
    if head == "list":
        return "LIST_IDS"
    if head == "export" and len(tokens) == 2:
        return f"TEMPLATE_EXPORT:{tokens[1]}"
    if head == "export_all":
        return "TEMPLATE_EXPORT_ALL"
    if head == "help":
        return "HELP"
    return None


def get_arg_value(flag_name):
    if flag_name not in sys.argv:
        return None
    idx = sys.argv.index(flag_name)
    if idx + 1 >= len(sys.argv):
        return None
    return sys.argv[idx + 1]


def main():
    if "--simulate" in sys.argv:
        run_simulation_write_test()
        return

    batch_text = get_arg_value("--batch")
    batch_wait_text = get_arg_value("--batch-wait")
    final_wait_text = get_arg_value("--final-wait")
    explicit_port = get_arg_value("--port")

    batch_wait_seconds = 2.0
    final_wait_seconds = 4.0
    if batch_wait_text:
        try:
            batch_wait_seconds = float(batch_wait_text)
        except Exception:
            pass
    if final_wait_text:
        try:
            final_wait_seconds = float(final_wait_text)
        except Exception:
            pass

    os.makedirs(DATA_DIR, exist_ok=True)
    ensure_csv(INDEX_CSV, ["fingerprint_id", "person_name", "updated_at"])
    ensure_csv(EVENTS_CSV, ["timestamp", "event_type", "fingerprint_id", "person_name", "status", "raw_message"])
    ensure_csv(TEMPLATES_CSV, ["timestamp", "fingerprint_id", "chunk_index", "hex_payload"])

    print("Saving files in:", DATA_DIR)

    id_to_name = load_index()
    lock = threading.Lock()
    stop_event = threading.Event()

    port = explicit_port if explicit_port else choose_serial_port("COM5")
    try:
        ser = serial.Serial(port, 115200, timeout=1)
    except Exception as e:
        print(f"Failed to open serial port {port}: {e}")
        return

    time.sleep(2)
    print("Connected to", port)
    print("Commands: enroll | scan | list | export <id> | export_all | name <id> <person_name> | quit")

    def handle_serial_line(line):
        parts = line.split(":")
        tag = parts[0] if parts else ""

        with lock:
            if tag == "ENROLL":
                fid, status = parse_enroll(parts)
                if fid is None:
                    append_event("ENROLL", -1, "Unknown", status, line)
                    return
                if status.upper() == "OK" and fid not in id_to_name:
                    id_to_name[fid] = f"Unknown_{fid}"
                    write_full_index(id_to_name)
                append_event("ENROLL", fid, id_to_name.get(fid, "Unknown"), status, line)
                print(f"[event] ENROLL id={fid} status={status}")
                if id_to_name.get(fid, "").startswith("Unknown_"):
                    print(f"Set a name with: name {fid} <person_name>")

            elif tag == "SCAN":
                fid, status = parse_scan(parts)
                if fid is None:
                    append_event("SCAN", -1, "Unknown", status, line)
                    return
                name = id_to_name.get(fid, "Unknown")
                append_event("SCAN", fid, name, status, line)
                print(f"[event] SCAN id={fid} name={name} status={status}")

            elif tag == "TEMPLATE_BEGIN":
                fid = -1
                if len(parts) >= 2:
                    try:
                        fid = int(parts[1])
                    except Exception:
                        pass
                append_event("TEMPLATE_BEGIN", fid, id_to_name.get(fid, "Unknown"), "BEGIN", line)
                print(f"[event] TEMPLATE_BEGIN id={fid}")

            elif tag == "TEMPLATE_CHUNK":
                if len(parts) < 4:
                    append_event("TEMPLATE_CHUNK", -1, "Unknown", "BAD_FORMAT", line)
                    return
                try:
                    fid = int(parts[1])
                    chunk_index = int(parts[2])
                except Exception:
                    append_event("TEMPLATE_CHUNK", -1, "Unknown", "BAD_ID_OR_INDEX", line)
                    return
                hex_payload = parts[3].strip().upper()
                append_template_chunk(fid, chunk_index, hex_payload)

            elif tag == "TEMPLATE_END":
                fid = -1
                total = "0"
                if len(parts) >= 2:
                    try:
                        fid = int(parts[1])
                    except Exception:
                        pass
                if len(parts) >= 3:
                    total = parts[2]
                append_event("TEMPLATE_END", fid, id_to_name.get(fid, "Unknown"), f"BYTES_{total}", line)
                print(f"[event] TEMPLATE_END id={fid} total_bytes={total}")

            elif tag == "TEMPLATE_ERROR":
                fid = -1
                reason = "UNKNOWN"
                if len(parts) >= 2:
                    try:
                        fid = int(parts[1])
                    except Exception:
                        pass
                if len(parts) >= 3:
                    reason = parts[2]
                append_event("TEMPLATE_ERROR", fid, id_to_name.get(fid, "Unknown"), reason, line)
                print(f"[event] TEMPLATE_ERROR id={fid} reason={reason}")

            elif tag in ("IDS", "IDS_COUNT", "TEMPLATE_EXPORT_ALL_BEGIN", "TEMPLATE_EXPORT_ALL_END", "ERROR"):
                append_event(tag, -1, "Unknown", "INFO", line)
                print(f"[info] {line}")

            else:
                append_event("RAW", -1, "Unknown", "UNPARSED", line)
                print(f"[raw] {line}")

    def serial_reader():
        while not stop_event.is_set():
            raw = ser.readline()
            if not raw:
                continue
            try:
                line = raw.decode(errors="ignore").strip()
            except Exception:
                line = ""
            if line:
                handle_serial_line(line)

    reader_thread = threading.Thread(target=serial_reader, daemon=True)
    reader_thread.start()

    try:
        if batch_text:
            commands = [c.strip() for c in batch_text.split(",") if c.strip()]
            print("Running batch commands:", commands)
            for c in commands:
                wire_cmd = command_to_wire(c)
                if wire_cmd is None:
                    print("Skipping unknown batch command:", c)
                    continue
                ser.write((wire_cmd + "\n").encode("utf-8"))
                print("[sent]", wire_cmd)
                time.sleep(batch_wait_seconds)

            # Keep port open briefly so serial reader can capture trailing packets.
            time.sleep(final_wait_seconds)

        else:
            while True:
                user = input("cmd> ").strip()
                if not user:
                    continue

                if user.lower() == "quit":
                    break

                if user.lower().startswith("name "):
                    pieces = user.split(maxsplit=2)
                    if len(pieces) < 3:
                        print("Usage: name <id> <person_name>")
                        continue
                    try:
                        fid = int(pieces[1])
                    except Exception:
                        print("Invalid ID")
                        continue
                    with lock:
                        id_to_name[fid] = pieces[2]
                        write_full_index(id_to_name)
                        append_event("NAME_UPDATE", fid, pieces[2], "OK", user)
                    print(f"Saved mapping: {fid} -> {pieces[2]}")
                    continue

                wire_cmd = command_to_wire(user)
                if wire_cmd is None:
                    print("Unknown command. Use: enroll | scan | list | export <id> | export_all | name <id> <person_name> | quit")
                    continue

                ser.write((wire_cmd + "\n").encode("utf-8"))
                print("[sent]", wire_cmd)

    except KeyboardInterrupt:
        print("\nInterrupted.")
    finally:
        stop_event.set()
        try:
            ser.close()
        except Exception:
            pass
        print("Serial closed.")
        print("Local files:")
        print(" ", INDEX_CSV)
        print(" ", EVENTS_CSV)
        print(" ", TEMPLATES_CSV)


if __name__ == "__main__":
    main()

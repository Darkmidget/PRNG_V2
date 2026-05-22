import time

import serial


PORT = "COM5"
BAUD = 115200


def main():
    print(f"Opening {PORT} @ {BAUD}")
    ser = serial.Serial(PORT, BAUD, timeout=0.5)
    try:
        time.sleep(3)
        for cmd in ["HELP", "LIST_IDS", "SCAN"]:
            print("SEND:", cmd)
            ser.write((cmd + "\n").encode("utf-8"))
            end = time.time() + 3.0
            saw_any = False
            while time.time() < end:
                raw = ser.readline()
                if raw:
                    saw_any = True
                    print("RECV:", raw.decode(errors="ignore").strip())
            if not saw_any:
                print("RECV: <none>")
    finally:
        ser.close()
    print("Done")


if __name__ == "__main__":
    main()

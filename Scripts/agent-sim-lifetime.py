#!/usr/bin/env python3
"""Release only recorded, unleased agent simulators; never boot or erase a device."""
import argparse
from contextlib import ExitStack
import json
import os
import re
from pathlib import Path
import select
import subprocess
import sys
import time
import uuid


def identity(pid):
    result = subprocess.run(["ps", "-p", str(pid), "-o", "lstart="], capture_output=True, text=True, check=False)
    if result.returncode not in (0, 1) or result.returncode == 1 and (result.stderr.strip() or result.stdout.strip()):
        raise RuntimeError("Could not verify simulator owner")
    started = result.stdout.strip()
    if result.returncode == 0 and not re.fullmatch(r"\w{3}\s+\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4}", started):
        raise RuntimeError("Could not parse simulator owner identity")
    return started


def write_record(path, record):
    temporary = path.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(record))
    temporary.replace(path)


def record_is_current(path, record):
    try:
        return json.loads(path.read_text()).get("token") == record["token"]
    except FileNotFoundError:
        return False


def remove_record(path, record):
    if record_is_current(path, record):
        path.unlink()


def slot_value(slot):
    try:
        return slot.read_text()
    except FileNotFoundError:
        return None


def lease_active(record):
    return slot_value(Path(record["slot"])) == record["lease"] and identity(record["owner"]) == record["started"]


def wait_release(record):
    if hasattr(select, "kqueue") and lease_active(record):
        with ExitStack() as stack:
            try:
                slot = stack.enter_context(Path(record["slot"]).open())
            except FileNotFoundError:
                return
            queue = select.kqueue()
            stack.callback(queue.close)
            events = [select.kevent(slot.fileno(), filter=select.KQ_FILTER_VNODE, flags=select.KQ_EV_ADD | select.KQ_EV_ONESHOT,
                                   fflags=select.KQ_NOTE_DELETE | select.KQ_NOTE_WRITE | select.KQ_NOTE_RENAME),
                      select.kevent(record["owner"], filter=select.KQ_FILTER_PROC, flags=select.KQ_EV_ADD | select.KQ_EV_ONESHOT,
                                   fflags=select.KQ_NOTE_EXIT)]
            try:
                queue.control(events, 0, 0)
                # The slot may disappear or be replaced before notifications attach.
                if not lease_active(record):
                    return
                queue.control(None, 2, None)
            except ProcessLookupError:
                return
    while lease_active(record):
        time.sleep(2)


def cleanup(record):
    slot = Path(record["slot"])
    lock = slot.parent / ".sim-lifecycle.lock"
    try:
        lock.mkdir()
    except FileExistsError:
        return False
    marker = f"{os.getpid()} cleanup {record['token']}\n"
    (lock / "pid").write_text(str(os.getpid()))
    reserved = False
    try:
        path = slot.with_suffix(".lifetime.json")
        if path.exists() and not record_is_current(path, record):
            return True
        current = slot_value(slot)
        if current is not None:
            if current != record["lease"] or identity(record["owner"]) == record["started"]:
                return True
            slot.unlink(missing_ok=True)
        with slot.open("x") as handle:
            handle.write(marker)
        reserved = True
        result = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "-j"], capture_output=True, text=True, check=True, timeout=15)
        devices = [device for group in json.loads(result.stdout)["devices"].values() for device in group]
        device = next((device for device in devices if device["udid"] == record["udid"]), None)
        if not device or device["name"] != record["name"] or device["state"] == "Shutdown":
            return True
        # A foreign XCTest guest is not permission to shut down its device.
        processes = subprocess.check_output(["ps", "-axo", "pid=,ppid=,command="], text=True)
        rows = [line.strip().split(None, 2) for line in processes.splitlines()]
        parents = {row[0] for row in rows if len(row) == 3 and "launchd_sim" in row[2] and f"/Devices/{record['udid']}/" in row[2]}
        if any(len(row) == 3 and row[1] in parents and ("/Agents/xctest" in row[2] or "TrinketUITests-Runner" in row[2]) for row in rows):
            return True
        subprocess.run(["xcrun", "simctl", "shutdown", record["udid"]], check=True, timeout=30)
        deadline = time.monotonic() + 30
        while True:
            result = subprocess.run(["xcrun", "simctl", "list", "devices", record["udid"], "-j"], capture_output=True, text=True, check=True, timeout=15)
            devices = [device for group in json.loads(result.stdout)["devices"].values() for device in group]
            if any(device["udid"] == record["udid"] and device["state"] == "Shutdown" for device in devices):
                break
            if time.monotonic() >= deadline:
                raise RuntimeError("Idle simulator did not finish shutdown; preserve its ownership record")
            time.sleep(.2)
        print(f"Released idle {record['name']} ({record['udid']}).", flush=True)
        return True
    finally:
        if reserved and slot.exists() and slot.read_text() == marker:
            slot.unlink()
        if (lock / "pid").read_text().strip() == str(os.getpid()):
            (lock / "pid").unlink()
            lock.rmdir()


def watch(path, token):
    record = json.loads(path.read_text())
    if record["token"] != token:
        return
    wait_release(record)
    time.sleep(record["grace"])
    while record_is_current(path, record):
        if cleanup(record):
            remove_record(path, record)
            return
        time.sleep(1)


def register(args):
    slot = Path(args.slot).resolve()
    if not slot.exists():
        return
    lease = slot.read_text()
    if lease.split()[0] != str(args.owner) or args.name != f"Trinket Agent {slot.stem}":
        return
    started = identity(args.owner)
    if not started:
        return
    path = slot.with_suffix(".lifetime.json")
    if path.exists():
        previous = json.loads(path.read_text())
        if previous["lease"] == lease and previous["udid"] == args.udid and previous.get("guardianStarted") and identity(previous["guardian"]) == previous["guardianStarted"]:
            return
    record = {"owner": args.owner, "started": started, "lease": lease, "slot": str(slot), "name": args.name,
              "udid": args.udid, "grace": args.grace, "token": uuid.uuid4().hex}
    write_record(path, record)
    with path.with_suffix(".log").open("a") as log:
        child = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "watch", str(path), "--token", record["token"]], stdin=subprocess.DEVNULL,
                                 stdout=log, stderr=log, start_new_session=True)
    record["guardian"] = child.pid
    record["guardianStarted"] = identity(child.pid)
    if not record["guardianStarted"]:
        raise RuntimeError("Simulator lifetime watcher did not start; preserve its record")
    write_record(path, record)
    return child


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    launch = sub.add_parser("register")
    launch.add_argument("--slot", required=True)
    launch.add_argument("--owner", type=int, required=True)
    launch.add_argument("--udid", required=True)
    launch.add_argument("--name", required=True)
    launch.add_argument("--grace", type=int, default=60)
    monitor = sub.add_parser("watch")
    monitor.add_argument("record", type=Path)
    monitor.add_argument("--token", required=True)
    args = parser.parse_args()
    if args.command == "register":
        if args.owner < 1 or not 0 <= args.grace <= 3600:
            parser.error("Owner must be positive; grace must be between 0 and 3600 seconds")
        register(args)
    else:
        watch(args.record, args.token)


if __name__ == "__main__":
    main()

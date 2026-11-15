#!/usr/bin/env python3
"""Scripted 3270BBS tests for the MiniSQL Workbench (dbwork.bas).

Each scenario stages the program(s) on the BBS, runs one one-shot x3270
session, feeds a list of inputs, captures every screen, and asserts on the
captured text.

Usage:
    python3 test-dbwork.py [scenario ...]

Exit status is 1 if any scenario fails.
"""
import os
import subprocess
import sys
import time

HOST = "192.168.122.151:3270"
BBS = "3270BBS"
ADMIN = "~/3270BBS/basic/admin"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = "/tmp/opencode/dbwork_session.out"

SCENARIOS = {}

GLOBAL_BAD = ["?SYNTAX", "?UNDEFINED", "?ILLEGAL", "?STRING", "?REDO",
              "?DIVISION", "?OUT OF", "?NEXT WITHOUT", "?INPUT PAST END",
              "?EXECUTION",
              "?FILE NOT FOUND"]


def xstr(s):
    return 'String("%s")' % s.replace("\\", "\\\\").replace('"', '\\"')


def stage(name):
    path = os.path.join(HERE, name)
    if not os.path.exists(path):
        print("  (missing local %s; not staged)" % name, flush=True)
        return
    subprocess.run(["scp", "-q", path, "%s:%s/%s" % (BBS, ADMIN, name)], check=True)
    subprocess.run(["ssh", BBS, "chmod 664 %s/%s" % (ADMIN, name)], check=True)


def run_setup(cmds):
    for c in cmds:
        subprocess.run(["ssh", BBS, c], check=False)


def parse_screens(path):
    screens = []
    cur = []
    try:
        with open(path, "r", errors="replace") as f:
            for line in f:
                line = line.rstrip("\n")
                if line.startswith("data:"):
                    cur.append(line[5:].rstrip())
                elif cur:
                    screens.append("\n".join(cur))
                    cur = []
    except OSError:
        return []
    if cur:
        screens.append("\n".join(cur))
    return screens


def run_session(prog, inputs, must, must_not, final_must=None,
                final_must_not=None, pre=None, step_wait=3.0):
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    stage(prog + ".bas")
    if pre:
        stage(pre + ".bas")

    with open(OUT_PATH, "w") as out:
        p = subprocess.Popen(
            ["x3270", "-script", "-model", "3279-2", HOST],
            stdin=subprocess.PIPE, stdout=out, stderr=subprocess.STDOUT,
            text=True,
        )

        def send(action, delay=0.6):
            p.stdin.write(action + "\n")
            p.stdin.flush()
            time.sleep(delay)

        def ascii(delay=0.8):
            send("Ascii", delay)

        # logon and navigate to BASIC
        send("Wait(10,Output)", 1.5)
        send(xstr("admin"), 0.3)
        send("Tab", 0.3)
        send(xstr("admin"), 0.3)
        send("Enter", 4.0)
        send("PF(3)", 3.0)
        send(xstr("m"), 0.4)
        send("Enter", 3.0)
        send(xstr("b"), 0.4)
        send("Enter", 7.0)

        if pre:
            send(xstr('load "%s"' % pre), 0.5)
            send("Enter", 8.0)
            send(xstr("run"), 0.5)
            send("Enter", 2.0)
            time.sleep(25.0)
            ascii()

        send(xstr('load "%s"' % prog), 0.5)
        send("Enter", 8.0)
        send(xstr("run"), 0.5)
        send("Enter", 2.0)
        time.sleep(2.0)
        ascii()

        for item in inputs:
            if item is None:
                time.sleep(step_wait)
                continue
            if item != "":
                send(xstr(item), 0.3)
            send("Enter", step_wait)
            ascii()

        send("Ascii", 1.0)
        send("Quit", 0.5)
        try:
            p.wait(timeout=15)
        except subprocess.TimeoutExpired:
            p.kill()

    screens = parse_screens(OUT_PATH)
    text = "\n".join(screens)
    last = screens[-1] if screens else ""
    problems = []
    for want in must:
        if want not in text:
            problems.append("missing [%s]" % want)
    for bad in must_not:
        if bad in text:
            problems.append("found [%s]" % bad)
    for bad in GLOBAL_BAD:
        if bad in text:
            problems.append("interpreter error [%s]" % bad)
    for want in (final_must or []):
        if want not in last:
            problems.append("final missing [%s]" % want)
    for bad in (final_must_not or []):
        if bad in last:
            problems.append("final found [%s]" % bad)
    return problems


SCENARIOS["smoke"] = {
    "prog": "dbwork",
    "setup": [],
    "inputs": ["Q"],
    "must": ["MiniSQL Workbench", "N = new database", "Q = quit"],
    "must_not": ["?SYNTAX", "?UNDEFINED", "ERROR"],
}


SCENARIOS["open"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST1_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST1"],
    "must": ["DB: WBTEST1", "No tables yet", "N=new table"],
    "must_not": ["?SYNTAX", "?ILLEGAL", "?FILE NOT FOUND"],
}
SCENARIOS["openlong"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/ABCDEF*"],
    "inputs": ["N", "ABCDEFGHIJKLMNOPQRSTUVWX"],
    "must": ["DATABASE NAME TOO LONG"],
    "must_not": ["?ILLEGAL", "READY"],
}

SCENARIOS["recent"] = {
    "prog": "dbwork",
    "setup": [],
    "inputs": [],
    "must": ["WBTEST1"],
    "must_not": ["?SYNTAX"],
}

SCENARIOS["tables"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST2_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST2",
               "N", "customers", "id,name,email,city", "B",
               "N", "orders", "id,customer_id,date,status", "B",
               "N", "zzlinks", "",
               "N", "bad", "credit_limit,x", "",
               "N", "bad name", "a,b", ""],
    "must": ["customers", "id,name,email,city", "orders", "id,customer_id,date,status",
             "RESERVED", "BAD COLUMN NAME", "BAD TABLE NAME"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
    "final_must_not": ["zzlinks", "bad name"],
}

SCENARIOS["design"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST2_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST2", "N", "customers", "id,name,email,city",
               "A", "phone", "D", "5", "Y", "T", "x", "B",
               "N", "one", "a", "D", "1", "", "T", "one"],
    "must": ["Table: customers", "phone", "LAST COLUMN", "Dropped"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
    "final_must_not": ["one"],
}
SCENARIOS["dropcancel"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST2_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST2", "N", "customers", "id,name", "T", "x", "B"],
    "must": ["customers"],
    "must_not": ["?SYNTAX", "UNKNOWN SELECTION"],
    "final_must": ["DB: WBTEST2"],
}


def main():
    names = sys.argv[1:] or ["smoke"]
    failed = 0
    for name in names:
        sc = SCENARIOS.get(name)
        if sc is None:
            print("FAIL %s: no such scenario" % name)
            failed += 1
            continue
        run_setup(sc.get("setup", []))
        problems = run_session(
            sc["prog"], sc["inputs"], sc["must"], sc["must_not"],
            sc.get("final_must"), sc.get("final_must_not"),
            sc.get("pre"), sc.get("step_wait", 3.0),
        )
        if problems:
            print("FAIL %s: %s" % (name, "; ".join(problems)))
            failed += 1
        else:
            print("PASS %s" % name)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

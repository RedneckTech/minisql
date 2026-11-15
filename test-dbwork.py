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
               "N", "customers", "id,name,email,city", "Q",
               "N", "orders", "id,customer_id,date,status", "Q",
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
               "A", "phone", "D", "5", "Y", "T", "x", "Q",
               "N", "one", "a", "D", "1", "", "T", "one"],
    "must": ["Table: customers", "phone", "LAST COLUMN", "Dropped"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
    "final_must_not": ["one"],
}
SCENARIOS["dropcancel"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST2_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST2", "N", "customers", "id,name", "T", "x", "Q"],
    "must": ["customers"],
    "must_not": ["?SYNTAX", "UNKNOWN SELECTION"],
    "final_must": ["DB: WBTEST2"],
}

SCENARIOS["links"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST3_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST3", "N", "customers", "id,name", "Q",
               "N", "orders", "id,customer_id,date", "Q",
               "1", "L", "2", "2", "3", "Q",
               "1", "L", "2", "1", "2", "Q"],
    "must": ["customers.id -> orders.customer_id", "customers.id -> customers.id"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
}
SCENARIOS["linkdrop"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST3B_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST3B", "N", "customers", "id,name", "Q",
               "N", "orders", "id,customer_id,date", "Q",
               "1", "L", "2", "2", "3", "Q",
               "1", "D", "1", "Y", "Q", "1"],
    "must": ["1 link removed", "Links: (none)"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
}

SCENARIOS["insert"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST4_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST4", "N", "items", "label,val",
               "I", "", "alpha", "100",
               "I", "k2", "beta", "200",
               "I", "", "a,b", "300", "",
               "I", "", "a)b", "400", ""],
    "must": ["Inserted", "BAD VALUE", "Rows: 2"],
    "must_not": ["?SYNTAX", "?ILLEGAL", "?STRING"],
    "final_must": ["Rows: 2"],
}

SCENARIOS["browse"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST7_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "pre": "wbfill",
    "step_wait": 5.0,
    "inputs": ["N", "WBTEST7", "1", "B", "V", "1", "", "N", "N", "P"],
    "must": ["Page 1", "k01", "k15", "Page 2", "k16", "Page 3", "k31", "k40", "label1"],
    "must_not": ["?SYNTAX", "?ILLEGAL", "?STRING"],
}
SCENARIOS["browseempty"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST7B_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST7B", "N", "items", "label,val", "B"],
    "must": ["No rows"],
    "must_not": ["?SYNTAX"],
}

SCENARIOS["edit"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST7_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "pre": "wbfill",
    "step_wait": 5.0,
    "inputs": ["N", "WBTEST7", "1", "B", "E", "1", "alpha2", "",
               "E", "1", "", "@",
               "D", "1", "N", "D", "1", "Y"],
    "must": ["Updated", "Cleared", "Deleted"],
    "must_not": ["?SYNTAX", "?ILLEGAL", "?STRING"],
    "final_must_not": ["k01"],
}
SCENARIOS["delcancel"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST7_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "pre": "wbfill",
    "step_wait": 5.0,
    "inputs": ["N", "WBTEST7", "1", "B", "D", "1", "N"],
    "must": ["k01"],
    "must_not": ["?SYNTAX", "UNKNOWN SELECTION"],
    "final_must": ["k01"],
}

SCENARIOS["map"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST5_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST5", "N", "customers", "id,name", "Q",
               "N", "orders", "id,customer_id,date", "Q",
               "1", "L", "2", "2", "3", "Q", "M"],
    "must": ["Database map", "customers", "orders",
             "customers.id -> orders.customer_id", "Tables: 2", "Links: 1"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
    "final_must": ["Tables: 2", "Links: 1"],
}

SCENARIOS["sql"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST4_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "step_wait": 7.0,
    "inputs": ["N", "WBTEST4", "N", "items", "label,val",
               "I", "", "alpha", "100", "Q",
               "S",
               "SELECT COUNT(*) FROM items", "",
               "DESCRIBE items", "",
               "SHOW TABLES", "",
               "DROP TABLE zzlinks", "",
               "FOO", "",
               "B"],
    "must": ["COUNT=1", "COLS=label,val", "items", "zzlinks", "RESERVED", "UNSUPPORTED SQL"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
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

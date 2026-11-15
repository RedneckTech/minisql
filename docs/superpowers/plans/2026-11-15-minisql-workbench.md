# MiniSQL Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `dbwork.bas`, a screen-based MiniSQL database designer/viewer/editor, and a scripted test harness that proves it works on the live 3270BBS.

**Architecture:** A standalone label-mode BASIC program. It draws numbered screens with `CLS`/`BOXCHAR$`, keeps session state in globals, and chains into `minisql.bas` for every database operation. Link metadata lives in a reserved `zzlinks` table; recent databases live in `dbwork.dat`. A host-side Python harness drives one-shot x3270 sessions and asserts on screen text.

**Tech Stack:** TIMESHARING BASIC v3.0.1 on 3270BBS; x3270 `-script` for tests; Python 3 for the harness.

**Spec:** `docs/superpowers/specs/2026-11-15-minisql-workbench-design.md`

## Global Constraints

- Program filename `dbwork.bas`: 10 chars max, no `_`, label mode, `START:` required.
- Source lines ≤71 characters, ASCII only; screens 79 columns; single-line `BOXCHAR$(1-6)` only.
- No `EXIT WHILE`; never `GOTO` out of a `WHILE` (use a flag in the condition); `SLEEP` ≥0.1 in long loops.
- Values reject `,` `|` `)`; max 120 chars. Engine trims leading/trailing spaces.
- Names (tables/columns): letters/digits/`-`/`_`; reject `key`, `zzlinks`, `_schema_meta`, the substring `LIMIT`, and exact reserved words `INTO`, `VALUES`, `FROM`, `WHERE`, `SET`, `TABLE`, `ORDER`, `LIKE`, `AND`, `OR`, `DROP`, `SHOW`, `DESCRIBE`, `ALTER`, `PK`.
- Explicit keys: letters/digits/`.`/`-`/`_`; no spaces; reject `LIMIT` and `VALUES` substrings; non-empty.
- Database names: letters/digits/`-`/`_`; encoded length ≤20 (longest file `<db>_zzlinks.idx`).
- Limits: 50 tables, 40 columns per table, 30 links, 1800-char built statements, 15-row pages.
- Every engine call uses `CHAIN "minisql.bas"` with `COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$, SQL_STATUS, SQL_MSG$`; check `SQL_STATUS` after every call.
- Never leave a file handle open across a `CHAIN`. The engine uses #1-#4; the workbench uses #5+ only while not chaining.
- Reserved tables: `zzlinks`, `_schema_meta`.
- All BBS staging uses `scp` + `chmod 664` for test speed; the final delivery is uploaded with `uploader.py --verify` and passes `CHECK` with 0 errors.

## Review Focus

- A value containing `,`, `|`, or `)` must be rejected before the engine sees it (silent record corruption otherwise). Tested in Task 6.
- A column name containing `LIMIT` (e.g. `credit_limit`) must be rejected with a clear message. Tested in Task 3.
- A database name whose encoded form exceeds 20 characters must be refused before `INITDB` (otherwise `?ILLEGAL FILE NAME` kills the program). Tested in Task 2.
- Dropping the last user column must be refused (otherwise the table becomes unreachable). Tested in Task 4.
- A leftover `batch.dat` containing `BEGIN` must be rolled back on startup so writes persist instead of silently queuing. Tested in Task 12.

---

## File Structure

- Create `dbwork.bas` — the workbench. One file; sections separated by `REM =====` banners and labels.
- Create `test-dbwork.py` — host-side scripted test harness (login, load, feed inputs, assert screens).
- Create `wbfill.bas` — test fixture: creates `WBTEST7`/`items` with 40 rows for paging tests.
- Modify `README.md`, `user_manual.md` — add a short Workbench section.
- Do not modify `minisql.bas` unless a goal is blocked; propose first.

## Program Structure (locked in before tasks)

`START:` sets defaults, builds the 77-char horizontal line `WB_HL$`, reads the
registry, issues a startup `ROLLBACK`, then runs a dispatcher:

```
START:
    COMMON ...
    GOSUB WB_BOOT
    SCREEN = 1
    WHILE SCREEN <> 0
        IF SCREEN = 1 THEN GOSUB SCR_START
        IF SCREEN = 2 THEN GOSUB SCR_TABLES
        IF SCREEN = 3 THEN GOSUB SCR_DESIGN
        IF SCREEN = 4 THEN GOSUB SCR_BROWSE
        IF SCREEN = 5 THEN GOSUB SCR_VIEW
        IF SCREEN = 6 THEN GOSUB SCR_EDIT
        IF SCREEN = 7 THEN GOSUB SCR_INSERT
        IF SCREEN = 8 THEN GOSUB SCR_MAP
        IF SCREEN = 9 THEN GOSUB SCR_SQL
        IF SCREEN = 10 THEN GOSUB SCR_SEED
    WEND
    END
```

Each screen reads a command, sets `SCREEN`, and returns. `SCREEN=0` quits.

Shared globals: `SCREEN`, `DB$`, `TBL$`, `TCOLS$`, `TPK$`, `PAGE`, `LASTKEY$`,
`PAGESZ=15`, `TBNT`, `TBN$(50)`, `TBC$(50)`, `COLNT`, `COLN$(40)`,
`LNKT`, `LNKF$(30)`, `LNKFK$(30)`, `LNKTT$(30)`, `LNKTC$(30)`, `LNKKEY$(30)`,
`RESN`, `RESL$(60)`, `ROWKEYS$(15)`, `ROWLINES$(15)`, `ROWN`, `SELROW`,
`ANS$`, `PROMPT$`, `ERR$`, `YESNO`, `TEXT$`, `T2$`, `WB_HL$`.

### Screen kit interfaces (Task 1)

- `WB_BOOT`: defaults (`SQL_MODE$="RW"`), `WB_HL$`, registry read, `WB_CLRBATCH`.
- `WB_CLRBATCH`: truncate `batch.dat` directly (`OPEN "batch.dat" FOR OUTPUT AS #5: CLOSE #5`); this is the startup equivalent of ROLLBACK and works before a DB is selected.
- `WB_CLS`: `CLS`.
- `WB_TOP`: top border.
- `WB_SEP`: middle separator.
- `WB_BOT`: bottom border.
- `WB_PAD`: `TEXT$` → `T2$` padded/truncated to 77.
- `WB_LINE`: prints `│` + padded `TEXT$` + `│`.
- `WB_HEADER`: top, `TITLE$` line, separator (green title).
- `WB_FOOTER`: separator, `FOOT$` line, bottom.
- `WB_PROMPT`: prints `PROMPT$`, `INPUT ""`, `ANS$`.
- `WB_ERR`: prints `ERR$` in red, waits for Enter.
- `WB_PAUSE`: prints `Press ENTER...`, waits.
- `WB_YES`: prompts `PROMPT$ (Y/N)`, sets `YESNO` (1 only for `Y`/`y`).

### Engine wrapper interfaces (Task 2)

- `WB_CHAIN`: `CHAIN "minisql.bas"`.
- `WB_INIT`: `SQL_CMD$="INITDB"`, `GOSUB WB_CHAIN`.
- `WB_EXEC`: `SQL_CMD$="EXEC"`, `GOSUB WB_CHAIN`.
- `WB_ROLLBACK`: `SQL_CMD$="ROLLBACK"`, `GOSUB WB_CHAIN`.
- `WB_CHECK`: if `SQL_STATUS<>0` then `ERR$=SQL_MSG$: GOSUB WB_ERR`.

### Parser interfaces (Task 3)

- `WB_GETTOK`: IN `S$`, `D$`, `N`; OUT `GETD$` (copy the minisql pattern).
- `WB_SPLIT`: IN `SQL_RESULT$`; OUT `RESN`, `RESL$()`.
- `WB_PARSEROW`: IN `ROWL$`; OUT `RFN`, `RN$()`, `RV$()`, `RKN$`, `RKV$`.
- `WB_PARSEDESC`: IN `SQL_RESULT$`; OUT `DTBL$`, `DCOLS$`, `DPK$`.
- `WB_PARSECOUNT`: IN `SQL_RESULT$`; OUT `CNT`.

---

### Task 1: Skeleton, screen kit, start screen, quit

**Files:**
- Create: `dbwork.bas`
- Create: `test-dbwork.py`

**Interfaces:**
- Produces: `START:`, `WB_BOOT`, `WB_CLS`, `WB_TOP`, `WB_SEP`, `WB_BOT`, `WB_PAD`, `WB_LINE`, `WB_HEADER`, `WB_FOOTER`, `WB_PROMPT`, `WB_ERR`, `WB_PAUSE`, `WB_YES`, `SCR_START`, `SCREEN`, `TITLE$`, `FOOT$`, `WB_HL$`.
- Consumes: nothing.

- [ ] **Step 1: Write the failing harness scenario**

Create `test-dbwork.py` with a `run_session(prog, inputs, must, must_not, final_must=[], final_must_not=[], pre=None)` helper (one-shot x3270: login `admin`/`admin`, `PF(3)`, `M`, `B`, optionally load/run the `pre` fixture first, then `load "<prog>"`, `run`, feed inputs, capture all `Ascii` screens). `must`/`must_not` check all screens; `final_must`/`final_must_not` check only the last screen. Also use the patterns in `~/ai/references/timesharing-basic/UI_PANELS.md` for the screen kit. A `smoke` scenario:

```python
SCENARIOS["smoke"] = {
    "prog": "dbwork",
    "setup": [],
    "inputs": ["Q"],
    "must": ["MiniSQL Workbench", "N = new database", "Q = quit"],
    "must_not": ["?SYNTAX", "?UNDEFINED", "ERROR"],
}
```

The harness stages `dbwork.bas` with `scp` + `chmod 664` before the session.

- [ ] **Step 2: Run the scenario to verify it fails**

Run: `python3 test-dbwork.py smoke`
Expected: `FAIL smoke: missing MiniSQL Workbench` (or `?FILE NOT FOUND` on screen).

- [ ] **Step 3: Implement the skeleton**

`dbwork.bas` label mode with `START:`, the dispatcher, `WB_BOOT` building `WB_HL$` as 77 `BOXCHAR$(5)` characters in a loop, the screen kit, and `SCR_START` showing the title, an empty "Recent databases" list, and the commands `N = new database`, `S = sample SHOP database`, `Q = quit`. `Q` sets `SCREEN=0`. Use `WB_HEADER`/`WB_FOOTER`; do not use `TAB` after box characters.

- [ ] **Step 4: Run the scenario to verify it passes**

Run: `python3 test-dbwork.py smoke`
Expected: `PASS smoke`.

- [ ] **Step 5: Commit**

Commit via the git subagent with the approved subject `Add dbwork.bas workbench skeleton` (or the project's approved-verb equivalent). Stage `dbwork.bas` and `test-dbwork.py` only.

---

### Task 2: Open/create database, registry, INITDB, zzlinks, empty table list

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`

**Interfaces:**
- Produces: `WB_READREG`, `WB_WRITEREG`, `WB_OPENDB`, `WB_INIT`, `WB_EXEC`, `WB_CHAIN`, `WB_ROLLBACK`, `WB_CLRBATCH`, `WB_CHECK`, `DB$`, `DBPFX$`, `SCR_TABLES` (placeholder).
- Consumes: screen kit from Task 1.

- [ ] **Step 1: Write the failing scenarios**

Add `open` and `openlong`:

```python
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
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python3 test-dbwork.py open openlong`
Expected: both FAIL (no DB header / no error message).

- [ ] **Step 3: Implement DB open and registry**

- `WB_READREG`: ensure `dbwork.dat` exists with `OPEN ... FOR APPEND: CLOSE`, then read lines into `REG$(10)`, `REGN`; skip blanks; dedupe.
- `WB_WRITEREG`: rewrite `dbwork.dat` FOR OUTPUT, most recent first, max 10.
- `WB_OPENDB`: uppercase `DB$`; validate characters and encoded length ≤20 (replicate the engine's encoding: `-`→`_`, `_`→`__`); on failure set `ERR$` and return to start. On success set `SQL_DB$=DB$` and `SQL_MODE$="RW"`, then `WB_INIT`; if `SQL_STATUS<>0` show `SQL_MSG$`; `SQL_STMT$="CREATE TABLE zzlinks (ftbl,fcol,ttbl,tcol) PK KEY"`, `WB_EXEC`, ignore status 33; move `DB$` to the top of `REG$`; `WB_WRITEREG`; `SCREEN=2`.
- `SCR_TABLES` placeholder: header `DB: <DB$>`, `No tables yet`, commands `N=new table`, `M=map`, `S=SQL`, `Q=quit`; `Q` sets `SCREEN=0`.

- [ ] **Step 4: Run the scenarios to verify they pass**

Add `recent`:

```python
SCENARIOS["recent"] = {
    "prog": "dbwork",
    "setup": [],
    "inputs": [],
    "must": ["WBTEST1"],
    "must_not": ["?SYNTAX"],
}
```

Run: `python3 test-dbwork.py open openlong recent`
Expected: all PASS (the recent list survives a new session).

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with database open and registry`.

---

### Task 3: Parsers, table list, create table, name validation

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`

**Interfaces:**
- Produces: `WB_GETTOK`, `WB_SPLIT`, `WB_PARSEDESC`, `WB_PARSECOUNT`, `WB_LOADTABLES`, `WB_LOADCOLS`, `WB_VALNAME`, `SCR_NEWTABLE`, `TBNT`, `TBN$()`, `TBC$()`, `COLNT`, `COLN$()`.
- Consumes: `WB_EXEC`, `WB_CHECK`, screen kit.

- [ ] **Step 1: Write the failing scenario**

```python
SCENARIOS["tables"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST2_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST2",
               "N", "customers", "id,name,email,city", "B",
               "N", "orders", "id,customer_id,date,status", "B",
               "N", "zzlinks", "x",
               "N", "bad", "credit_limit,x",
               "N", "bad name", "a,b"],
    "must": ["customers", "id,name,email,city", "orders", "id,customer_id,date,status",
             "RESERVED", "BAD COLUMN NAME", "BAD TABLE NAME"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
    "final_must_not": ["zzlinks", "bad name"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py tables`
Expected: FAIL (no table list/create flow).

- [ ] **Step 3: Implement parsers and the table list**

- `WB_GETTOK` as in `minisql.bas`; `WB_SPLIT` splits `SQL_RESULT$` on `CHR$(10)` into `RESL$()`.
- `WB_PARSEDESC`: split `SQL_RESULT$` into three lines; `DTBL$` after `TBL=`, `DCOLS$` after `COLS=`, `DPK$` after `PK=`.
- `WB_PARSECOUNT`: `CNT=VAL(MID$(SQL_RESULT$,7))`.
- `WB_LOADTABLES`: `SHOW TABLES`; for each non-empty line except `zzlinks` (case-insensitive), store `TBN$(n)`, then `DESCRIBE <name>` and store `DCOLS$` in `TBC$(n)`; cap 50; set `TBNT`.
- `WB_LOADCOLS`: split `TBC$` by comma into `COLN$()`, `COLNT`, cap 40.
- `WB_VALNAME`: empty/char/reserved rules from Global Constraints; set `VBAD`.
- `SCR_TABLES`: `WB_LOADTABLES`; print numbered tables with columns and `key`; commands number/N/M/S/R/Q. `N` prompts name and comma columns, validates each with `WB_VALNAME` (reject `zzlinks`, `_schema_meta`, `LIMIT` substring, reserved exact words), builds `CREATE TABLE <name> (<cols>) PK KEY`, `WB_EXEC`, on success refresh and open design (`TBL$=<name>`, `SCREEN=3`).
- Add a placeholder `SCR_DESIGN` that shows `Table: <TBL$>` and columns, and `B` returns to tables. Task 4 fills it.

- [ ] **Step 4: Run the scenario to verify it passes**

Run: `python3 test-dbwork.py tables`
Expected: PASS. The `zzlinks` attempt shows `RESERVED`; `credit_limit` shows `BAD COLUMN NAME`; the spaced table name shows `BAD TABLE NAME`.

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with table list and create table`.

---

### Task 4: Table design, add/drop column, drop table, last-column guard

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`

**Interfaces:**
- Produces: `SCR_DESIGN`, `WB_LOADCOLS` use, `WB_DROPCOL`, `WB_DROPTABLE`, `WB_COUNTROWS`, `TCOLS$`.
- Consumes: `TBL$`, `TBC$`, `COLN$()`, `COLNT`, `WB_EXEC`.

- [ ] **Step 1: Write the failing scenario**

```python
SCENARIOS["design"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST2_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST2", "N", "customers", "id,name,email,city",
               "A", "phone", "D", "5", "T", "x", "B",
               "N", "one", "a", "D", "1", "T", "one"],
    "must": ["Table: customers", "phone", "LAST COLUMN", "Dropped"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
    "final_must_not": ["one"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py design`
Expected: FAIL (design screen is a placeholder; no add/drop).

- [ ] **Step 3: Implement the design screen**

- Header: `Table: <TBL$>`, `KEY` line, row count via `SELECT COUNT(*) FROM <TBL$>`, links touching the table (loaded in Task 5; until then print `Links: (none)`).
- Numbered columns from `TBC$`; `KEY` is shown first but is not numbered, so user
  columns are 1..COLNT (the link picker numbers `KEY` as 1, columns 2..).
- `A`: prompt name, `WB_VALNAME`, `ALTER TABLE <TBL$> ADD <col>`, refresh.
- `D n`: map `n` to `COLN$(n)`; if `COLNT=1` refuse with `LAST COLUMN`; confirm; `ALTER TABLE <TBL$> DROP <col>`; refresh.
- `T`: confirm by typing the table name; `DROP TABLE <TBL$>`; `SCREEN=2`.
- `B`/`Q`: back to tables. `I`/`E`/`D`/`V` row commands are placeholders until later tasks.

- [ ] **Step 4: Run the scenario to verify it passes**

Add `dropcancel`:

```python
SCENARIOS["dropcancel"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST2_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST2", "N", "customers", "id,name", "T", "x", "B"],
    "must": ["customers"],
    "must_not": ["?SYNTAX"],
}
```

Run: `python3 test-dbwork.py design dropcancel`
Expected: both PASS.

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with table design and column editing`.

---

### Task 5: Links (load, add, delete, self-links, cleanup)

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`

**Interfaces:**
- Produces: `WB_LOADLINKS`, `WB_SAVELINK`, `WB_DELLINK`, `WB_LINKSFOR`, `WB_CLEANLINKS`, `LNKT`, `LNKF$()`, `LNKFK$()`, `LNKTT$()`, `LNKTC$()`, `LNKKEY$()`.
- Consumes: `TBN$()`, `TBC$()`, `COLN$()`, `WB_EXEC`.

- [ ] **Step 1: Write the failing scenario**

```python
SCENARIOS["links"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST3_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST3", "N", "customers", "id,name", "B",
               "N", "orders", "id,customer_id,date", "B",
               "1", "L", "2", "2", "3", "B",
               "1", "L", "2", "1", "2", "B"],
    "must": ["customers.id -> orders.customer_id", "customers.id -> customers.id"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py links`
Expected: FAIL (no link commands).

- [ ] **Step 3: Implement links**

- `WB_LOADLINKS`: `SELECT * FROM zzlinks`; parse rows into the five arrays; cap 30; missing table → `LNKT=0`.
- `SCR_DESIGN`: show outgoing (`ftbl.fcol -> ttbl.tcol`) and incoming (`<-`) links; number them for `X n`.
- `L`: numbered from-columns (`KEY` + columns), numbered target tables (all except `zzlinks`, including self), numbered target columns (`KEY` + columns); validate; `INSERT INTO zzlinks VALUES (f,fk,t,tc)`; refresh.
- `X n`: `DELETE FROM zzlinks KEY <LNKKEY$(n)>`; refresh.
- `WB_CLEANLINKS`: IN `TBL$` and optional column; scan `zzlinks` in pages of 30, delete matching rows, return `CLNDEL`; call from drop-column and drop-table after confirmation and report the count.

- [ ] **Step 4: Run the scenario to verify it passes**

Add `linkdrop` and run both:

```python
SCENARIOS["linkdrop"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST3B_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST3B", "N", "customers", "id,name", "B",
               "N", "orders", "id,customer_id,date", "B",
               "1", "L", "2", "2", "3", "B",
               "1", "D", "1", "Y", "B", "1"],
    "must": ["1 link removed", "Links: (none)"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
}
```

Run: `python3 test-dbwork.py links linkdrop`
Expected: both PASS.

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with table links`.

---

### Task 6: Row insert and value/key validation

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`

**Interfaces:**
- Produces: `SCR_INSERT`, `WB_VALVAL`, `WB_VALKEY`, `WB_INSERTROW`, `ROWKEYS$()`.
- Consumes: `COLN$()`, `COLNT`, `TBL$`, `WB_EXEC`.

- [ ] **Step 1: Write the failing scenario**

```python
SCENARIOS["insert"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST4_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST4", "N", "items", "label,val",
               "I", "", "alpha", "100",
               "I", "k2", "beta", "200",
               "I", "", "a,b", "300",
               "I", "", "a)b", "400"],
    "must": ["Inserted", "BAD VALUE", "Rows: 2"],
    "must_not": ["?SYNTAX", "?ILLEGAL", "?STRING"],
    "final_must": ["Rows: 2"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py insert`
Expected: FAIL (no insert flow).

- [ ] **Step 3: Implement insert**

- `WB_VALVAL`: empty allowed; length ≤120; reject `,` `|` `)`.
- `WB_VALKEY`: non-empty for explicit keys; chars `[A-Za-z0-9._-]`; reject `LIMIT`/`VALUES` substrings.
- `SCR_INSERT`: prompt `Key (blank = auto): `; if blank build `INSERT INTO <t> VALUES (v1,...)`, else validate key and build `INSERT INTO <t> KEY <k> VALUES (...)`; on `SQL_STATUS=0` print `Inserted`; on 47 print `DUPLICATE KEY`; refresh count.
- `WB_INSERTROW` builds the statement in a string; reject if `LEN(SQL_STMT$)>1800`.

- [ ] **Step 4: Run the scenario to verify it passes**

Run: `python3 test-dbwork.py insert`
Expected: PASS. Verify with a direct engine call that `items` has 2 rows (the rejected ones did not insert).

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with row insert and validation`.

---

### Task 7: Row browser, view, paging (fixture)

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`
- Create: `wbfill.bas`

**Interfaces:**
- Produces: `SCR_BROWSE`, `WB_LOADPAGE`, `WB_VIEWROW`, `PAGE`, `LASTKEY$`, `PAGEKEYS$(20)`, `ROWKEYS$()`, `ROWLINES$()`, `ROWN`, `PAGESZ=15`.
- Consumes: `TBL$`, `WB_EXEC`, `WB_PARSEROW`.

- [ ] **Step 1: Create the fixture and failing scenario**

The harness stages `wbfill.bas`; when a scenario sets `"pre": "wbfill"`, it loads/runs the fixture first, waits for `FILL DONE`, then loads/runs `dbwork`.

`wbfill.bas` (label mode, no `_` in name): DB `WBTEST7`, `INITDB`, `CREATE TABLE items (label,val) PK KEY`, then `FOR I=1 TO 40`: `SQL_STMT$="INSERT INTO items KEY k"+RIGHT$("0"+TRIM$(STR$(I)),2)+" VALUES (label"+TRIM$(STR$(I))+","+TRIM$(STR$(I))+")"`, `CHAIN "minisql.bas"`, `SLEEP(0.1)` every 10; print `FILL DONE`.

```python
SCENARIOS["browse"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST7_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat",
              "stage wbfill.bas"],
    "pre": "wbfill",
    "inputs": ["N", "WBTEST7", "1", "B", "V", "1", "N", "N", "P"],
    "must": ["Page 1", "k01", "k15", "Page 2", "k16", "Page 3", "k31", "k40", "label1"],
    "must_not": ["?SYNTAX", "?ILLEGAL", "?STRING"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py browse`
Expected: FAIL (no browser).

- [ ] **Step 3: Implement the browser**

- `SCR_BROWSE`: `PAGE=1`, `LASTKEY$=""`; `WB_LOADPAGE`: page 1 `SELECT * FROM <t> LIMIT 15`; later `SELECT * FROM <t> WHERE key><LASTKEY$> LIMIT 15`; split rows; store `ROWKEYS$(n)` and a formatted `ROWLINES$(n)` truncated to 77 with `..`; `ROWN` count; set `LASTKEY$` to the last key.
- Display `Page <PAGE>` and numbered rows; commands `N`/`P` page (set `PAGE`, keep/derive `LASTKEY$`), `V n` view, `E n`/`D n` placeholders, `I` insert, `B` back, `R` refresh.
- `SCR_VIEW`: fetch by key (`SELECT * WHERE KEY=<k>`), parse row, print `col=value` one per line, page if >18 lines, Enter returns.

- [ ] **Step 4: Run the scenario to verify it passes**

Add `browseempty`:

```python
SCENARIOS["browseempty"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST7B_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST7B", "N", "items", "label,val", "B"],
    "must": ["No rows"],
    "must_not": ["?SYNTAX"],
}
```

Run: `python3 test-dbwork.py browse browseempty`
Expected: PASS; `k01`/`k15` on page 1, `k16` on page 2, `k31`/`k40` on page 3, no duplicates; the empty table shows `No rows`.

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with row browser and paging`.

---

### Task 8: Row edit, delete, `@` clear

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`

**Interfaces:**
- Produces: `SCR_EDIT`, `SCR_DELETE`, `WB_UPDATEROW`, `WB_DELETEROW`.
- Consumes: `ROWKEYS$()`, `COLN$()`, `WB_PARSEROW`, `WB_EXEC`.

- [ ] **Step 1: Write the failing scenario**

```python
SCENARIOS["edit"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST7_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat",
              "stage wbfill.bas"],
    "pre": "wbfill",
    "inputs": ["N", "WBTEST7", "1", "B", "E", "1", "alpha2", "",
               "E", "1", "", "@",
               "D", "1", "N", "D", "1", "Y"],
    "must": ["Updated", "Cleared", "Deleted"],
    "must_not": ["?SYNTAX", "?ILLEGAL", "?STRING"],
    "final_must_not": ["k01"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py edit`
Expected: FAIL (E/D are placeholders).

- [ ] **Step 3: Implement edit/delete**

- `SCR_EDIT`: fetch the row by key; print the key read-only; for each column prompt `col [current]: `; empty keeps; `@` clears; `@@` stores a literal `@`; validate with `WB_VALVAL`; build `REPLACE <t> KEY <k> VALUES (v1,...)`; reject if >1800; `WB_EXEC`; print `Updated`; refresh.
- `SCR_DELETE`: confirm `Delete row n? (Y/N)`; `DELETE FROM <t> KEY <k>`; print `Deleted`; refresh.
- Add the browser commands `E n`/`D n` dispatching to these screens.

- [ ] **Step 4: Run the scenario to verify it passes**

Add `delcancel`:

```python
SCENARIOS["delcancel"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST7_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat",
              "stage wbfill.bas"],
    "pre": "wbfill",
    "inputs": ["N", "WBTEST7", "1", "B", "D", "1", "N"],
    "must": ["k01"],
    "must_not": ["?SYNTAX"],
}
```

Run: `python3 test-dbwork.py edit delcancel`
Expected: both PASS. Verify via the engine that the first row's label is `alpha2`, its value is empty, and the row is gone after the confirmed delete; the canceled delete leaves `k01` present.

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with row edit and delete`.

---

### Task 9: Map screen

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`

**Interfaces:**
- Produces: `SCR_MAP`, `WB_MAPLINES`, `MAPN`, `MAPL$(60)`.
- Consumes: `TBN$()`, `TBC$()`, `LNKF$()`...`LNKTC$()`.

- [ ] **Step 1: Write the failing scenario**

```python
SCENARIOS["map"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST5_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST5", "N", "customers", "id,name", "B",
               "N", "orders", "id,customer_id,date", "B",
               "1", "L", "2", "2", "3", "B", "M"],
    "must": ["Database map", "customers", "orders",
             "customers.id -> orders.customer_id", "Tables: 2", "Links: 1"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
    "final_must": ["Tables: 2", "Links: 1"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py map`
Expected: FAIL (no map).

- [ ] **Step 3: Implement the map**

`SCR_MAP`: build `MAPL$()` with a title, each table as `name: cols`, then `Links:` and each link; count tables/links; page 20 lines at a time with Enter; commands `B`/`R`. Flag dangling links (target table/column not in the cache) with `!` and a note.

- [ ] **Step 4: Run the scenario to verify it passes**

Run: `python3 test-dbwork.py map`
Expected: PASS.

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with database map`.

---

### Task 10: SQL console

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`

**Interfaces:**
- Produces: `SCR_SQL`, `WB_SHOWRESULT`, `WB_SHOWDESC`.
- Consumes: `WB_EXEC`, parsers.

- [ ] **Step 1: Write the failing scenario**

```python
SCENARIOS["sql"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST4_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST4", "N", "items", "label,val",
               "I", "", "alpha", "100", "B",
               "S", "SELECT COUNT(*) FROM items",
               "DESCRIBE items", "SHOW TABLES", "DROP TABLE zzlinks", "FOO", "B"],
    "must": ["COUNT=1", "COLS=label,val", "items", "zzlinks", "RESERVED", "UNSUPPORTED SQL"],
    "must_not": ["?SYNTAX", "?ILLEGAL"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py sql`
Expected: FAIL (no console).

- [ ] **Step 3: Implement the console**

`SCR_SQL`: prompt `SQL> `; empty/`B` returns; refuse statements whose uppercased text contains `ZZLINKS` or `_SCHEMA_META` (print `RESERVED`); `WB_EXEC`; print status/msg; `COUNT=` → one line; `TBL=` → `WB_SHOWDESC`; rows → one line each truncated to 77, page every 20 lines; errors red; loop.

- [ ] **Step 4: Run the scenario to verify it passes**

Run: `python3 test-dbwork.py sql`
Expected: PASS.

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with SQL console`.

---

### Task 11: Sample SHOP seed

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`

**Interfaces:**
- Produces: `SCR_SEED`, `WB_SEEDTABLE`, `WB_SEEDLINK`, `WB_SEEDROW`.
- Consumes: `WB_EXEC`, `WB_VALNAME`, `WB_LOADTABLES`.

- [ ] **Step 1: Write the failing scenario**

```python
SCENARIOS["seed"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/SHOP_* ~/3270BBS/basic/admin/dbwork.dat ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["S", "M"],
    "must": ["SHOP", "customers", "products", "orders", "order_lines",
             "suppliers", "shipments", "Tables: 6", "Links: 5"],
    "must_not": ["?SYNTAX", "?ILLEGAL", "?STRING"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py seed`
Expected: FAIL (no seed).

- [ ] **Step 3: Implement the seed**

`SCR_SEED`: set `DB$="SHOP"`; if `dbwork.dat`/SHOP exists, prompt `SHOP exists - merge sample? (Y/N)`; create missing tables with the exact schemas in §13 of the spec; add missing links (check `zzlinks` first); insert sample rows only into empty tables; report counts; `SCREEN=2`.
Exact sample values: customers `c01 Alice`, `c02 Bob`; suppliers `s01 Acme`, `s02 Globex`; products `p01 Widget 10 100 s01`, `p02 Gadget 20 50 s02`; orders `o01 c01 2026-01-10 open`, `o02 c02 2026-01-11 shipped`; order_lines `l01 o01 p01 2 10`, `l02 o01 p02 1 20`; shipments `h01 o02 UPS 2026-01-12`.

- [ ] **Step 4: Run the scenario to verify it passes**

Run: `python3 test-dbwork.py seed`
Expected: PASS. Add a `seedmerge` scenario with `"inputs": ["S", "Y", "M", "B", "1"]` and `"must": ["Tables: 6", "Links: 5", "Rows: 2"]`; run it after `seed`. Expected: PASS with the same counts (no duplicate rows or links).

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with sample SHOP seed`.

---

### Task 12: Startup batch rollback, limits, docs, full regression

**Files:**
- Modify: `dbwork.bas`, `test-dbwork.py`, `README.md`, `user_manual.md`

**Interfaces:**
- Produces: startup `WB_CLRBATCH`, `QUEUED` detection, final limits/help text.
- Consumes: everything.

- [ ] **Step 1: Write the failing regression scenario**

```python
SCENARIOS["batch"] = {
    "prog": "dbwork",
    "setup": ["rm -f ~/3270BBS/basic/admin/WBTEST6_* ~/3270BBS/basic/admin/dbwork.dat",
              "printf 'BEGIN\\n' > ~/3270BBS/basic/admin/batch.dat"],
    "inputs": ["N", "WBTEST6", "N", "items", "label,val",
               "1", "I", "", "alpha", "100"],
    "must": ["Inserted"],
    "must_not": ["QUEUED", "?SYNTAX", "?ILLEGAL"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 test-dbwork.py batch`
Expected: FAIL (the insert is queued; no `Inserted`).

- [ ] **Step 3: Implement startup rollback and QUEUED detection**

- `WB_BOOT` calls `WB_CLRBATCH` before the first screen (truncates `batch.dat`).
- After every `WB_EXEC`, if `INSTR(UCASE$(SQL_MSG$), "QUEUED")>0` then print `TXN QUEUE ERROR`, `WB_ROLLBACK`, and set `SQL_STATUS=1`.
- Add the final limits/help text to the screens (50/40/30/120/1800/15) and a `?` help line on the start screen.
- Update `README.md` and `user_manual.md` with a `dbwork` section: run instructions, screens, safe-token limits, links, sample seed.

- [ ] **Step 4: Run the full regression**

Run: `python3 test-dbwork.py smoke open openlong recent tables design dropcancel links linkdrop insert browse browseempty edit delcancel map sql seed seedmerge batch`
Expected: all PASS.
Add a `regression` mode to `test-dbwork.py` that loads/runs `test-runner` and asserts `PASS: 14` / `FAIL: 0`, and a `check` mode that loads `dbwork`, runs `check`, and asserts the screen does not contain `ERROR(S) FOUND` and the generated `dbwork.list` contains `TOTAL ERRORS: 0`. Run `python3 test-dbwork.py regression check`. Expected: PASS.
Run `CHECK` on `dbwork.bas` on the BBS: expected `0 ERRORS`.
Upload the final file with `python3 ~/ai/scripts/bbs/uploader.py dbwork.bas --verify`.

- [ ] **Step 5: Commit**

Commit via the git subagent: `Update dbwork.bas with final polish and docs`. Stage `dbwork.bas`, `test-dbwork.py`, `wbfill.bas`, `README.md`, `user_manual.md`.

---

## Self-Review

- Spec coverage: start/registry (Tasks 1-2), table list/create (3), design/columns/drop (4), links/self-links/cleanup (5), insert (6), browser/paging/view (7), edit/delete/`@` (8), map (9), SQL console (10), sample seed (11), batch/limits/docs/regression (12). All spec goals and non-goals are represented.
- Type consistency: `WB_LOADTABLES` fills `TBN$()/TBC$()`; later tasks consume those names. `ROWKEYS$()` is produced by Task 7 and consumed by Task 8. `LNKKEY$()` is produced by Task 5 and consumed by link deletion. `WB_VALNAME` is used by Tasks 3-5; `WB_VALVAL` by 6-8.
- Review Focus tests: value characters (Task 6), `LIMIT` column (Task 3), DB name length (Task 2), last column (Task 4), leftover batch (Task 12).
- Proportion: the plan gives labels, interfaces, SQL strings, and test assertions; it does not transcribe the BASIC bodies.

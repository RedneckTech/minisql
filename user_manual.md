# MiniSQL User Manual (minisql.bas)

MiniSQL is a tiny SQL-ish database engine designed for
TIMESHARING BASIC / 3270BBS-style BASIC.

It is used like a **library**: your program sets `COMMON` variables and
`CHAIN`s into `minisql.bas` for one operation. MiniSQL returns to your
program when it finishes.

This manual explains how to integrate MiniSQL, how storage works, and
how to use every command (including COMPACT and REINDEX).

---

## Table of Contents

- What MiniSQL Is
- Limits and Design Goals
- Files MiniSQL Creates
- Storage Model
- Calling Convention (COMMON + CHAIN)
- Code Template (recommended)
- Commands (with code examples)
  - INITDB
  - EXEC
  - SEARCH
  - BEGIN / COMMIT / ROLLBACK
  - COMPACT
  - REINDEX
- SQL-ish Statement Reference (with examples)
  - CREATE TABLE
  - INSERT
  - SELECT (+ WHERE + LIMIT)
  - UPDATE
  - REPLACE
  - DELETE
- Modes (RW / RO / AO)
- Results and Output Format (+ printing helpers)
- Error Codes
- Maintenance & Best Practices
- Troubleshooting
- Compatibility Notes

---

## What MiniSQL Is

MiniSQL provides:

- simple tables (schema stored in an index file)
- insert/select/update/replace/delete
- a basic index on a primary “KEY”
- file rollover when data files hit 10KB
- transactions (queue statements, commit later)
- maintenance commands (COMPACT / REINDEX)

MiniSQL is not full SQL. It is intentionally small and file-based.

---

## Limits and Design Goals

MiniSQL exists to live within platform limits:

- Terminal width: 71 columns (keep BASIC source lines short)
- Data file size: each `.dat` file max 10KB
- Open file handles: max 4 at one time
- Watchdog safety: long loops call `SLEEP(0.25)` periodically

---

## Files MiniSQL Creates

Assuming `SQL_DB$ = "TESTDB"`, MiniSQL will create:

- `TESTDB-idx.dat`  (index + schemas + metadata)
- `TESTDB-db1.dat`  (data rows)
- `TESTDB-db2.dat`, `TESTDB-db3.dat`, ... (more data files)
- `TESTDB-txn.dat`  (transaction queue)

### Filename rules

The system does not allow `_` in filenames.
MiniSQL uses `-` and converts `_` to `-` in your DB prefix.

---

## Storage Model (Important)

MiniSQL uses an **append-only** storage model.

### Data records (in dbN.dat)

Each row is one line:

`R|table|key|col=value|col=value|...`

Example:

`R|people|alice|name=Alice|age=25|city=Chicago`

### Index records (in idx.dat)

Index lines point a `(table,key)` to its newest record:

`I|table|key|file|rec`

- `file` is db file number (1,2,3...)
- `rec` is the line number inside db file (1-based)

Deletes are tombstones:

`I|table|key|0|0`

### Updates and replaces

UPDATE and REPLACE do not modify in place. They:

1. append a new `R|...` record line
2. append a new `I|...` line pointing to the new record

### SELECT returns latest versions

SELECT scans the data files but only returns records that match the
current index pointer for each key.

---

## Calling Convention (COMMON + CHAIN)

MiniSQL is controlled using `COMMON` variables.

Your program and `minisql.bas` must declare the same `COMMON` variables
in the same order:

```basic
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$
```

### Inputs

* `SQL_CMD$`:
  `INITDB`, `EXEC`, `SEARCH`, `BEGIN`, `COMMIT`, `ROLLBACK`,
  `COMPACT`, `REINDEX`
* `SQL_DB$`: database prefix (example: `TESTDB`)
* `SQL_MODE$`: `RW`, `RO`, `AO`
* `SQL_STMT$`: statement (EXEC) or spec (SEARCH)

### Outputs

* `SQL_STATUS`: `0` success, nonzero error
* `SQL_MSG$`: short status message
* `SQL_RESULT$`: results text for SELECT/SEARCH (lines split by LF)

---

## Code Template (recommended)

Use this caller template in your programs. It keeps BASIC lines short.

```basic
REM ----- Put this near the top of your program -----
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTDB"
SQL_MODE$ = "RW"

REM ----- Helper: call minisql and print status/result -----
CALL_SQL:
  SQL_STATUS = 0
  SQL_MSG$ = ""
  SQL_RESULT$ = ""
  CHAIN "minisql"
  PRINT "STATUS:"; SQL_STATUS
  PRINT "MSG   :"; SQL_MSG$
  IF SQL_RESULT$<>"" THEN GOSUB PRINT_RES
  RETURN

PRINT_RES:
  S$ = SQL_RESULT$
  P = 1
PR1:
  N = INSTR(MID$(S$, P), CHR$(10))
  IF N=0 THEN
    L$ = MID$(S$, P)
    IF TRIM$(L$)<>"" THEN PRINT L$
    RETURN
  END IF
  L$ = MID$(S$, P, N-1)
  IF TRIM$(L$)<>"" THEN PRINT L$
  P = P + N
  GOTO PR1
```

---

## Commands (with code examples)

### INITDB

Creates the files if missing and seeds basic metadata.

**Example**

```basic
SQL_CMD$ = "INITDB"
SQL_STMT$ = ""
GOSUB CALL_SQL
```

Expected `SQL_MSG$` examples:

* `INITDB OK (CREATED)`
* `INITDB OK (EXISTS)`

---

### EXEC

Executes one SQL-ish statement in `SQL_STMT$`.

**Example: CREATE TABLE**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "CREATE TABLE people (name,age,city) PK KEY"
GOSUB CALL_SQL
```

**Example: INSERT**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO people KEY alice VALUES (Alice,25,Chicago)"
GOSUB CALL_SQL
```

**Example: SELECT**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT * FROM people WHERE city=Chicago LIMIT 10"
GOSUB CALL_SQL
```

---

### SEARCH

Scan-style search. Set `SQL_STMT$` as:

`table|term|col(optional)`

**Example: search any field**

```basic
SQL_CMD$ = "SEARCH"
SQL_STMT$ = "people|denver|"
GOSUB CALL_SQL
```

**Example: search only a column**

```basic
SQL_CMD$ = "SEARCH"
SQL_STMT$ = "people|denver|city"
GOSUB CALL_SQL
```

---

### BEGIN / COMMIT / ROLLBACK (Transaction batching)

Transactions queue write statements in `DBNAME-txn.dat`.

#### BEGIN

```basic
SQL_CMD$ = "BEGIN"
SQL_STMT$ = ""
GOSUB CALL_SQL
```

#### Queue writes (EXEC during txn)

During an active txn, `EXEC` statements (except SELECT) are queued.

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO people KEY bob VALUES (Bob,30,Boston)"
GOSUB CALL_SQL
```

#### COMMIT

```basic
SQL_CMD$ = "COMMIT"
SQL_STMT$ = ""
GOSUB CALL_SQL
```

#### ROLLBACK

```basic
SQL_CMD$ = "ROLLBACK"
SQL_STMT$ = ""
GOSUB CALL_SQL
```

---

### COMPACT

Rewrites `DBNAME-idx.dat` to remove old duplicates.
Keeps only the latest schema/meta/index state.

```basic
SQL_CMD$ = "COMPACT"
SQL_STMT$ = ""
GOSUB CALL_SQL
```

---

### REINDEX

Rebuilds `DBNAME-idx.dat` by scanning all `DBNAME-db*.dat` files.
Then runs COMPACT.

```basic
SQL_CMD$ = "REINDEX"
SQL_STMT$ = ""
GOSUB CALL_SQL
```

---

## SQL-ish Statement Reference (with examples)

### CREATE TABLE

Format:

`CREATE TABLE t (a,b,c) PK KEY`

**Example**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "CREATE TABLE people (name,age,city) PK KEY"
GOSUB CALL_SQL
```

Notes:

* Columns are a comma-list.
* `PK KEY` stores the pk label. MiniSQL still uses the keyword `KEY`
  in statements for lookups/updates.

---

### INSERT

Format:

`INSERT INTO t KEY k VALUES (v1,v2,v3)`

**Example**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO people KEY alice VALUES (Alice,25,Chicago)"
GOSUB CALL_SQL
```

Notes:

* values are positional, matching schema order.
* no quoting rules (commas and `|` inside values will break parsing).

---

### SELECT (+ WHERE + LIMIT)

Format:

* `SELECT * FROM t`
* `SELECT * FROM t WHERE col=value`
* `SELECT * FROM t WHERE KEY=somekey`
* add `LIMIT n` optionally

**Examples**

Select all:

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT * FROM people"
GOSUB CALL_SQL
```

Filter by column:

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT * FROM people WHERE city=Chicago"
GOSUB CALL_SQL
```

Direct key lookup (fastest):

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT * FROM people WHERE KEY=alice"
GOSUB CALL_SQL
```

Filter + limit:

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT * FROM people WHERE city=Chicago LIMIT 5"
GOSUB CALL_SQL
```

---

### UPDATE

Format:

`UPDATE t KEY k SET col=value`

**Example**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "UPDATE people KEY bob SET city=Denver"
GOSUB CALL_SQL
```

Behavior:

* appends a new record version
* updates index to point to the new version

---

### REPLACE

Format:

`REPLACE t KEY k VALUES (v1,v2,v3)`

**Example**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "REPLACE people KEY bob VALUES (Bob,30,Denver)"
GOSUB CALL_SQL
```

Behavior:

* appends a full new record version
* updates index to point to it

---

### DELETE

Format:

`DELETE FROM t KEY k`

**Example**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "DELETE FROM people KEY bob"
GOSUB CALL_SQL
```

Behavior:

* writes a tombstone `I|people|bob|0|0`
* old row versions remain in db files but are not returned

---

## Modes (RW / RO / AO)

Set `SQL_MODE$` before calling MiniSQL.

### RW (Read/Write)

Default. All commands allowed.

```basic
SQL_MODE$ = "RW"
```

### RO (Read-only)

Only SELECT allowed via EXEC. Writes return an error.

```basic
SQL_MODE$ = "RO"
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT * FROM people"
GOSUB CALL_SQL
```

### AO (Append-only)

Only INSERT allowed via EXEC. Updates/deletes are blocked.

```basic
SQL_MODE$ = "AO"
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO log KEY e1 VALUES (HELLO)"
GOSUB CALL_SQL
```

---

## Results and Output Format

### SQL_MSG$

Always check `SQL_STATUS`. `SQL_MSG$` gives a short hint:

* `INSERTED people KEY alice`
* `UPDATED people KEY bob`
* `0 ROWS`
* `READ-ONLY MODE`

### SQL_RESULT$

For SELECT/SEARCH:

* records are joined with `CHR$(10)`
* each record line is the raw stored line:

`R|table|key|col=value|...`

### Example: parsing a record line

If you want to extract the `key` from a result row:

```basic
REM L$ is one record line like:
REM R|people|alice|name=Alice|age=25|city=Chicago

REM remove "R|"
REST$ = MID$(L$, 3)

REM token 1 = table, token 2 = key
TBL$ = GETTOK$(REST$, "|", 1)
KEY$ = GETTOK$(REST$, "|", 2)
```

A minimal token helper (no quotes):

```basic
GETTOK$:
  REM IN: S$, D$, N  OUT: GETTOK$
  P = 1
  K = 1
GT1:
  Q = INSTR(MID$(S$, P), D$)
  IF Q = 0 THEN
    PART$ = MID$(S$, P)
  ELSE
    PART$ = MID$(S$, P, Q-1)
  END IF
  IF K = N THEN GETTOK$ = TRIM$(PART$): RETURN
  IF Q = 0 THEN GETTOK$ = "": RETURN
  P = P + Q
  K = K + 1
  GOTO GT1
```

---

## Error Codes (SQL_STATUS)

Common codes:

* `0` OK
* `10` missing SQL_DB$
* `11` empty SQL statement
* `12` unsupported SQL
* `20` read-only mode blocked a write
* `21` append-only mode blocked a non-insert
* `30..35` CREATE parse errors
* `40..46` INSERT parse / missing table errors
* `50..52` SELECT parse errors
* `60..65` UPDATE parse errors
* `70..75` REPLACE parse errors
* `80..82` DELETE parse errors
* `90..91` SEARCH parse errors
* `98` internal empty record protection
* `99` unknown command

Tip: always print both `SQL_STATUS` and `SQL_MSG$`.

---

## Maintenance & Best Practices

1. Run INITDB once per DB name before other commands.

2. Prefer `WHERE KEY=...` for fastest lookups.

3. Run COMPACT occasionally to keep `idx.dat` smaller.

4. Run REINDEX if you suspect index problems.

5. Use transactions for bulk writes:
   
   * BEGIN
   * many EXEC (queued)
   * COMMIT

---

## Troubleshooting

### “My program runs but nothing happens”

Most common causes:

1. You never print status/result in the caller.
   
   * Use the CALL_SQL helper in this manual.

2. CHAIN target mismatch.
   
   * Try `CHAIN "minisql.bas"`.

3. COMMON mismatch (variables or order differ).
   
   * Ensure both files use exactly the same COMMON declarations.

### “SELECT returns old data”

MiniSQL returns the latest indexed version. If index seems stale:

* run COMPACT
* if still wrong, run REINDEX

---

## Compatibility Notes / Simplifications

MiniSQL is intentionally simple:

* no quoting/escaping
* values cannot safely contain `,` or `|`
* WHERE is simple `col=value`
* no JOIN/ORDER/GROUP
* no type enforcement (everything is text)

This may change in newer versions.

---

## Quick Walkthrough Example (full flow)

This shows the full flow in one place.

```basic
REM Setup
SQL_DB$ = "TESTDB"
SQL_MODE$ = "RW"

REM Init
SQL_CMD$ = "INITDB"
SQL_STMT$ = ""
GOSUB CALL_SQL

REM Create table
SQL_CMD$ = "EXEC"
SQL_STMT$ = "CREATE TABLE people (name,age,city) PK KEY"
GOSUB CALL_SQL

REM Insert
SQL_STMT$ = "INSERT INTO people KEY alice VALUES (Alice,25,Chicago)"
GOSUB CALL_SQL

REM Update
SQL_STMT$ = "UPDATE people KEY alice SET city=Boston"
GOSUB CALL_SQL

REM Select
SQL_STMT$ = "SELECT * FROM people WHERE KEY=alice"
GOSUB CALL_SQL

REM Compact
SQL_CMD$ = "COMPACT"
SQL_STMT$ = ""
GOSUB CALL_SQL
```

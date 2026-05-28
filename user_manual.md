# MiniSQL User Manual (minisql.bas) — v0.5.0

MiniSQL is a tiny SQL-ish database engine designed for
TIMESHARING BASIC / 3270BBS-style BASIC.

It is used like a **library**: your program sets `COMMON` variables and
`CHAIN`s into `minisql.bas` for one operation. MiniSQL returns to your
program when it finishes.

---

## Table of Contents

- What MiniSQL Is
- Limits and Design Goals
- Files MiniSQL Creates
- Storage Model (ISAM)
- Calling Convention (COMMON + CHAIN)
- Code Template (recommended)
- Commands (with code examples)
  - INITDB / OPENDB
  - EXEC
  - SEARCH
  - BEGIN / COMMIT / ROLLBACK
- SQL-ish Statement Reference (with examples)
  - CREATE TABLE
  - INSERT (+ auto-increment keys)
  - SELECT (column filtering, DISTINCT, *,
    WHERE with AND/OR/comparison/LIKE,
    ORDER BY, LIMIT, COUNT)
  - UPDATE (single-key, bulk WHERE, multi-col SET)
  - REPLACE
  - DELETE (single-key, bulk WHERE)
  - DROP TABLE
  - SHOW TABLES
  - DESCRIBE table
  - ALTER TABLE (ADD / DROP col)
- SEARCH Modes: CONTAINS, EXACT, PREFIX, SUFFIX
- Modes (RW / RO / AO)
- Event Logging
- Option Codes (configuration)
- Results and Output Format (+ printing helpers)
- Error Codes
- Maintenance & Best Practices
- Troubleshooting
- Compatibility Notes

---

## What MiniSQL Is

MiniSQL provides:

- simple tables (schema stored in a system ISAM table)
- insert/select/update/replace/delete/drop
- ISAM-based primary key index on every table
- SELECT column filtering (col1,col2,... or *)
- SELECT DISTINCT deduplication
- WHERE with AND/OR, comparison operators (< > <= >= <>),
  and LIKE (% wildcard)
- ORDER BY with ascending/descending sort
- COUNT(*) aggregate
- auto-increment numeric keys
- transactions (queue statements, commit later)
- event logging with timestamps + configurable log levels
- configurable option codes
- SHOW TABLES / DESCRIBE / ALTER TABLE
- search with CONTAINS, EXACT, PREFIX, SUFFIX matching
- bulk UPDATE and DELETE by WHERE clause
- multi-column SET in UPDATE

MiniSQL is not full SQL. It is intentionally small and file-based.

---

## Limits and Design Goals

MiniSQL exists to live within platform limits:

- Data file size: max 256KB per ISAM file
- Open file handles: max 4 at one time
  (uses #1=log, #2=schema, #3=table, #4=batch)
- Watchdog safety: long loops call `SLEEP(0.25)` periodically
- Result set sort limit: max 500 rows in memory (ORDER BY)

---

## Files MiniSQL Creates

Assuming `SQL_DB$ = "TESTDB"` and table `people`, MiniSQL creates:

- `TESTDB.log.dat` — event log (always open as file #1)
- `TESTDB.schema.idx` — ISAM system table storing schemas
- `TESTDB.people.idx` — ISAM file per user table
- `batch.dat` — transaction queue (global, not per-database)

### Filename rules

The system does not allow `_` in filenames.
MiniSQL converts `_` to `-` in your DB prefix.

---

## Storage Model (ISAM)

MiniSQL v0.4.0+ uses the platform's built-in **INDEXED** file system
(ISAM) as its storage foundation.

### How it works

Each table gets its own ISAM file: `<db>.<table>.idx`

- Records are stored as **associative arrays** (`DIM R{}`)
- The primary key field is always `"key"`
- ISAM handles indexing, lookup, and deletion internally
- `PUT #n, R{}` inserts or updates a record by key
- `GET #n, R{}, KEY = k` looks up by key (fast)
- `GET #n, R{}, NEXT` scans sequentially
- `DELETE #n, KEY = k` removes by key

### Schema storage

Table schemas (column list + primary key + auto-inc sequence) are
stored in the system ISAM table `<db>.schema.idx`, keyed by table name.

### No more append-only model

Unlike v0.3.x, MiniSQL now uses proper indexed storage.
UPDATE and REPLACE overwrite in place. DELETE removes the entry
entirely. No tombstone records, no multi-file rollover.

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

* `SQL_CMD$`: `INITDB`, `EXEC`, `SEARCH`, `BEGIN`, `COMMIT`, `ROLLBACK`
* `SQL_DB$`: database prefix (example: `TESTDB`)
* `SQL_MODE$`: `RW`, `RO`, `AO`
* `SQL_STMT$`: statement (EXEC) or pipe-delimited spec (SEARCH)

### Outputs

* `SQL_STATUS`: `0` success, nonzero error
* `SQL_MSG$`: short status message
* `SQL_RESULT$`: results text for SELECT/SEARCH (lines split by LF)

---

## Code Template (recommended)

Use this caller template in your programs:

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

Creates the log file with header + option codes, and seeds the schema
ISAM system table.

**Example**

```basic
SQL_CMD$ = "INITDB"
SQL_STMT$ = ""
GOSUB CALL_SQL
```

Expected `SQL_MSG$`:

* `INITDB OK`

---

### EXEC

Executes one SQL-ish statement in `SQL_STMT$`.

**Example: CREATE TABLE**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "CREATE TABLE people (name,age,city) PK KEY"
GOSUB CALL_SQL
```

**Example: INSERT with auto-increment key**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO people VALUES (Alice,25,Chicago)"
GOSUB CALL_SQL
```

**Example: SELECT with column filtering and WHERE**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT name,age FROM people WHERE city=Chicago"
GOSUB CALL_SQL
```

**Example: bulk UPDATE by WHERE**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "UPDATE people SET city=Denver WHERE age<30"
GOSUB CALL_SQL
```

---

### SEARCH

Scan-style search with configurable matching mode.
`SQL_STMT$` is pipe-delimited: `table|term|col|mode`

The 4th field (mode) is optional, defaulting to `CONTAINS`.

**Example: search any field (CONTAINS)**

```basic
SQL_CMD$ = "SEARCH"
SQL_STMT$ = "people|denver||"
GOSUB CALL_SQL
```

**Example: search by exact match on a column**

```basic
SQL_CMD$ = "SEARCH"
SQL_STMT$ = "people|Chicago|city|EXACT"
GOSUB CALL_SQL
```

---

### BEGIN / COMMIT / ROLLBACK (Transaction batching)

Transactions queue write statements in `batch.dat`.

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

## SQL-ish Statement Reference

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
* `PK KEY` stores the pk label. MiniSQL always uses `key` as the ISAM
  key field internally.

---

### INSERT

Format:

`INSERT INTO t [KEY k|*] VALUES (v1,v2,v3)`

KEY is optional. Omitting KEY or using `*` auto-generates a numeric
key from the table's sequence counter (starts at 1).

**Example: explicit key**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO people KEY alice VALUES (Alice,25,Chicago)"
GOSUB CALL_SQL
```

**Example: auto-increment key**

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO people VALUES (Bob,30,Boston)"
GOSUB CALL_SQL
```

**Example: auto-increment with KEY ***

```basic
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO people KEY * VALUES (Carol,28,Miami)"
GOSUB CALL_SQL
```

Notes:

* values are positional, matching schema order.
* duplicate explicit keys are rejected (error code 47).
* auto-increment keys are guaranteed unique per table.

---

### SELECT

Format:

* `SELECT * FROM t`
* `SELECT col1,col2 FROM t`
* `SELECT DISTINCT col FROM t`
* `SELECT COUNT(*) FROM t`
* `... WHERE col=value`
* `... WHERE cond AND cond2 OR cond3`
* `... WHERE col LIKE %pattern%`
* `... WHERE key > 100`
* `... WHERE KEY=somekey`
* `... ORDER BY col [ASC|DESC]`
* `... LIMIT n`

**Examples**

Select all:

```basic
SQL_STMT$ = "SELECT * FROM people"
```

Filter columns:

```basic
SQL_STMT$ = "SELECT name,age FROM people"
```

With DISTINCT:

```basic
SQL_STMT$ = "SELECT DISTINCT city FROM people"
```

Count rows:

```basic
SQL_STMT$ = "SELECT COUNT(*) FROM people"
```

WHERE with AND:

```basic
SQL_STMT$ = "SELECT * FROM people WHERE age>20 AND city=Chicago"
```

WHERE with LIKE:

```basic
SQL_STMT$ = "SELECT * FROM people WHERE name LIKE %A%"
```

WHERE with comparison:

```basic
SQL_STMT$ = "SELECT * FROM people WHERE age>=18"
```

Direct key lookup (fastest — uses ISAM keyed GET):

```basic
SQL_STMT$ = "SELECT * FROM people WHERE KEY=alice"
```

Filter + sort + limit:

```basic
SQL_STMT$ = "SELECT name,age FROM people "
SQL_STMT$ = SQL_STMT$ + "WHERE city=Chicago ORDER BY age DESC "
SQL_STMT$ = SQL_STMT$ + "LIMIT 5"
```

**WHERE operators:**

| Operator | Meaning     |
|----------|-------------|
| `=`      | Equal       |
| `<`      | Less than   |
| `>`      | Greater than|
| `<=`     | Less/equal  |
| `>=`     | Greater/equal|
| `<>`     | Not equal   |
| `LIKE`   | Pattern match (% wildcard) |

**LIKE wildcards:**

| Pattern   | Meaning                        |
|-----------|--------------------------------|
| `%text%`  | Contains (substring match)     |
| `text%`   | Starts with (prefix match)     |
| `%text`   | Ends with (suffix match)       |
| `text`    | Exact match (no wildcard)      |

**ORDER BY details:**

* Up to 500 rows are collected in memory and insertion-sorted.
* If more than 500 rows match, excess rows are appended unsorted.
* ASC and DESC are supported. Default is ASC.
* Uses string comparison (text sorting, not numeric).

---

### UPDATE

Format:

* `UPDATE t KEY k SET col=val` (single row, by KEY)
* `UPDATE t KEY k SET col1=val1,col2=val2` (multi-column SET)
* `UPDATE t SET col=val WHERE cond` (bulk, by WHERE)

**Examples**

Single key update:

```basic
SQL_STMT$ = "UPDATE people KEY bob SET city=Denver"
```

Multi-column SET:

```basic
SQL_STMT$ = "UPDATE people KEY bob SET city=Denver,age=31"
```

Bulk update by WHERE:

```basic
SQL_STMT$ = "UPDATE people SET city=Denver WHERE age<30"
```

Behavior:

* KEY-based: retrieves record, modifies, re-puts (overwrites)
* WHERE-based: scans all rows, evaluates WHERE, updates matches

---

### REPLACE

Format:

`REPLACE t KEY k VALUES (v1,v2,v3)`

**Example**

```basic
SQL_STMT$ = "REPLACE people KEY bob VALUES (Bob,30,Denver)"
```

Behavior:

* Creates a fresh record with all columns from VALUES
* Puts it via ISAM (overwrites any existing record with that key)
* Duplicates are allowed (unlike INSERT)

---

### DELETE

Format:

* `DELETE FROM t KEY k` (single row)
* `DELETE FROM t WHERE cond` (bulk)

**Examples**

Single key delete:

```basic
SQL_STMT$ = "DELETE FROM people KEY bob"
```

Bulk delete by WHERE:

```basic
SQL_STMT$ = "DELETE FROM people WHERE age<18"
```

---

### DROP TABLE

Format:

`DROP TABLE t`

**Example**

```basic
SQL_STMT$ = "DROP TABLE people"
```

Behavior:

* Empties the table's ISAM file and removes its schema entry.
* The ISAM file still exists on disk (empty) and can be re-created
  with CREATE TABLE.

---

### SHOW TABLES

Lists all tables in the current database.

```basic
SQL_STMT$ = "SHOW TABLES"
```

Output in `SQL_RESULT$`: one table name per line.

---

### DESCRIBE

Shows schema for a table.

```basic
SQL_STMT$ = "DESCRIBE people"
```

Output format:

```
TBL=people
COLS=name,age,city
PK=key
```

---

### ALTER TABLE

Add or drop a column from an existing table.

`ALTER TABLE t ADD col`

`ALTER TABLE t DROP col`

**Examples**

```basic
SQL_STMT$ = "ALTER TABLE people ADD email"
SQL_STMT$ = "ALTER TABLE people DROP age"
```

Notes:

* ADD requires the column name not to already exist.
* DROP removes the column from the schema only — existing ISAM
  records still contain the old data (unused fields are ignored).
* The PK column cannot be dropped via ALTER.

---

## SEARCH Modes

The SEARCH command supports four matching modes as the 4th
pipe-delimited parameter in `SQL_STMT$`:

| Mode       | Description                    | Example match "Chicago" |
|------------|--------------------------------|-------------------------|
| `CONTAINS` | Substring match (default)      | `"Chi"` ✓ `"go"` ✓      |
| `EXACT`    | Full field must equal term     | `"Chicago"` only         |
| `PREFIX`   | Field starts with term         | `"Chi"` ✓ `"go"` ✗      |
| `SUFFIX`   | Field ends with term           | `"go"` ✓ `"Chi"` ✗      |

**Examples:**

```basic
' EXACT match on city field
SQL_STMT$ = "people|Chicago|city|EXACT"

' PREFIX match on name field
SQL_STMT$ = "people|A|name|PREFIX"

' SUFFIX match on any field (leave col blank)
SQL_STMT$ = "people|ville||SUFFIX"
```

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
```

### AO (Append-only)

Only INSERT allowed via EXEC. Updates/deletes are blocked.

```basic
SQL_MODE$ = "AO"
```

---

## Event Logging

MiniSQL maintains an event log at `<db>.log.dat`. It is opened at the
start of every session (file handle #1) and kept open until the session
ends.

Each log line is pipe-delimited:

`EVENT|LABEL|YYYY-MM-DDTHH:MM:SS|message`

### Log labels

| Label     | When used                        |
|-----------|----------------------------------|
| `OPEN`    | Database opened, transaction start |
| `CLOSED`  | Database closed, txn rollback/commit |
| `UPDATED` | CREATE TABLE, UPDATE, REPLACE, ALTER, SHOW |
| `APPENDED`| INSERT                           |
| `DELETED` | DELETE, DROP TABLE               |
| `WARNING` | Mode violation (RO/AO)           |
| `ERROR`   | Transaction abort                |

### Log control

Logging behavior is controlled by option codes:

- OPT 200 (LOG_ENABLED): `0` disables all logging
- OPT 201 (LOG_LEVEL): `0`=errors only, `1`=normal, `2`=verbose

---

## Option Codes

Option codes are stored in the log file header and loaded on startup.
They control MiniSQL behavior. All 30 slots (100-109, 200-209, 300-309)
are pre-allocated with defaults.

### Header options (100-109)

| Code | Name            | Default  | Description             |
|------|-----------------|----------|-------------------------|
| 100  | VERSION         | `0.5.0`  | Database version        |
| 101  | AUTOCOMPACT     | `0`      | Auto-compact on startup |
| 102  | MAXREC          | `10000`  | Max records per file    |
| 103-109 | (reserved)   | `0`      | Future use              |

### Log options (200-209)

| Code | Name            | Default  | Description             |
|------|-----------------|----------|-------------------------|
| 200  | LOG_ENABLED     | `1`      | Enable event logging    |
| 201  | LOG_LEVEL       | `1`      | 0=errors, 1=normal, 2=verbose |
| 202-209 | (reserved)   | `0`      | Future use              |

### Batching options (300-309)

| Code | Name            | Default  | Description             |
|------|-----------------|----------|-------------------------|
| 300  | BATCH_ENABLED   | `1`      | Enable transaction batching |
| 301  | BATCH_MAX       | `100`    | Max statements per batch |
| 302-309 | (reserved)   | `0`      | Future use              |

---

## Results and Output Format

### SQL_MSG$

Always check `SQL_STATUS`. `SQL_MSG$` gives a short hint:

* `INSERTED people KEY alice`
* `UPDATED people KEY bob`
* `UPDATED 5 ROWS IN people` (bulk)
* `READ-ONLY MODE`
* `COUNT=42`
* `TBL=people / COLS=name,age,city / PK=key`

### SQL_RESULT$

For SELECT/SEARCH:

* records are joined with `CHR$(10)`
* each record line format:

`R|pkname|pkvalue|col=value|col=value|...`

### Example: parsing a record line

```basic
REM L$ is one record line like:
REM R|key|alice|name=Alice|age=25|city=Chicago

REM remove leading "R|"
REST$ = MID$(L$, 3)

REM token 1 = pkname, token 2 = pkvalue
PKNAME$ = GETTOK$(REST$, "|", 1)
KEY$ = GETTOK$(REST$, "|", 2)
```

A minimal token helper (no quotes):

```basic
GETTOK$:
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

| Code | Description                       |
|------|-----------------------------------|
| `0`  | OK                                |
| `10` | missing SQL_DB$                   |
| `11` | empty SQL statement               |
| `12` | unsupported SQL                   |
| `20` | read-only mode blocked a write    |
| `21` | append-only mode blocked non-INSERT |
| `30..33` | CREATE parse / table exists    |
| `40..47` | INSERT parse / missing table / dup key |
| `50..52` | SELECT parse errors            |
| `60..66` | UPDATE parse / key not found   |
| `70..75` | REPLACE parse errors            |
| `80..82` | DELETE parse errors            |
| `85..86` | DROP parse / missing table     |
| `87`   | ALTER parse / column error      |
| `88`   | SHOW parse error                 |
| `89`   | DESCRIBE parse error             |
| `90..91` | SEARCH parse / missing table   |
| `98`   | internal empty record protection  |
| `99`   | unknown command                   |

Tip: always print both `SQL_STATUS` and `SQL_MSG$`.

---

## Maintenance & Best Practices

1. Run INITDB once per DB name before other commands.

2. Prefer `WHERE KEY=...` for fastest lookups (ISAM keyed GET).

3. Use transactions for bulk writes:
   * BEGIN
   * many EXEC (queued in batch.dat)
   * COMMIT

4. No COMPACT/REINDEX needed — ISAM handles index maintenance
   internally.

5. The log file grows unbounded. Periodically clear it by deleting
   `<db>.log.dat` or running INITDB again (recreates the header).

6. Use ALTER TABLE to evolve schemas without data loss.

---

## Troubleshooting

### "My program runs but nothing happens"

Most common causes:

1. You never print status/result in the caller.
   * Use the CALL_SQL helper in this manual.

2. CHAIN target mismatch.
   * Try `CHAIN "minisql.bas"`.

3. COMMON mismatch (variables or order differ).
   * Ensure both files use exactly the same COMMON declarations.

### "SELECT returns 0 ROWS but I inserted data"

Check:

1. The SQL_DB$ matches between INSERT and SELECT calls.
2. The table name matches.
3. You used the same KEY value you're searching for.

### "ORDER BY returns unsorted results"

Possible causes:

1. More than 500 rows matched — overflow rows are not sorted.
2. The sort column name doesn't match the schema (case-sensitive).

---

## Compatibility Notes / Simplifications

MiniSQL is intentionally simple:

* no quoting/escaping
* values cannot safely contain `,` or `|`
* no JOIN/GROUP BY/subqueries
* no type enforcement (everything is text)
* ORDER BY uses string comparison, not numeric
* ORDER BY limited to 500 rows in memory

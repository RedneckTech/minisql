# MiniSQL (TIMESHARING BASIC) — Chainable Tiny SQL-ish Database

MiniSQL is a small, **chainable** SQL-ish database engine written for
**TIMESHARING BASIC / 3270BBS-style BASIC**.

It is designed to be used as a **library** from other BASIC programs via
`COMMON` + `CHAIN`, so you can add simple database features to your own
projects without rewriting storage/search logic every time.

---

## Key Features

- **Program chaining library**
  
  - Your program sets `COMMON` variables and `CHAIN`s into `minisql.bas`.
  - MiniSQL runs one command and returns to the caller.

- **Multiple tables**
  
  - Table schemas are stored in the index file.

- **Storage across multiple data files**
  
  - Data is stored in: `DBNAME-db1.dat`, `DBNAME-db2.dat`, ...
  - Each `.dat` file stays under the **10KB** limit.

- **Indexing**
  
  - Index is stored in: `DBNAME-idx.dat`
  - Index entries are append-only (latest entry wins).

- **Update/Replace support**
  
  - Updates append a **new version** of a row.
  - Index is updated to point at the newest version.

- **Read-only and append-only modes**
  
  - `RO`: only SELECT is allowed.
  - `AO`: only INSERT is allowed.

- **Search and filtering**
  
  - `SELECT ... WHERE col=value`
  - `LIMIT n`
  - `SEARCH` command: `table|term|col(optional)`

- **Transaction-style batching**
  
  - `BEGIN` queues statements into `DBNAME-txn.dat`
  - `COMMIT` runs queued statements
  - `ROLLBACK` clears the queue

- **COMPACT and REINDEX maintenance**
  
  - `COMPACT`: rebuilds the index to remove old duplicate entries.
  - `REINDEX`: rebuilds index entries by scanning the DB data files.

- **Watchdog-safe**
  
  - Uses `SLEEP(0.25)` inside long loops.

- **4 open files max**
  
  - MiniSQL opens files briefly and closes them quickly.
  - Typically only 1–2 files are open at any time.

---

## Project Files

- `minisql.bas`
  
  - The chainable database engine.

- `demo_sql.bas`
  
  - Interactive tutorial/demo that teaches how to call `minisql.bas`.

---

## File Naming Rules

The terminal/filesystem rules for this project include:

- Filenames **cannot** contain `_`
- MiniSQL uses `-` instead.

Generated files:

- `DBNAME-idx.dat`  (index, schemas, metadata)
- `DBNAME-db1.dat`  (data rows)
- `DBNAME-db2.dat`  (next data file when db1 is full)
- `DBNAME-txn.dat`  (transaction queue)

Where `DBNAME` comes from `SQL_DB$` (MiniSQL also sanitizes `_` → `-`).

---

## Data Format (High-Level)

MiniSQL uses simple text lines:

### Index file: `DBNAME-idx.dat`

- `M|CUR|n`
  
  - Current active DB file number (`dbn.dat`)

- `M|TXN|0/1`
  
  - Transaction flag

- `F|n|bytes`
  
  - Approx byte count of `dbn.dat` (for 10KB rollover)

- `R|n|lastRec`
  
  - Record count in `dbn.dat`

- `S|table|col1,col2,col3|pkname`
  
  - Table schema

- `I|table|key|file|rec`
  
  - Index entry:
    - `file,rec` points to a row in `dbX.dat`
    - `0|0` is a tombstone (deleted)

### Data files: `DBNAME-dbX.dat`

Rows are stored as:

- `R|table|key|col=value|col=value|...`

Updates and replaces append a new `R|...` line and update the index to
point at the newest record.

---

## Calling MiniSQL from Your Program

MiniSQL is controlled using `COMMON` variables.

Your program must declare **the same COMMON variables** as `minisql.bas`
and then `CHAIN` into MiniSQL.

### Required COMMON block (caller + minisql must match)

```basic
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$
```

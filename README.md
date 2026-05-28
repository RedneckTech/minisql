# MiniSQL (TIMESHARING BASIC) v0.4.0 — Chainable Tiny SQL-ish Database

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

- **ISAM-based storage**
  
  - Uses the platform's built-in INDEXED file system (PUT/GET/DELETE)
  - Each table has its own ISAM file for fast keyed lookups

- **Multiple tables**
  
  - Table schemas stored in a system ISAM table (`<db>.schema.idx`)

- **Full CRUD + DROP**
  
  - CREATE TABLE, INSERT, SELECT, UPDATE, REPLACE, DELETE, DROP TABLE

- **ORDER BY with sorting**
  
  - `ORDER BY col [ASC|DESC]` with in-memory insertion sort (up to 500 rows)

- **Read-only and append-only modes**
  
  - `RO`: only SELECT is allowed.
  - `AO`: only INSERT is allowed.

- **Search and filtering**
  
  - `SELECT ... WHERE col=value` or `WHERE KEY=val`
  - `LIMIT n`
  - `SEARCH` with modes: CONTAINS, EXACT, PREFIX, SUFFIX

- **Transaction-style batching**
  
  - `BEGIN` queues statements into `batch.dat`
  - `COMMIT` runs queued statements
  - `ROLLBACK` clears the queue

- **Event logging**
  
  - All operations logged to `<db>.log.dat` with timestamps
  - Labels: OPEN, CLOSED, UPDATED, APPENDED, DELETED, WARNING, ERROR

- **Configurable option codes**
  
  - 30 pre-allocated options (100-109 header, 200-209 log, 300-309 batching)

- **Watchdog-safe**
  
  - Uses `SLEEP(0.25)` inside long loops.

- **4 open files max**
  
  - #1=log (always open), #2=schema, #3=table, #4=batch

---

## Project Files

- `minisql.bas` — the chainable database engine (851 lines)

---

## File Naming Rules

The terminal/filesystem rules for this project include:

- Filenames **cannot** contain `_`
- MiniSQL uses `-` instead.

Generated files for `SQL_DB$ = "testdb"` with table `people`:

- `testdb.log.dat` — event log
- `testdb.schema.idx` — system ISAM table for schemas
- `testdb.people.idx` — ISAM file per user table
- `batch.dat` — transaction queue (global)

---

## Quick Example

```basic
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "testdb"
SQL_MODE$ = "RW"

SQL_CMD$ = "INITDB"
SQL_STMT$ = ""
CHAIN "minisql"

SQL_CMD$ = "EXEC"
SQL_STMT$ = "CREATE TABLE people (name,age,city) PK KEY"
CHAIN "minisql"

SQL_STMT$ = "INSERT INTO people KEY alice VALUES (Alice,25,Chicago)"
CHAIN "minisql"

SQL_STMT$ = "SELECT * FROM people WHERE KEY=alice"
CHAIN "minisql"
PRINT SQL_RESULT$
```

---

## Commands

| Command      | Description                        |
|--------------|------------------------------------|
| `INITDB`     | Initialize database files          |
| `EXEC`       | Execute SQL statement              |
| `SEARCH`     | Scan with CONTAINS/EXACT/PREFIX/SUFFIX |
| `BEGIN`      | Start transaction                  |
| `COMMIT`     | Commit queued statements           |
| `ROLLBACK`   | Rollback queued statements         |

### SQL Statements (via EXEC)

| Statement                      | Description                |
|--------------------------------|----------------------------|
| `CREATE TABLE t (a,b,c) PK k` | Create table               |
| `INSERT INTO t KEY k VALUES (v1,v2,...)` | Insert row    |
| `SELECT * FROM t [WHERE ...] [ORDER BY ...] [LIMIT n]` | Query |
| `UPDATE t KEY k SET col=val`  | Update column              |
| `REPLACE t KEY k VALUES (...)`| Replace entire row         |
| `DELETE FROM t KEY k`         | Delete by key              |
| `DROP TABLE t`                | Drop table                 |

---

## Documentation

See `user_manual.md` for complete documentation including calling
convention, storage model, error codes, SEARCH modes, option codes,
and a full walkthrough example.

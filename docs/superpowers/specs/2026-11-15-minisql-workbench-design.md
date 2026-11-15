# MiniSQL Workbench — Design

Date: 2026-11-15
Status: draft for builder review
Project: `minisql` (TIMESHARING BASIC / 3270BBS)

## 1. Intent

A screen-based workbench for designing new, multi-table MiniSQL databases.
The user has not built a database before and does not have a specific first
database in mind. The tool should make schema design concrete and visible:
create tables and columns, record the logical links between them, look at the
whole design on one map, and browse/edit sample rows without writing SQL by
hand. SQL remains available as an escape hatch.

The agreed mental model is a small shop: `customers`, `products`, `orders`,
`order_lines`, `suppliers`, `shipments`, with links such as
`orders.customer_id -> customers.id`.

## 2. What it is

A standalone BASIC program, `dbwork.bas`, run from the BBS BASIC prompt.
It chains into `minisql.bas` for every database operation and returns to its
own menu. It is a design/administration tool, not a library.

## 3. Goals

1. Open or create a database by name; remember recently used databases.
2. Show a table list with each table's columns and key.
3. Create and drop tables; add and drop columns.
4. Record logical links between table columns; show them in the table view and
   on a design map.
5. Browse rows page by page; view, insert, edit, and delete rows.
6. Show a whole-database map: every table, its columns, and all links.
7. Provide a SQL console for anything the menus do not cover.
8. Protect destructive actions with confirmation and by cleaning up links.
9. Seed a sample `SHOP` database from the start screen so a first-time user has
   something to explore.

## 4. Non-goals (v1)

- No spreadsheet/cursor UI. The BASIC environment cannot position the cursor
  vertically or define editable fields; screens are drawn top-to-bottom and
  commands are typed on one input line.
- No joins, foreign-key enforcement, or referential integrity. Links are design
  notes only; MiniSQL does not enforce them.
- No column data types or type validation. MiniSQL stores everything as text.
  The workbench rejects values containing `,` or `|` (they would corrupt the
  engine's record format) but otherwise treats values as text.
- No table or column rename. MiniSQL has no rename; emulating it by
  create-copy-drop is future work.
- No import/export, no multi-user/concurrency handling, no graphical ERD.
- No sorting options in the row browser in v1; rows are shown in key order.
- No editing of the workbench's own metadata table (`zzlinks`) from the table
  list or map.

## 5. Anti-goals

- A tool that silently corrupts a record because a value contained a comma or
  pipe.
- A tool that hides MiniSQL's limits and then fails with a confusing runtime
  error.
- A tool that is slower than typing SQL for a one-line task.
- A tool that requires reading the user manual before the first table can be
  created.

## 6. Constraints

### 6.1 Environment

- TIMESHARING BASIC v3.0.1 on 3270BBS; label-mode source; `START:` required.
- Program filename `dbwork.bas` (6 chars, no `_`; BBS program names are limited
  to 10 chars and cannot contain `_`).
- Source lines ≤ 71 chars, ASCII only.
- 24×80 screen; 79 usable columns (the 80th is dropped).
- No vertical cursor positioning. `CLS` clears; output flows downward; `TAB(n)`
  is horizontal only. Screens are redrawn from the top, never overlaid.
- No `EXIT WHILE`. Use a flag variable in the `WHILE` condition.
- Do not `GOTO` out of a `WHILE`: it leaves the loop frame on the stack and a
  later `WEND` resumes the abandoned loop. `RETURN` from inside a `WHILE` is
  safe. Use flag loops.
- `SLEEP` minimum is 0.1; use it in long loops.
- Strings cap at 2048 bytes; `SQL_RESULT$` is capped around 2000 bytes.
- No `ON ERROR`; a runtime error terminates the program. Validate before
  calling the engine.
- Single-line `BOXCHAR$` (1-6) and `CP310$` 13-17, 22-25, 29-32 render; the
  double-line set renders as `■`. Build panel lines with `+` and `SPACE$`;
  `TAB` after box characters is 2 columns early because it counts UTF-8 bytes.
- Colors: `COLOR GREEN/RED/YELLOW/PINK/BLUE/TURQUOISE/WHITE` at the end of a
  `PRINT` colors the whole line.

### 6.2 MiniSQL engine

- Every operation is one `CHAIN "minisql.bas"` call with
  `COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$` and
  `COMMON SQL_STATUS, SQL_MSG$`.
- `SQL_CMD$ = "EXEC"` for SQL statements, `"INITDB"` to initialize/open.
- `SQL_STATUS` 0 = success; nonzero = error. Always display `SQL_MSG$` on error.
- Result formats:
  - `SELECT` rows: `R|key|<keyval>|col=value|col=value...`, lines separated by
    `CHR$(10)`.
  - `SELECT COUNT(*)`: `COUNT=<n>` (no newline).
  - `SHOW TABLES`: one table name per line.
  - `DESCRIBE t`: `TBL=<name>\nCOLS=<comma list>\nPK=<key label>`.
- The engine's internal row key field is always `key`. It is separate from the
  user's columns. `CREATE TABLE ... PK KEY` always uses that key.
- `INSERT INTO t VALUES (...)` auto-generates a numeric key; `INSERT INTO t KEY
  k VALUES (...)` uses an explicit key.
- `REPLACE t KEY k VALUES (...)` writes the whole row (best for the edit form).
- `UPDATE t KEY k SET col=value,...` updates selected columns.
- `DELETE FROM t KEY k` deletes one row.
- `ALTER TABLE t ADD col` / `ALTER TABLE t DROP col`.
- `DROP TABLE t`.
- `SELECT * FROM t LIMIT n` returns up to n rows in key order.
- `SELECT * FROM t WHERE key>lastkey LIMIT n` is the paging query; `key`
  comparison is string comparison and matches the engine's key order.
- `SHOW TABLES` lists the workbench's own `zzlinks` table; the workbench must
  filter it out everywhere.
- The engine uses file handles #1-#4. The workbench may use #5+ for its own
  files but must close them before chaining.

## 7. Interaction model (user-approved)

Numbered screens with a typed command line at the bottom. A table list looks
like:

```
┌─────────────────────────────────────────────────────────────┐
│  MiniSQL Workbench                     DB: SHOP             │
├─────────────────────────────────────────────────────────────┤
│  1  customers     id,name,email,city              key       │
│  2  products      id,name,price,stock             key       │
│  3  orders        id,customer_id,date,status      key       │
│  4  order_lines   id,order_id,product_id,qty      key       │
│  5  suppliers     id,name,city                    key       │
│  6  shipments     id,order_id,carrier,date        key       │
│                                                             │
│  Links: orders.customer_id -> customers.id                  │
│         order_lines.order_id -> orders.id                   │
│         order_lines.product_id -> products.id               │
├─────────────────────────────────────────────────────────────┤
│  Number to open, N=new table, M=map, S=SQL, Q=quit          │
└─────────────────────────────────────────────────────────────┘
Selection:
```

Inside a table, commands are typed (e.g. `N`/`P` page, `E 3` edit row 3).
Every edit form prompts one field at a time; Enter keeps the current value.

## 8. Screens and flows

### 8.1 Start screen

- Title and a short hint.
- Recently used databases from `dbwork.dat`, numbered (max 10).
- Commands: number = open; `N` = open/create by name; `S` = seed sample SHOP
  database; `Q` = quit.
- Opening a database: uppercase the name, run `INITDB`, ensure `zzlinks`
  exists, move the name to the top of the recent list, write `dbwork.dat`, then
  show the table list.
- Empty recent list: show a welcome line and the `N` hint.

### 8.2 Table list (main screen)

- `SHOW TABLES`, filter `zzlinks`.
- For each table, `DESCRIBE` to get columns and key label; cache in
  `TN$(n)` (name) and `TC$(n)` (comma list).
- Do not count rows here (it costs one engine call per table).
- Commands: number = open table; `N` = new table; `M` = map; `S` = SQL console;
  `R` = refresh; `Q` = quit to BASIC.
- If there are no tables: "No tables yet. N creates one."

### 8.3 New table

1. Prompt table name. Validate: letters/digits/`-`/`_`, non-empty; let the
   engine enforce the length limit.
2. Prompt columns as a comma-separated list (e.g. `id,name,email,city`).
   Trim spaces; validate each name; reject duplicates and `key`.
3. `CREATE TABLE <name> (<cols>) PK KEY`.
4. On success, refresh the table list and open the new table's design.

### 8.4 Table design

Header: table name, key label, row count (`SELECT COUNT(*)`), and links that
touch this table.

Body: numbered column list. `KEY` is shown first as the engine's row key and
is not a user column. A footnote explains: "KEY is MiniSQL's row key; the other
columns are your data."

Commands:
- `A` = add column (prompt name, validate, `ALTER TABLE t ADD col`).
- `D n` = drop column n (confirm; `ALTER TABLE t DROP col`; remove links that
  use it).
- `L` = add link (from this table).
- `X n` = delete link n (from the links list).
- `B` = browse rows.
- `I` = insert row.
- `T` = drop table (confirm by typing the table name; remove its links;
  `DROP TABLE t`).
- `R` = refresh.
- `Q`/`B` = back to the table list.

### 8.5 Add link

From the current table:
1. Choose the from-column: numbered list of `KEY` + columns.
2. Choose the target table: numbered list of all tables except `zzlinks`
   (self-links are allowed, e.g. `categories.parent_id -> categories.id`).
3. Choose the target column: numbered list of `KEY` + that table's columns.
4. Insert into `zzlinks`: `INSERT INTO zzlinks VALUES (ftbl,fcol,ttbl,tcol)`
   (auto key). Validate both columns still exist first.
5. Refresh the table design.

Links are directional; the table design shows both incoming and outgoing links
with an arrow (`->` outgoing, `<-` incoming).

### 8.6 Row browser

- Page size 15 rows.
- Page 1: `SELECT * FROM t LIMIT 15`.
- Next page: `SELECT * FROM t WHERE key>lastkey LIMIT 15`.
- Display each row on one line: row number, `key=<value>`, then `col=value`
  pairs, truncated to 79 columns. Long values are cut with `..`.
- Commands: `N`/`P` = next/previous page; `V n` = view row n's fields one per
  line; `E n` = edit row n; `D n` = delete row n; `I` = insert row; `K key` =
  jump to a key; `B` = back; `R` = refresh.
- Empty table: "No rows. I inserts one."

### 8.7 View row

- Fetch the row by key: `SELECT * FROM t WHERE KEY=<k>`.
- Print each column and its value, one per line, paging if more than 18 lines.
- Enter returns to the browser.

### 8.8 Edit row

1. Fetch the current row by key.
2. Show the key read-only.
3. For each column, prompt `col [current]: `. Empty input keeps the current
   value. Type `@` alone to clear the field; `@@` stores a literal `@`.
   Reject values containing `,`, `|`, or `)` (see §11).
4. `REPLACE t KEY <k> VALUES (v1,v2,...)`.
5. Refresh the browser page.
6. The key cannot be changed in the edit form; changing a key means delete +
   insert (documented on the screen).

### 8.9 Insert row

1. Prompt key: `Key (blank = auto): `. If blank, use the auto-key form.
2. For each column, prompt the value. Reject `,` and `|`.
3. `INSERT INTO t [KEY <k>] VALUES (v1,v2,...)`.
4. Refresh the browser.

### 8.10 Delete row

- Prompt `Delete row n? (Y/N)`; only `Y` proceeds.
- `DELETE FROM t KEY <k>`.
- Refresh the browser.

### 8.11 Map

- Print every table with its columns (wrapped, one table per block).
- Print all links as `ftbl.fcol -> ttbl.tcol`.
- Print counts: tables, links.
- Page if the output exceeds 20 lines.
- Commands: `B` = back, `R` = refresh.

### 8.12 SQL console

- Prompt `SQL> `.
- Empty or `B` returns to the previous screen.
- `EXEC` the statement; print `SQL_STATUS`/`SQL_MSG$`; print results:
  - `COUNT=` → one line.
  - `TBL=` → table/columns/key lines.
  - rows → one line each, truncated to 79, paging every 20 lines.
- Errors in red; continue the console.

## 9. Data model

### 9.1 User tables

Ordinary MiniSQL tables. The engine's row key is always `key`; user columns are
whatever the design list contains.

### 9.2 Link metadata: `zzlinks`

A reserved MiniSQL table in each database:

```
CREATE TABLE zzlinks (ftbl,fcol,ttbl,tcol) PK KEY
```

- One row per link; auto-generated numeric key.
- `ftbl`/`fcol` = source table/column; `ttbl`/`tcol` = target table/column.
- Created automatically when a database is opened (status 33 "TABLE EXISTS" is
  ignored).
- Hidden from the table list, map table blocks, and SQL console examples; it is
  still visible if the user runs `SHOW TABLES` in the SQL console.
- Deleting a table or column removes links that reference it (the workbench
  scans `zzlinks`, deletes matching rows, and reports the count).
- `zzlinks` is reserved: creating a user table with that name is not supported.

### 9.3 Recent database registry: `dbwork.dat`

A global sequential file in the user's BASIC file area:

- One database name per line, most recent first, max 10.
- Read at startup; skip blanks; dedupe.
- Rewritten (FOR OUTPUT) whenever the list changes.
- Missing file is normal: start with an empty list and create it on first write.
- The registry stores logical names as the user typed them (uppercased).

## 10. Parsing and formatting helpers

The workbench needs a small parser library (reuse the patterns from
`minisql-demo.bas`):

- `GetToken` (delimiter, index) for comma/pipe splitting.
- `SplitLines` for `CHR$(10)`-separated results.
- `ParseRow` for `R|key|k|col=value|...` into arrays.
- `ParseDescribe` for `TBL=/COLS=/PK=`.
- `FormatRow` for the browser's one-line display (truncate to 79).
- `ShowResult`/`PageLines` for SQL console and map output.

Values are text. The workbench must reject `,` and `|` in any value before
building an engine statement; both characters are structural in MiniSQL's
record format.

## 11. Validation and safety

- Table names: letters/digits/`-`/`_`, non-empty; reject `zzlinks` and
  `_schema_meta`; reject engine-reserved words/substrings (`KEY`, `LIMIT`,
  `ORDER`, `WHERE`, `FROM`, `INTO`, `VALUES`, `SET`, `TABLE`, `LIKE`, `AND`,
  `OR`, `DROP`, `SHOW`, `DESCRIBE`, `ALTER`, `PK`).
- Column names: same character set; non-empty; reject `key`, duplicates, and
  the same reserved words/substrings (a column named `credit_limit` would be
  read as a `LIMIT` clause by the engine).
- Database names: letters/digits/`-`/`_` only; encoded length <= 20 characters
  (the longest generated file is `<db>_zzlinks.idx`). Recent-list entries are
  revalidated before opening.
- Values: no `,`, no `|`, no `)`; maximum 120 characters. The engine trims
  leading/trailing spaces, so the workbench tells the user that spaces at the
  ends are not preserved. v1 uses safe tokens only; it does not extend the
  engine with quoted values (user decision, 2026-11-15).
- Explicit key values: non-empty; letters/digits/`.`/`-`/`_` only (no spaces,
  no reserved substrings); auto-generated keys are the default.
- Refuse to drop the last user column; an externally created table with an
  empty column list is shown as `BROKEN` and left untouched.
- The SQL console refuses statements that name `zzlinks` or `_schema_meta`;
  other console DDL is allowed, and caches are refreshed afterwards.
- On startup, issue `ROLLBACK` to clear a leftover `batch.dat` transaction.
  After every `EXEC`, treat `QUEUED (TXN)` as an error and roll back.
- Destructive actions (drop column, drop table, delete row) require `Y` or the
  table name; default is No.
- Dropping a table/column warns how many links will be removed, then removes
  them.
- Every engine call checks `SQL_STATUS`; on error, show `SQL_MSG$` in red and
  return to the same screen without partial state changes.
- The workbench never leaves a file handle open across a `CHAIN`.

## 12. Performance and limits

- Each engine call is a program load (~0.5 s). The table list costs one
  `SHOW TABLES` plus one `DESCRIBE` per table; cache the result until `R`.
- Row counts are fetched only on the table design screen.
- The browser requests 15 rows per page, keeping `SQL_RESULT$` well under its
  cap.
- Paging uses `WHERE key>lastkey LIMIT 15`; the engine scans from the start each
  time, so deep pages cost more on large tables. Acceptable for the intended
  small/medium databases; document it.
- The map/SQL console page their output to avoid the 2048-byte string cap.
- v1 enforces 50 tables, 40 columns per table, 30 links, values <=120
  characters, and built statements <=1800 characters, with clear errors
  instead of overflowing arrays or the engine's 2048-byte string cap.
- Link cleanup pages through `zzlinks`; it never relies on one capped SELECT.
- `DESCRIBE` output is length-checked against the cap before it is parsed.

## 13. Sample database (seed)

Start screen `S` seeds a `SHOP` database:

- `customers (id,name,email,city)`
- `products (id,name,price,stock)`
- `orders (id,customer_id,date,status)`
- `order_lines (id,order_id,product_id,qty,price)`
- `suppliers (id,name,city)`
- `shipments (id,order_id,carrier,date)`

Plus links:

- `orders.customer_id -> customers.id`
- `order_lines.order_id -> orders.id`
- `order_lines.product_id -> products.id`
- `shipments.order_id -> orders.id`
- `products.supplier_id -> suppliers.id` (add `supplier_id` to products if the
  sample is used)

Plus 2-3 sample rows per table so the browser and map have content.

If `SHOP` already exists, the workbench asks before merging. The merge creates
missing tables and columns, adds missing links (checking for duplicates), and
inserts sample rows only into empty tables. Re-running `S` is therefore safe
and never duplicates rows or links.

## 14. Testing plan

The workbench is interactive, so tests are scripted x3270 sessions that feed
commands and assert screen text:

1. Fresh DB: open a new name, create 2 tables, add/drop a column, add/delete a
   link, verify via `DESCRIBE`/`SHOW TABLES` and the map.
2. Row CRUD: insert auto-key and explicit-key rows, browse pages, view, edit,
   delete; verify with direct MiniSQL `SELECT` calls and counts.
3. Validation: comma/pipe in a value rejected; bad table/column names rejected;
   `key` column rejected; duplicate key rejected by the engine and shown.
4. Safety: answer `N` to drop/delete → no change; answer `Y` → change.
5. Paging: create 40 rows, page forward/back, verify no duplicates/gaps.
6. Links: add a link, drop the referenced column → link disappears with a
   warning; drop a table → its links disappear.
7. Empty states: new DB with no tables; table with no rows.
8. SQL console: SELECT/COUNT/DESCRIBE/SHOW through the console; error path.
9. Sample seed: `S` creates SHOP; re-running it is idempotent.
10. Regression: the existing MiniSQL 14-test suite and behavioral verifiers
    still pass (the workbench only adds tables/data in its own DBs).

The builder should provide a repeatable script (host-side Python/x3270) that
runs the above and prints PASS/FAIL per scenario.

## 15. Deliverables

- `dbwork.bas` — the workbench (label mode, ≤71 cols, ASCII, no `_` in name).
- A scripted test harness (host-side, e.g. `test-dbwork.py`) and a short
  `dbwork` section in `README.md`/`user_manual.md`.
- No changes to `minisql.bas` unless a missing engine capability blocks a goal;
  if so, propose the change before making it.

## 16. Decisions already made

User-approved:
- Numbered screens with typed commands (not a spreadsheet).
- Links are shown on the map and in the table view.
- The small-shop example is the reference shape.

Builder calls (mine):
- Program name `dbwork.bas`; standalone, chains `minisql.bas`.
- Link metadata lives in a reserved MiniSQL table `zzlinks`.
- Recent databases live in `dbwork.dat`.
- Row paging uses engine queries (`LIMIT` + `WHERE key>lastkey`), not direct
  ISAM reads, in v1.
- No column types, no rename, no joins, no sorting in v1.
- The sample SHOP seed is part of v1.
- Values, keys, and names use safe tokens only; no engine quoting in v1
  (user decision).

## 17. What is left to the builder

- Exact screen layouts, colors, and prompt wording.
- Array sizes and cache structure.
- The parser/formatting helper implementation.
- The scripted test harness.
- Any performance tuning of paging that does not change behavior.

## 18. Builder-review resolutions

A fresh builder reviewed this document. Its questions are resolved here.

1. **Characters rejected in values.** User chose safe-token v1 on 2026-11-15:
   reject `,` `|` `)` and accept engine trimming; do not extend `minisql.bas`
   with quoted values in v1.
2. **Keywords and names.** v1 restricts table/column names and explicit keys
   to a safe token set and rejects engine-reserved words/substrings (see §11).
   Auto-generated keys are the default. If the user chooses natural text in
   item 1, this restriction is revisited.
3. **Database names.** Letters/digits/`-`/`_` only; encoded length <=20
   characters (longest file is `<db>_zzlinks.idx`, 12 chars plus prefix).
   Recent-list entries are revalidated before opening; invalid or too-long
   names are refused with a message.
4. **Size limits.** v1 enforces 50 tables, 40 columns per table, 30 links,
   values <=120 characters, and a built statement <=1800 characters, with
   clear errors. Link cleanup pages through `zzlinks`; the browser pages 15
   rows. `DESCRIBE` is checked against the cap.
5. **Last column.** Dropping the last user column is refused. A table found
   with an empty column list (created outside the workbench) is shown as
   `BROKEN`; the workbench refuses to edit it and tells the user to repair it
   with SQL/engine tools.
6. **Reserved names.** `zzlinks` and `_schema_meta` are refused in menus. The
   SQL console refuses statements that name them. Other console DDL is
   allowed; the workbench refreshes caches after each console statement and
   flags dangling links on the map with `!`.
7. **Sample seed.** `S` uses `SHOP`; if it exists, the workbench asks before
   merging. The merge creates missing tables/columns, adds missing links (no
   duplicates), and inserts sample rows only into empty tables. Re-running is
   safe.
8. **Self-links.** Allowed: the target table list includes the current table.
9. **Clearing a field.** In edit forms, `@` alone clears the field; `@@` stores
   a literal `@`.
10. **Transactions.** On startup the workbench issues `ROLLBACK` to clear any
    leftover batch. After every `EXEC`, a `QUEUED (TXN)` message is treated as
    an error and the batch is rolled back. Destructive operations are not
    atomic: the drop happens first, then link cleanup; if cleanup fails, the
    map flags the dangling links and the user can retry.

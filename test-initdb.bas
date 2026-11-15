REM ==============================================================
REM  test_initdb.bas   -   INITDB / database initialization test
REM ==============================================================
START:
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TSTINITDB"
SQL_MODE$ = "RW"

REM ---- Test 1: INITDB on fresh database ----
SQL_CMD$ = "INITDB"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM ---- Test 2: INITDB is idempotent ----
SQL_CMD$ = "INITDB"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM ---- Test 3: DB is usable after INITDB ----
SQL_CMD$ = "EXEC"
SQL_STMT$ = "CREATE TABLE fruit (name,color) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO fruit KEY apple"
SQL_STMT$ = SQL_STMT$ + " VALUES (Apple,Red)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "SELECT * FROM fruit WHERE KEY=apple"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "INITDB OK"
END

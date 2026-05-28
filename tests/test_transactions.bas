REM ==============================================================
REM  test_transactions.bas  —  BEGIN / COMMIT / ROLLBACK
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"

REM Create table outside txn
SQL_CMD$ = "EXEC"
SQL_STMT$ = "CREATE TABLE tst_txn (data) PK KEY"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM BEGIN
SQL_CMD$ = "BEGIN"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM Queue inserts
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO tst_txn KEY t1 VALUES (queued_one)"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst_txn KEY t2 VALUES (queued_two)"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM COMMIT
SQL_CMD$ = "COMMIT"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM Verify committed data
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT * FROM tst_txn ORDER BY KEY"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM Test ROLLBACK
SQL_CMD$ = "BEGIN"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO tst_txn KEY t3 VALUES (will_rollback)"
CHAIN "minisql"

SQL_CMD$ = "ROLLBACK"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM Verify t3 was rolled back
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT * FROM tst_txn WHERE KEY=t3"
CHAIN "minisql"
IF SQL_RESULT$ = "" THEN
    REM t3 not found - rollback worked
    SQL_STATUS = 0
    SQL_MSG$ = "TRANSACTIONS OK"
ELSE
    SQL_STATUS = 1
    SQL_MSG$ = "ROLLBACK FAILED: t3 still exists"
END IF
END

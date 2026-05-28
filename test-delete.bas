REM ==============================================================
REM  test_delete.bas  —  DELETE (KEY-based and bulk WHERE)
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-del (name,age) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst-del KEY r1 VALUES (Alice,25)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-del KEY r2 VALUES (Bob,30)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-del KEY r3 VALUES (Carol,22)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-del KEY r4 VALUES (Dave,35)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-del KEY r5 VALUES (Eve,28)"
CHAIN "minisql.bas"

REM KEY-based delete
SQL_STMT$ = "DELETE FROM tst-del KEY r1"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Bulk WHERE delete
SQL_STMT$ = "DELETE FROM tst-del WHERE age>30"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Verify remaining
SQL_STMT$ = "SELECT name,age FROM tst-del ORDER BY name ASC"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "DELETE FEATURES OK"
END

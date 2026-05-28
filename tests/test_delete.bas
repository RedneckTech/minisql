REM ==============================================================
REM  test_delete.bas  —  DELETE (KEY-based and bulk WHERE)
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst_del (name,age) PK KEY"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst_del KEY r1 VALUES (Alice,25)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_del KEY r2 VALUES (Bob,30)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_del KEY r3 VALUES (Carol,22)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_del KEY r4 VALUES (Dave,35)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_del KEY r5 VALUES (Eve,28)"
CHAIN "minisql"

REM KEY-based delete
SQL_STMT$ = "DELETE FROM tst_del KEY r1"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM Bulk WHERE delete
SQL_STMT$ = "DELETE FROM tst_del WHERE age>30"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM Verify remaining
SQL_STMT$ = "SELECT name,age FROM tst_del ORDER BY name ASC"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "DELETE FEATURES OK"
END

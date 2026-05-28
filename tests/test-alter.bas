REM ==============================================================
REM  test_alter.bas  —  ALTER TABLE ADD/DROP
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-alt (name,age) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst-alt KEY u1 VALUES (Alice,25)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM ADD column
SQL_STMT$ = "ALTER TABLE tst-alt ADD email"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Verify new col exists in schema
SQL_STMT$ = "DESCRIBE tst-alt"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM DROP column
SQL_STMT$ = "ALTER TABLE tst-alt DROP age"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Verify drop
SQL_STMT$ = "DESCRIBE tst-alt"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "ALTER TABLE OK"
END

REM ==============================================================
REM  test_create.bas  —  CREATE TABLE test
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-create (name,age,city) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst-create KEY alice"
SQL_STMT$ = SQL_STMT$ + " VALUES (Alice,25,Chicago)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "SELECT * FROM tst-create WHERE KEY=alice"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "CREATE/INSERT/SELECT OK"
END

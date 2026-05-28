REM ==============================================================
REM  test_show_describe.bas  —  SHOW TABLES and DESCRIBE
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

REM Create a couple tables for listing
SQL_STMT$ = "CREATE TABLE tst-shw1 (a,b) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "CREATE TABLE tst-shw2 (x,y,z) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM SHOW TABLES
SQL_STMT$ = "SHOW TABLES"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM DESCRIBE
SQL_STMT$ = "DESCRIBE tst-shw1"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "DESCRIBE tst-shw2"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "SHOW/DESCRIBE OK"
END

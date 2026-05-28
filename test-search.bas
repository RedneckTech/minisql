REM ==============================================================
REM  test_search.bas  —  SEARCH modes
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-srch (name,city,desc) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst-srch KEY r1"
SQL_STMT$ = SQL_STMT$ + " VALUES (Alice,Chicago,Hello World)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-srch KEY r2"
SQL_STMT$ = SQL_STMT$ + " VALUES (Bob,Boston,Good Morning)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-srch KEY r3"
SQL_STMT$ = SQL_STMT$ + " VALUES (Carol,Chicago,Hello Again)"
CHAIN "minisql.bas"

REM CONTAINS (default)
SQL_CMD$ = "SEARCH"
SQL_STMT$ = "tst-srch|Hello||"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM EXACT
SQL_STMT$ = "tst-srch|Chicago|city|EXACT"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM PREFIX
SQL_STMT$ = "tst-srch|Bos|city|PREFIX"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM SUFFIX
SQL_STMT$ = "tst-srch|ing|desc|SUFFIX"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "SEARCH MODES OK"
END

REM ==============================================================
REM  test_search.bas  —  SEARCH modes
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst_srch (name,city,desc) PK KEY"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst_srch KEY r1"
SQL_STMT$ = SQL_STMT$ + " VALUES (Alice,Chicago,Hello World)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_srch KEY r2"
SQL_STMT$ = SQL_STMT$ + " VALUES (Bob,Boston,Good Morning)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_srch KEY r3"
SQL_STMT$ = SQL_STMT$ + " VALUES (Carol,Chicago,Hello Again)"
CHAIN "minisql"

REM CONTAINS (default)
SQL_CMD$ = "SEARCH"
SQL_STMT$ = "tst_srch|Hello||"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM EXACT
SQL_STMT$ = "tst_srch|Chicago|city|EXACT"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM PREFIX
SQL_STMT$ = "tst_srch|Bos|city|PREFIX"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM SUFFIX
SQL_STMT$ = "tst_srch|ing|desc|SUFFIX"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "SEARCH MODES OK"
END

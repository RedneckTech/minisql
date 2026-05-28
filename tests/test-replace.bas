REM ==============================================================
REM  test_replace.bas  —  REPLACE (upsert)
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-rpl (name,val) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Insert initial
SQL_STMT$ = "INSERT INTO tst-rpl KEY k1 VALUES (first,100)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Replace (new key)
SQL_STMT$ = "REPLACE tst-rpl KEY k2 VALUES (second,200)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Replace (existing key - upsert)
SQL_STMT$ = "REPLACE tst-rpl KEY k1 VALUES (first_updated,150)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Verify
SQL_STMT$ = "SELECT * FROM tst-rpl ORDER BY KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "REPLACE OK"
END

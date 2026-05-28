REM ==============================================================
REM  test_insert.bas  —  INSERT with auto-increment keys
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-ins (label,val) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Auto-increment (no KEY)
SQL_STMT$ = "INSERT INTO tst-ins VALUES (first,100)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Auto-increment (KEY *)
SQL_STMT$ = "INSERT INTO tst-ins KEY * VALUES (second,200)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Explicit key
SQL_STMT$ = "INSERT INTO tst-ins KEY k3 VALUES (third,300)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Verify
SQL_STMT$ = "SELECT * FROM tst-ins"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "INSERT AUTO-KEYS OK"
END

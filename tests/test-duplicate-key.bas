REM ==============================================================
REM  test_duplicate_key.bas  —  Duplicate key rejection
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-dup (label) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Insert first record
SQL_STMT$ = "INSERT INTO tst-dup KEY mykey VALUES (hello)"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Try inserting same key (should FAIL with code 47)
SQL_STMT$ = "INSERT INTO tst-dup KEY mykey VALUES (world)"
CHAIN "minisql.bas"
IF SQL_STATUS = 47 THEN
    REM Expected - duplicate rejected
    SQL_STATUS = 0
    SQL_MSG$ = "DUPLICATE KEY (status 47) OK"
ELSE
    REM Unexpected - either no error or different error
    SQL_STATUS = 1
    SQL_MSG$ = "DUP KEY TEST FAIL: expected 47 got "
    SQL_MSG$ = SQL_MSG$ + STR$(SQL_STATUS)
END IF
END

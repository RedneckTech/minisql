REM ==============================================================
REM  test_update.bas  —  UPDATE (KEY-based, bulk WHERE, multi-col)
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-upd (name,age,score) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst-upd KEY a VALUES (Alice,25,80)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-upd KEY b VALUES (Bob,30,90)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-upd KEY c VALUES (Carol,22,85)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-upd KEY d VALUES (Dave,35,95)"
CHAIN "minisql.bas"

REM KEY-based single-col update
SQL_STMT$ = "UPDATE tst-upd KEY a SET age=26"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM KEY-based multi-col update
SQL_STMT$ = "UPDATE tst-upd KEY b SET age=31,score=91"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Bulk WHERE update
SQL_STMT$ = "UPDATE tst-upd SET score=100 WHERE age>25"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Verify
SQL_STMT$ = "SELECT name,age,score FROM tst-upd"
SQL_STMT$ = SQL_STMT$ + " ORDER BY name ASC"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "UPDATE FEATURES OK"
END

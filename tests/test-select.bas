REM ==============================================================
REM  test_select.bas  —  SELECT column filtering, DISTINCT, ORDER
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-sel (name,role,dept) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst-sel KEY u1 VALUES (Alice,dev,eng)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-sel KEY u2 VALUES (Bob,dev,eng)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-sel KEY u3 VALUES (Carol,mgr,hr)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-sel KEY u4 VALUES (Dave,dev,qc)"
CHAIN "minisql.bas"

REM Column filtering
SQL_STMT$ = "SELECT name,dept FROM tst-sel"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM DISTINCT
SQL_STMT$ = "SELECT DISTINCT role FROM tst-sel"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM ORDER BY
SQL_STMT$ = "SELECT * FROM tst-sel ORDER BY name ASC"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM ORDER BY DESC
SQL_STMT$ = "SELECT * FROM tst-sel ORDER BY name DESC"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM LIMIT
SQL_STMT$ = "SELECT * FROM tst-sel ORDER BY name ASC LIMIT 2"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Combined
SQL_STMT$ = "SELECT name,role FROM tst-sel"
SQL_STMT$ = SQL_STMT$ + " WHERE dept=eng ORDER BY name ASC"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Full table scan (no WHERE)
SQL_STMT$ = "SELECT * FROM tst-sel"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "SELECT FEATURES OK"
END

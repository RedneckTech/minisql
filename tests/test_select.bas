REM ==============================================================
REM  test_select.bas  —  SELECT column filtering, DISTINCT, ORDER
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst_sel (name,role,dept) PK KEY"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst_sel KEY u1 VALUES (Alice,dev,eng)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_sel KEY u2 VALUES (Bob,dev,eng)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_sel KEY u3 VALUES (Carol,mgr,hr)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_sel KEY u4 VALUES (Dave,dev,qc)"
CHAIN "minisql"

REM Column filtering
SQL_STMT$ = "SELECT name,dept FROM tst_sel"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM DISTINCT
SQL_STMT$ = "SELECT DISTINCT role FROM tst_sel"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM ORDER BY
SQL_STMT$ = "SELECT * FROM tst_sel ORDER BY name ASC"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM ORDER BY DESC
SQL_STMT$ = "SELECT * FROM tst_sel ORDER BY name DESC"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM LIMIT
SQL_STMT$ = "SELECT * FROM tst_sel ORDER BY name ASC LIMIT 2"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM Combined
SQL_STMT$ = "SELECT name,role FROM tst_sel"
SQL_STMT$ = SQL_STMT$ + " WHERE dept=eng ORDER BY name ASC"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM Full table scan (no WHERE)
SQL_STMT$ = "SELECT * FROM tst_sel"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "SELECT FEATURES OK"
END

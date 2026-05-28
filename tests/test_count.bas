REM ==============================================================
REM  test_count.bas  —  SELECT COUNT(*) aggregate
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst_cnt (label,val) PK KEY"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst_cnt KEY a VALUES (alpha,10)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_cnt KEY b VALUES (beta,20)"
CHAIN "minisql"
SQL_STMT$ = "INSERT INTO tst_cnt KEY c VALUES (gamma,30)"
CHAIN "minisql"

REM COUNT all
SQL_STMT$ = "SELECT COUNT(*) FROM tst_cnt"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM COUNT with WHERE
SQL_STMT$ = "SELECT COUNT(*) FROM tst_cnt WHERE val>10"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

REM COUNT with WHERE and comparison
SQL_STMT$ = "SELECT COUNT(*) FROM tst_cnt WHERE val>=10"
SQL_STMT$ = SQL_STMT$ + " AND val<=30"
CHAIN "minisql"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "COUNT OK"
END

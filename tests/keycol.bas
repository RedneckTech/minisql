REM ==============================================================
REM  keycol.bas  -  reserved column name 'key' is rejected
REM ==============================================================
START:
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$
PASS = 0
FAIL = 0
SQL_DB$ = "KEYCOL"
SQL_MODE$ = "RW"
SQL_CMD$ = "INITDB"
CHAIN "minisql.bas"
SQL_CMD$ = "EXEC"
SQL_STMT$ = "CREATE TABLE kt (key,x) PK KEY"
CHAIN "minisql.bas"
TEST$ = "reject key first"
WSTAT = 32
GOSUB CKST
SQL_STMT$ = "CREATE TABLE kt2 (x) PK KEY"
CHAIN "minisql.bas"
TEST$ = "normal table ok"
WSTAT = 0
GOSUB CKST
SQL_STMT$ = "ALTER TABLE kt2 ADD key"
CHAIN "minisql.bas"
TEST$ = "reject alter key"
WSTAT = 87
GOSUB CKST
SQL_STMT$ = "CREATE TABLE kt3 (a,KEY) PK KEY"
CHAIN "minisql.bas"
TEST$ = "reject upper KEY"
WSTAT = 32
GOSUB CKST
SQL_STMT$ = "CREATE TABLE ok (key2,x) PK KEY"
CHAIN "minisql.bas"
TEST$ = "key2 allowed"
WSTAT = 0
GOSUB CKST
SQL_STMT$ = "INSERT INTO ok KEY a VALUES (v1,v2)"
CHAIN "minisql.bas"
TEST$ = "insert ok"
WSTAT = 0
GOSUB CKST
SQL_STMT$ = "SELECT * FROM ok WHERE KEY=a"
CHAIN "minisql.bas"
TEST$ = "select ok"
WSTAT = 0
GOSUB CKST
IF SQL_RESULT$ = "R|key|a|key2=v1|x=v2" + CHR$(10) THEN
    PASS = PASS + 1
ELSE
    FAIL = FAIL + 1
    PRINT "FAIL result=["; SQL_RESULT$; "]"
END IF
SQL_STMT$ = "CREATE TABLE badc (a=b,x) PK KEY"
CHAIN "minisql.bas"
TEST$ = "reject eq col"
WSTAT = 32
GOSUB CKST
SQL_STMT$ = "CREATE TABLE badc2 (a|b) PK KEY"
CHAIN "minisql.bas"
TEST$ = "reject pipe col"
WSTAT = 32
GOSUB CKST
SQL_STMT$ = "CREATE TABLE badc3 (a b) PK KEY"
CHAIN "minisql.bas"
TEST$ = "reject space col"
WSTAT = 32
GOSUB CKST
SQL_STMT$ = "CREATE TABLE goodc (a-b,a_b) PK KEY"
CHAIN "minisql.bas"
TEST$ = "dash/underscore cols"
WSTAT = 0
GOSUB CKST
SQL_STMT$ = "ALTER TABLE kt2 ADD b=c"
CHAIN "minisql.bas"
TEST$ = "reject alter eq"
WSTAT = 87
GOSUB CKST
PRINT ""
PRINT "KEYCOL RESULTS"
PRINT "PASS: "; PASS
PRINT "FAIL: "; FAIL
IF FAIL = 0 THEN PRINT "ALL CHECKS PASSED"
IF FAIL > 0 THEN PRINT "THERE ARE FAILURES"
END
CKST:
    IF SQL_STATUS = WSTAT THEN
        PASS = PASS + 1
    ELSE
        FAIL = FAIL + 1
        PRINT "FAIL "; TEST$; " ST="; SQL_STATUS; " WANT="; WSTAT
        PRINT "  MSG="; SQL_MSG$
    END IF
    RETURN

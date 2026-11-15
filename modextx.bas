REM ==============================================================
REM  modextx.bas  -  RO/AO mode must block queued transactions
REM ==============================================================
START:
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$
PASS = 0
FAIL = 0
SQL_DB$ = "MODEXTX"
SQL_MODE$ = "RW"
SQL_CMD$ = "INITDB"
CHAIN "minisql.bas"
SQL_CMD$ = "EXEC"
SQL_STMT$ = "CREATE TABLE mt (v) PK KEY"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO mt KEY a VALUES (one)"
CHAIN "minisql.bas"
SQL_MODE$ = "RO"
SQL_CMD$ = "BEGIN"
CHAIN "minisql.bas"
TEST$ = "RO BEGIN"
WSTAT = 0
GOSUB CKST
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO mt KEY b VALUES (two)"
CHAIN "minisql.bas"
TEST$ = "RO queue denied"
WSTAT = 20
GOSUB CKST
SQL_CMD$ = "ROLLBACK"
CHAIN "minisql.bas"
SQL_MODE$ = "RO"
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT COUNT(*) FROM mt"
CHAIN "minisql.bas"
TEST$ = "RO count after deny"
WSTAT = 0
GOSUB CKST
IF SQL_RESULT$ = "COUNT=1" THEN
    PASS = PASS + 1
ELSE
    FAIL = FAIL + 1
    PRINT "FAIL count=["; SQL_RESULT$; "]"
END IF
SQL_MODE$ = "AO"
SQL_CMD$ = "BEGIN"
CHAIN "minisql.bas"
TEST$ = "AO BEGIN"
WSTAT = 0
GOSUB CKST
SQL_CMD$ = "EXEC"
SQL_STMT$ = "UPDATE mt KEY a SET v=x"
CHAIN "minisql.bas"
TEST$ = "AO update denied"
WSTAT = 21
GOSUB CKST
SQL_CMD$ = "ROLLBACK"
CHAIN "minisql.bas"
SQL_MODE$ = "AO"
SQL_CMD$ = "EXEC"
SQL_STMT$ = "INSERT INTO mt KEY c VALUES (three)"
CHAIN "minisql.bas"
TEST$ = "AO insert allowed"
WSTAT = 0
GOSUB CKST
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"
SQL_STMT$ = "SELECT COUNT(*) FROM mt"
CHAIN "minisql.bas"
TEST$ = "RW count final"
WSTAT = 0
GOSUB CKST
IF SQL_RESULT$ = "COUNT=2" THEN
    PASS = PASS + 1
ELSE
    FAIL = FAIL + 1
    PRINT "FAIL final count=["; SQL_RESULT$; "]"
END IF
SQL_MODE$ = "RO"
SQL_CMD$ = "COMMIT"
CHAIN "minisql.bas"
TEST$ = "RO commit empty"
WSTAT = 0
GOSUB CKST
IF SQL_MSG$ = "NO TXN" THEN
    PASS = PASS + 1
ELSE
    FAIL = FAIL + 1
    PRINT "FAIL commit msg=["; SQL_MSG$; "]"
END IF
PRINT ""
PRINT "MODE+TX RESULTS"
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

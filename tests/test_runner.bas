REM ==============================================================
REM  MiniSQL Test Runner  —  runs all test*.bas programs
REM ==============================================================
REM  Usage: CHAIN "tests/test_runner"  (or RUN from BASIC)
REM
REM  Each test creates its own table(s) prefixed with "tst_" and
REM  cleans up before exiting.  The runner prints PASS/FAIL for
REM  each test based on SQL_STATUS and expected output.
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

TESTDB$ = "TESTSUITE"
PASS = 0
FAIL = 0

REM ---- Init once ----
SQL_DB$ = TESTDB$
SQL_MODE$ = "RW"
SQL_CMD$ = "INITDB"
CHAIN "minisql"
PRINT "=== MiniSQL Test Suite ==="
PRINT "DB: "; TESTDB$
PRINT ""

REM ---- Test list ----
DIM TN$(20)
TN$(1) = "test_create"
TN$(2) = "test_insert"
TN$(3) = "test_select"
TN$(4) = "test_where"
TN$(5) = "test_update"
TN$(6) = "test_delete"
TN$(7) = "test_alter"
TN$(8) = "test_count"
TN$(9) = "test_show_describe"
TN$(10) = "test_replace"
TN$(11) = "test_duplicate_key"
TN$(12) = "test_transactions"
TN$(13) = "test_search"
TOTAL = 13

FOR TI = 1 TO TOTAL
    PRINT "["; TI; "/"; TOTAL; "] Running "; TN$(TI); "..."
    SQL_CMD$ = "EXEC"
    SQL_STMT$ = "DELETE FROM tst_meta KEY " + TN$(TI)
    CHAIN "minisql"
    SQL_STMT$ = "INSERT INTO tst_meta KEY " + TN$(TI)
    SQL_STMT$ = SQL_STMT$ + " VALUES (running)"
    CHAIN "minisql"
    
    CHAIN "tests/" + TN$(TI)
    
    IF SQL_STATUS = 0 THEN
        PRINT "  PASS"; TAB(40); SQL_MSG$
        PASS = PASS + 1
    ELSE
        PRINT "  FAIL code="; SQL_STATUS; SQL_MSG$
        FAIL = FAIL + 1
    END IF
NEXT TI

PRINT ""
PRINT "=== Results ==="
PRINT "PASS: "; PASS
PRINT "FAIL: "; FAIL
PRINT "TOTAL: "; TOTAL
PRINT "=== Done ==="
END

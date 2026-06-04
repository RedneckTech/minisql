REM ==============================================================
REM  MiniSQL Test Runner  —  runs all test*.bas programs
REM ==============================================================
START:
REM  Usage: CHAIN "test-runner.bas"  (or RUN from BASIC)
REM
REM  Each test creates its own table(s) prefixed with "tst-" and
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
CHAIN "minisql.bas"
PRINT "=== MiniSQL Test Suite ==="
PRINT "DB: "; TESTDB$
PRINT ""

REM ---- Test list ----
DIM TN$(20)
TN$(1) = "test-initdb"
TN$(2) = "test-create"
TN$(3) = "test-insert"
TN$(4) = "test-select"
TN$(5) = "test-where"
TN$(6) = "test-update"
TN$(7) = "test-delete"
TN$(8) = "test-alter"
TN$(9) = "test-count"
TN$(10) = "test-show-describe"
TN$(11) = "test-replace"
TN$(12) = "test-duplicate-key"
TN$(13) = "test-transactions"
TN$(14) = "test-search"
TOTAL = 14

FOR TI = 1 TO TOTAL
    PRINT "["; TI; "/"; TOTAL; "] Running "; TN$(TI); "..."
    
    CHAIN TN$(TI) + ".bas"
    
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

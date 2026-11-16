REM ==============================================================
REM  verify3a.bas   -   MiniSQL verification part
REM  Checks SQL_RESULT$ contents and status codes for every
REM  feature.  Prints one progress line per check, details on
REM  failure, and a final PASS/FAIL summary.
REM ==============================================================
START:
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

PASS = 0
FAIL = 0
LF$ = CHR$(10)
SQL_DB$ = "VERIFY3A"
SQL_MODE$ = "RW"
SQL_CMD$ = "INITDB"
GOSUB T_RUNSQL
TEST$ = "C00 INITDB"
GOSUB T_SHOW
WSTAT = 0
GOSUB T_CKST

REM ---------- setup table v1 ----------
TEST$ = "C00B CREATE v1"
GOSUB T_SHOW
SQL_STMT$ = "CREATE TABLE v1 (name,age,city) PK KEY"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST
TEST$ = "C00C INSERT r1"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO v1 KEY r1 VALUES (Alice,25,Chicago)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST
TEST$ = "C00D INSERT r2"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO v1 KEY r2 VALUES (Bob,30,Boston)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST
TEST$ = "C00E INSERT r3"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO v1 KEY r3 VALUES (Carol,22,Chicago)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST
TEST$ = "C00F INSERT r4"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO v1 KEY r4 VALUES (Dave,35,Denver)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST
TEST$ = "C00G INSERT r5"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO v1 KEY r5 VALUES (Eve,28,Austin)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST

REM ---------- SELECT / WHERE ----------
TEST$ = "C42 REPLACE new key"
GOSUB T_SHOW
SQL_STMT$ = "REPLACE v1 KEY r9 VALUES (Zoe,20,Miami)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST

TEST$ = "C43 verify replace new"
GOSUB T_SHOW
SQL_STMT$ = "SELECT * FROM v1 WHERE KEY=r9"
GOSUB T_EXEC
WANT$ = "R|key|r9|name=Zoe|age=20|city=Miami" + LF$
GOT$ = SQL_RESULT$
GOSUB T_CKEQ

TEST$ = "C44 REPLACE existing"
GOSUB T_SHOW
SQL_STMT$ = "REPLACE v1 KEY r9 VALUES (Zoe2,21,Tampa)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST

TEST$ = "C45 verify replace existing"
GOSUB T_SHOW
SQL_STMT$ = "SELECT * FROM v1 WHERE KEY=r9"
GOSUB T_EXEC
WANT$ = "R|key|r9|name=Zoe2|age=21|city=Tampa" + LF$
GOT$ = SQL_RESULT$
GOSUB T_CKEQ

REM ---------- ALTER ----------
TEST$ = "C46 ALTER ADD"
GOSUB T_SHOW
SQL_STMT$ = "ALTER TABLE v1 ADD email"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST

TEST$ = "C47 DESCRIBE after add"
GOSUB T_SHOW
SQL_STMT$ = "DESCRIBE v1"
GOSUB T_EXEC
WANT$ = "COLS=name,age,city,email": GOSUB T_CKCONT

TEST$ = "C48 old row empty new col"
GOSUB T_SHOW
SQL_STMT$ = "SELECT * FROM v1 WHERE KEY=r9"
GOSUB T_EXEC
WANT$ = "R|key|r9|name=Zoe2|age=21|city=Tampa|email=" + LF$
GOT$ = SQL_RESULT$
GOSUB T_CKEQ

TEST$ = "C49 INSERT with new col"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO v1 KEY r10"
SQL_STMT$ = SQL_STMT$ + " VALUES (Amy,23,Boise,amy@x)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST
SQL_STMT$ = "SELECT * FROM v1 WHERE KEY=r10"
GOSUB T_EXEC
WANT$ = "email=amy@x": GOSUB T_CKCONT

TEST$ = "C50 ALTER ADD dup col"
GOSUB T_SHOW
SQL_STMT$ = "ALTER TABLE v1 ADD email"
GOSUB T_EXEC
WSTAT = 87
GOSUB T_CKST

TEST$ = "C51 ALTER DROP"
GOSUB T_SHOW
SQL_STMT$ = "ALTER TABLE v1 DROP city"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST

TEST$ = "C52 DESCRIBE after drop"
GOSUB T_SHOW
SQL_STMT$ = "DESCRIBE v1"
GOSUB T_EXEC
WANT$ = "COLS=name,age,email": GOSUB T_CKCONT
WANT$ = "city": GOSUB T_CKABS

TEST$ = "C53 dropped col hidden"
GOSUB T_SHOW
SQL_STMT$ = "SELECT * FROM v1 WHERE KEY=r9"
GOSUB T_EXEC
WANT$ = "|city=": GOSUB T_CKABS

TEST$ = "C54 ALTER DROP PK"
GOSUB T_SHOW
SQL_STMT$ = "ALTER TABLE v1 DROP key"
GOSUB T_EXEC
WSTAT = 87
GOSUB T_CKST

TEST$ = "C55 ALTER DROP missing"
GOSUB T_SHOW
SQL_STMT$ = "ALTER TABLE v1 DROP nosuch"
GOSUB T_EXEC
WSTAT = 87
GOSUB T_CKST

TEST$ = "C56 ALTER no action"
GOSUB T_SHOW
SQL_STMT$ = "ALTER TABLE v1"
GOSUB T_EXEC
WSTAT = 87
GOSUB T_CKST

REM ---------- SHOW / DESCRIBE ----------
REM ---------- summary ----------
PRINT ""
PRINT "VERIFY RESULTS"
PRINT "PASS: "; PASS
PRINT "FAIL: "; FAIL
IF FAIL = 0 THEN PRINT "ALL CHECKS PASSED"
IF FAIL > 0 THEN PRINT "THERE ARE FAILURES"
END

REM ==============================================================
REM  Helper routines
REM ==============================================================
T_RUNSQL:
    SQL_STATUS = 0
    SQL_MSG$ = ""
    SQL_RESULT$ = ""
    CHAIN "minisql.bas"
    RETURN

T_EXEC:
    SQL_CMD$ = "EXEC"
    GOSUB T_RUNSQL
    RETURN

T_SHOW:
    PRINT ".";
    RETURN

T_CKST:
    IF SQL_STATUS = WSTAT THEN
        PASS = PASS + 1
    ELSE
        FAIL = FAIL + 1
        PRINT "  FAIL STATUS="; SQL_STATUS; " WANT="; WSTAT
        PRINT "  MSG="; SQL_MSG$
    END IF
    RETURN

T_CKEQ:
    IF GOT$ = WANT$ THEN
        PASS = PASS + 1
    ELSE
        FAIL = FAIL + 1
        PRINT "  FAIL WANT=["; LEFT$(WANT$, 100); "]"
        PRINT "  FAIL GOT =["; LEFT$(GOT$, 100); "]"
    END IF
    RETURN

T_CKCONT:
    IF INSTR(SQL_RESULT$, WANT$) > 0 THEN
        PASS = PASS + 1
    ELSE
        FAIL = FAIL + 1
        PRINT "  FAIL MISSING ["; LEFT$(WANT$, 100); "]"
        PRINT "  RESULT=["; LEFT$(SQL_RESULT$, 100); "]"
    END IF
    RETURN

T_CKMSG:
    IF INSTR(SQL_MSG$, WANT$) > 0 THEN
        PASS = PASS + 1
    ELSE
        FAIL = FAIL + 1
        PRINT "  FAIL MSG MISSING ["; WANT$; "]"
        PRINT "  MSG=["; SQL_MSG$; "]"
    END IF
    RETURN

T_CKABS:
    IF INSTR(SQL_RESULT$, WANT$) = 0 THEN
        PASS = PASS + 1
    ELSE
        FAIL = FAIL + 1
        PRINT "  FAIL FOUND ["; LEFT$(WANT$, 100); "]"
        PRINT "  RESULT=["; LEFT$(SQL_RESULT$, 100); "]"
    END IF
    RETURN

T_ROWS:
    ROWCNT = LEN(SQL_RESULT$) - LEN(REPLACE$(SQL_RESULT$, LF$, ""))
    RETURN

T_OCC:
    OCC = 0
    IF LEN(WANT$) > 0 THEN
        OCC = (LEN(SQL_RESULT$) - LEN(REPLACE$(SQL_RESULT$, WANT$, "")))
        OCC = OCC / LEN(WANT$)
    END IF
    RETURN

T_CKNUM:
    IF GOTN = WANTN THEN
        PASS = PASS + 1
    ELSE
        FAIL = FAIL + 1
        PRINT "  FAIL NUM="; GOTN; " WANT="; WANTN
        PRINT "  RESULT=["; LEFT$(SQL_RESULT$, 100); "]"
    END IF
    RETURN

T_CKPOS:
    IF GOTN > 0 AND WANTN > 0 AND GOTN < WANTN THEN
        PASS = PASS + 1
    ELSE
        FAIL = FAIL + 1
        PRINT "  FAIL POS "; GOTN; " NOT BEFORE "; WANTN
        PRINT "  RESULT=["; LEFT$(SQL_RESULT$, 100); "]"
    END IF
    RETURN

REM ==============================================================
REM  verify3b.bas   -   MiniSQL verification part
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
SQL_DB$ = "VERIFY3B"
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
TEST$ = "C57 SHOW TABLES"
GOSUB T_SHOW
SQL_STMT$ = "SHOW TABLES"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST
WANT$ = "v1": GOSUB T_CKCONT
WANT$ = "_schema_meta": GOSUB T_CKABS

TEST$ = "C58 DESCRIBE missing tbl"
GOSUB T_SHOW
SQL_STMT$ = "DESCRIBE nosuch"
GOSUB T_EXEC
WSTAT = 51
GOSUB T_CKST

TEST$ = "C59 DESCRIBE empty"
GOSUB T_SHOW
SQL_STMT$ = "DESCRIBE"
GOSUB T_EXEC
WSTAT = 89
GOSUB T_CKST

REM ---------- AUTO-INCREMENT ----------
TEST$ = "C60 CREATE vseq"
GOSUB T_SHOW
SQL_STMT$ = "CREATE TABLE vseq (label) PK KEY"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST

TEST$ = "C61 auto key starts 1"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO vseq VALUES (one)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST
SQL_STMT$ = "SELECT * FROM vseq WHERE KEY=1"
GOSUB T_EXEC
WANT$ = "R|key|1|label=one": GOSUB T_CKCONT

TEST$ = "C62 auto key 2"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO vseq VALUES (two)"
GOSUB T_EXEC
SQL_STMT$ = "SELECT * FROM vseq WHERE KEY=2"
GOSUB T_EXEC
WANT$ = "R|key|2|label=two": GOSUB T_CKCONT

TEST$ = "C63 auto key 3 star"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO vseq KEY * VALUES (three)"
GOSUB T_EXEC
SQL_STMT$ = "SELECT * FROM vseq WHERE KEY=3"
GOSUB T_EXEC
WANT$ = "R|key|3|label=three": GOSUB T_CKCONT

TEST$ = "C64 explicit key 10"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO vseq KEY 10 VALUES (ten)"
GOSUB T_EXEC
WSTAT = 0
GOSUB T_CKST

TEST$ = "C65 auto key 4"
GOSUB T_SHOW
SQL_STMT$ = "INSERT INTO vseq VALUES (four)"
GOSUB T_EXEC
SQL_STMT$ = "SELECT * FROM vseq WHERE KEY=4"
GOSUB T_EXEC
WANT$ = "R|key|4|label=four": GOSUB T_CKCONT

TEST$ = "C66 count vseq"
GOSUB T_SHOW
SQL_STMT$ = "SELECT COUNT(*) FROM vseq"
GOSUB T_EXEC
WANT$ = "COUNT=5"
GOT$ = SQL_RESULT$
GOSUB T_CKEQ

REM ---------- SEARCH ----------
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

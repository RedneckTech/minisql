REM ==============================================================
REM  MINISQL.BAS  (LABEL-BASED / CHAINABLE)
REM  Version: 0.3.24
REM --------------------------------------------------------------
REM  Uses COMMON + CHAIN library style. When this program ENDs,
REM  control returns to the caller after CHAIN, with COMMON kept.
REM
REM  FILENAMES: underscores are NOT used. We use dashes:
REM    <DB>-idx.dat   (schemas, index, metadata)
REM    <DB>-db1.dat   (data, max 10KB per file)
REM    <DB>-db2.dat ...
REM    <DB>-txn.dat   (transaction batch file)
REM
REM  FILE HANDLE LIMIT: only #1..#4 may be open at once, so we
REM  keep at most 1-2 open and CLOSE quickly.
REM
REM  WATCHDOG SAFE: loops call SLEEP(0.25).
REM
REM  COMMON API:
REM    SQL_CMD$    = "INITDB"|"EXEC"|"BEGIN"|"COMMIT"|"ROLLBACK"|"SEARCH"|"COMPACT"|"REINDEX"
REM    SQL_DB$     = database prefix (we sanitize '_' -> '-' for filenames)
REM    SQL_STMT$   = SQL statement (EXEC) or search spec (SEARCH)
REM    SQL_MODE$   = "RW" default | "RO" read-only | "AO" append-only
REM
REM  OUTPUTS:
REM    SQL_STATUS  = 0 ok, nonzero error
REM    SQL_MSG$    = message
REM    SQL_RESULT$ = results (lines separated by CHR$(10))
REM ==============================================================
REM Copyright 2025 by FARMER. ALL rights reserved

START:
    COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$, SQL_STATUS, SQL_MSG$

    SQL_STATUS = 0
    SQL_MSG$ = ""
    SQL_RESULT$ = ""

    MAXFILE = 10240
    YIELDSEC = 0.25

    CMD$ = UCASE$(TRIM$(SQL_CMD$))
    IF SQL_MODE$ = "" THEN SQL_MODE$ = "RW"
    SQL_MODE$ = UCASE$(SQL_MODE$)

    IF SQL_DB$ = "" THEN
        SQL_STATUS = 10
        SQL_MSG$ = "SQL_DB$ REQUIRED"
        END
    END IF

    GOSUB SanitizeDB
    GOSUB BuildNames

    SELECT CASE CMD$
        CASE "INITDB"
            GOSUB InitDB
        CASE "EXEC"
            GOSUB ExecSQL
        CASE "BEGIN"
            GOSUB TxnBegin
        CASE "COMMIT"
            GOSUB TxnCommit
        CASE "ROLLBACK"
            GOSUB TxnRollback
        CASE "SEARCH"
            GOSUB SearchCmd
        CASE "COMPACT"
            GOSUB CompactIdx
        CASE "REINDEX"
            GOSUB ReindexAll
        CASE ELSE
            SQL_STATUS = 99
            SQL_MSG$ = "UNKNOWN CMD"
    END SELECT

    END


REM ==============================================================
REM  Helpers: sanitize DB name for filenames ( '_' -> '-' )
REM ==============================================================
SanitizeDB:
    DBPFX$ = ""
    FOR I = 1 TO LEN(SQL_DB$)
        C$ = MID$(SQL_DB$, I, 1)
        IF C$ = "_" THEN C$ = "-"
        DBPFX$ = DBPFX$ + C$
    NEXT I
    RETURN


REM ==============================================================
REM  Helpers: build filenames
REM ==============================================================
BuildNames:
    IDXFN$ = DBPFX$ + "-idx.dat"
    TXNFN$ = DBPFX$ + "-txn.dat"
    RETURN

MakeDBName:
    REM IN: FN  OUT: DBFN$
    DBFN$ = DBPFX$ + "-db" + STR$(FN) + ".dat"
    RETURN


REM ==============================================================
REM  INITDB: create idx + db1 if missing, seed metadata if idx empty
REM ==============================================================
InitDB:
    REM Create idx and db1 by APPEND open (creates file if missing)
    OPEN IDXFN$ FOR APPEND AS #1
    CLOSE #1

    FN = 1
    GOSUB MakeDBName
    OPEN DBFN$ FOR APPEND AS #1
    CLOSE #1

    REM Check if idx is empty
    EMPTY = 1
    OPEN IDXFN$ FOR INPUT AS #1
    IF EOF(1) THEN
        CLOSE #1
    ELSE
        INPUT #1, L$
        IF TRIM$(L$) <> "" THEN EMPTY = 0
        CLOSE #1
    END IF

    IF EMPTY = 0 THEN
        SQL_MSG$ = "INITDB OK (EXISTS)"
        RETURN
    END IF

    REM Seed metadata
    OPEN IDXFN$ FOR APPEND AS #1
    PRINT #1, "M|CUR|1"
    PRINT #1, "M|TXN|0"
    PRINT #1, "F|1|0"
    PRINT #1, "R|1|0"
    CLOSE #1

    SQL_MSG$ = "INITDB OK (CREATED)"
    RETURN


REM ==============================================================
REM  Index meta readers (scan idx; latest wins)
REM ==============================================================
GetMeta:
    REM IN: METAKEY$ ("CUR" or "TXN")  OUT: METAVAL$
    METAVAL$ = ""
    OPEN IDXFN$ FOR INPUT AS #1
    N = 0
    WHILE NOT EOF(1)
        INPUT #1, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)   REM watchdog-safe
        L$ = TRIM$(L$)
        IF INSTR(L$, "M|" + METAKEY$ + "|") = 1 THEN
            METAVAL$ = MID$(L$, LEN("M|" + METAKEY$ + "|") + 1)
        END IF
    WEND
    CLOSE #1
    RETURN

GetFileBytes:
    REM IN: FN  OUT: BYTES
    BYTES = 0
    OPEN IDXFN$ FOR INPUT AS #1
    N = 0
    WHILE NOT EOF(1)
        INPUT #1, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        IF INSTR(L$, "F|" + STR$(FN) + "|") = 1 THEN
            BYTES = VAL(MID$(L$, LEN("F|" + STR$(FN) + "|") + 1))
        END IF
    WEND
    CLOSE #1
    RETURN

GetFileRecMax:
    REM IN: FN  OUT: RMAX
    RMAX = 0
    OPEN IDXFN$ FOR INPUT AS #1
    N = 0
    WHILE NOT EOF(1)
        INPUT #1, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        IF INSTR(L$, "R|" + STR$(FN) + "|") = 1 THEN
            RMAX = VAL(MID$(L$, LEN("R|" + STR$(FN) + "|") + 1))
        END IF
    WEND
    CLOSE #1
    RETURN

GetSchema:
    REM IN: TBL$  OUT: COLS$, PK$
    COLS$ = ""
    PK$ = ""
    OPEN IDXFN$ FOR INPUT AS #1
    N = 0
    WHILE NOT EOF(1)
        INPUT #1, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        IF INSTR(L$, "S|" + TBL$ + "|") = 1 THEN
            REM S|table|cols|pk
            REST$ = MID$(L$, LEN("S|" + TBL$ + "|") + 1)
            P = INSTR(REST$, "|")
            IF P > 0 THEN
                COLS$ = LEFT$(REST$, P-1)
                PK$ = MID$(REST$, P+1)
            END IF
        END IF
    WEND
    CLOSE #1
    RETURN


REM ==============================================================
REM  Load index for one table into associative array:
REM    IDX{"key"} = "file,rec"  (0,0 means deleted)
REM ==============================================================
LoadIndexForTable:
    DIM IDX{}
    OPEN IDXFN$ FOR INPUT AS #1
    N = 0
    WHILE NOT EOF(1)
        INPUT #1, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        L$ = TRIM$(L$)
        IF INSTR(L$, "I|" + TBL$ + "|") = 1 THEN
            REM I|table|key|file|rec
            REST$ = MID$(L$, LEN("I|" + TBL$ + "|") + 1)
            P1 = INSTR(REST$, "|")
            IF P1 > 0 THEN
                KEY$ = LEFT$(REST$, P1-1)
                REST2$ = MID$(REST$, P1+1)
                P2 = INSTR(REST2$, "|")
                IF P2 > 0 THEN
                    F$ = LEFT$(REST2$, P2-1)
                    R$ = MID$(REST2$, P2+1)
                    IDX{KEY$} = F$ + "," + R$
                END IF
            END IF
        END IF
    WEND
    CLOSE #1
    RETURN


REM ==============================================================
REM  Fetch record by (file,rec)
REM ==============================================================
FetchByPos:
    REM IN: FNO, RNO  OUT: OUT$
    OUT$ = ""
    IF FNO <= 0 OR RNO <= 0 THEN RETURN
    FN = FNO
    GOSUB MakeDBName
    OPEN DBFN$ FOR INPUT AS #1
    I = 0
    WHILE NOT EOF(1)
        INPUT #1, L$
        I = I + 1
        IF (I MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        IF I = RNO THEN OUT$ = L$: CLOSE #1: RETURN
    WEND
    CLOSE #1
    OUT$ = ""
    RETURN


REM ==============================================================
REM  Append record to current db file (rolls to next file at 10KB)
REM  Updates idx with:
REM    M|CUR|n, F|n|bytes, R|n|rec, I|table|key|n|rec
REM ==============================================================
AppendRecord:
    REM IN: REC$, TBL$, KEY$
    REC$ = TRIM$(REC$)
    IF REC$ = "" THEN SQL_STATUS = 98: SQL_MSG$="EMPTY RECORD": RETURN

    GOSUB GetMeta
    METAKEY$ = "CUR": GOSUB GetMeta
    CURFILE = VAL(METAVAL$)
    IF CURFILE <= 0 THEN CURFILE = 1

    FN = CURFILE
    GOSUB GetFileBytes
    CURB = BYTES

    ADD = LEN(REC$) + 2
    NEWB = CURB + ADD

    IF NEWB > MAXFILE THEN
        CURFILE = CURFILE + 1
        FN = CURFILE
        GOSUB MakeDBName
        OPEN DBFN$ FOR APPEND AS #1
        CLOSE #1
        CURB = 0
        NEWB = ADD
    END IF

    FN = CURFILE
    GOSUB GetFileRecMax
    RNO = RMAX + 1

    FN = CURFILE
    GOSUB MakeDBName
    OPEN DBFN$ FOR APPEND AS #1
    PRINT #1, REC$
    CLOSE #1

    OPEN IDXFN$ FOR APPEND AS #1
    PRINT #1, "M|CUR|"; CURFILE
    PRINT #1, "F|"; CURFILE; "|"; NEWB
    PRINT #1, "R|"; CURFILE; "|"; RNO
    PRINT #1, "I|"; TBL$; "|"; KEY$; "|"; CURFILE; "|"; RNO
    CLOSE #1
    RETURN


REM ==============================================================
REM  EXEC SQL: CREATE/INSERT/SELECT/UPDATE/REPLACE/DELETE
REM  + Transaction queueing (BEGIN/COMMIT/ROLLBACK)
REM ==============================================================
ExecSQL:
    ST$ = TRIM$(SQL_STMT$)
    IF ST$ = "" THEN SQL_STATUS = 11: SQL_MSG$="EMPTY SQL": RETURN

    REM If txn is active, queue statements (except SELECT allowed to run)
    METAKEY$ = "TXN": GOSUB GetMeta
    TXNFLAG = VAL(METAVAL$)

    UP$ = UCASE$(ST$)

    IF TXNFLAG = 1 THEN
        IF LEFT$(UP$, 6) <> "SELECT" THEN
            OPEN TXNFN$ FOR APPEND AS #1
            PRINT #1, ST$
            CLOSE #1
            SQL_MSG$ = "QUEUED (TXN)"
            RETURN
        END IF
    END IF

    REM Enforce modes
    IF SQL_MODE$ = "RO" THEN
        IF LEFT$(UP$, 6) <> "SELECT" THEN
            SQL_STATUS=20: SQL_MSG$="READ-ONLY MODE":
            RETURN
    END IF
    IF SQL_MODE$ = "AO" THEN
        IF LEFT$(UP$, 6) <> "INSERT" THEN
            SQL_STATUS=21: SQL_MSG$="APPEND-ONLY MODE":
            RETURN
    END IF

    IF LEFT$(UP$, 12) = "CREATE TABLE" THEN GOSUB DoCreate: RETURN
    IF LEFT$(UP$, 6) = "INSERT" THEN GOSUB DoInsert: RETURN
    IF LEFT$(UP$, 6) = "SELECT" THEN GOSUB DoSelect: RETURN
    IF LEFT$(UP$, 6) = "UPDATE" THEN GOSUB DoUpdate: RETURN
    IF LEFT$(UP$, 7) = "REPLACE" THEN GOSUB DoReplace: RETURN
    IF LEFT$(UP$, 6) = "DELETE" THEN GOSUB DoDelete: RETURN

    SQL_STATUS = 12
    SQL_MSG$ = "UNSUPPORTED SQL"
    RETURN


REM ==============================================================
REM  CREATE TABLE t (a,b,c) PK keyname
REM ==============================================================
DoCreate:
    P = INSTR(UP$, "TABLE")
    IF P = 0 THEN SQL_STATUS=30: SQL_MSG$="BAD CREATE": RETURN
    TMP$ = TRIM$(MID$(ST$, P+5))

    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=31: SQL_MSG$="BAD CREATE": RETURN
    TBL$ = TRIM$(LEFT$(TMP$, SP-1))
    REST$ = TRIM$(MID$(TMP$, SP+1))

    OP = INSTR(REST$, "(")
    CP = INSTR(REST$, ")")
    IF OP = 0 OR CP = 0 OR CP < OP THEN
        SQL_STATUS=32: SQL_MSG$="BAD COL LIST":
        RETURN
    COLS$ = TRIM$(MID$(REST$, OP+1, CP-OP-1))

    PK$ = "KEY"
    PPK = INSTR(UCASE$(REST$), "PK")
    IF PPK > 0 THEN
        PK$ = TRIM$(MID$(REST$, PPK+2))
        IF PK$ = "" THEN PK$ = "KEY"
    END IF

    OPEN IDXFN$ FOR APPEND AS #1
    PRINT #1, "S|"; TBL$; "|"; COLS$; "|"; PK$
    CLOSE #1

    SQL_MSG$ = "TABLE CREATED: " + TBL$
    RETURN


REM ==============================================================
REM  INSERT INTO t KEY k VALUES (v1,v2,...)
REM ==============================================================
DoInsert:
    P = INSTR(UP$, "INTO")
    IF P = 0 THEN SQL_STATUS=40: SQL_MSG$="BAD INSERT": RETURN
    TMP$ = TRIM$(MID$(ST$, P+4))

    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=41: SQL_MSG$="BAD INSERT": RETURN
    TBL$ = TRIM$(LEFT$(TMP$, SP-1))
    REST$ = TRIM$(MID$(TMP$, SP+1))

    GOSUB GetSchema
    IF COLS$ = "" THEN SQL_STATUS=46: SQL_MSG$="NO SUCH TABLE": RETURN

    PKPOS = INSTR(UCASE$(REST$), "KEY")
    IF PKPOS = 0 THEN
        SQL_STATUS=42: SQL_MSG$="INSERT REQUIRES KEY":
    RETURN
    TMP2$ = TRIM$(MID$(REST$, PKPOS+3))
    SP2 = INSTR(TMP2$, " ")
    IF SP2 = 0 THEN
        SQL_STATUS=43: SQL_MSG$="INSERT REQUIRES VALUES":
    RETURN
    KEY$ = TRIM$(LEFT$(TMP2$, SP2-1))
    REST2$ = TRIM$(MID$(TMP2$, SP2+1))

    VPOS = INSTR(UCASE$(REST2$), "VALUES")
    IF VPOS = 0 THEN
        SQL_STATUS=44: SQL_MSG$="INSERT REQUIRES VALUES":
    RETURN
    VSTR$ = TRIM$(MID$(REST2$, VPOS+6))
    OP = INSTR(VSTR$, "("): CP = INSTR(VSTR$, ")")
    IF OP=0 OR CP=0 OR CP<OP THEN
        SQL_STATUS=45: SQL_MSG$="BAD VALUES":
    RETURN
    VALS$ = TRIM$(MID$(VSTR$, OP+1, CP-OP-1))

    REC$ = "R|" + TBL$ + "|" + KEY$
    CI = 1
    WHILE 1
        GOSUB TokCSVCols
        IF COL$ = "" THEN EXIT WHILE
        GOSUB TokCSVVals
        REC$ = REC$ + "|" + COL$ + "=" + VV$
        CI = CI + 1
    WEND

    GOSUB AppendRecord
    SQL_MSG$ = "INSERTED " + TBL$ + " KEY " + KEY$
    RETURN

TokCSVCols:
    COL$ = GetCSVToken$(COLS$, CI)
    RETURN
TokCSVVals:
    VV$ = GetCSVToken$(VALS$, CI)
    RETURN


REM ==============================================================
REM  SELECT * FROM t [WHERE KEY=val | WHERE col=val] [LIMIT n]
REM  Returns only latest versions (using idx table map)
REM ==============================================================
DoSelect:
    SQL_RESULT$ = ""
    LIMIT = 0

    PF = INSTR(UP$, "FROM")
    IF PF = 0 THEN SQL_STATUS=50: SQL_MSG$="BAD SELECT": RETURN

    TMP$ = TRIM$(MID$(ST$, PF+4))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN
        TBL$ = TRIM$(TMP$)
        REST$ = ""
    ELSE
        TBL$ = TRIM$(LEFT$(TMP$, SP-1))
        REST$ = TRIM$(MID$(TMP$, SP+1))
    END IF

    GOSUB GetSchema
    IF COLS$ = "" THEN SQL_STATUS=51: SQL_MSG$="NO SUCH TABLE": RETURN

    WCOL$ = "": WVAL$ = "": WHEREKEY = 0

    PW = INSTR(UCASE$(REST$), "WHERE")
    IF PW > 0 THEN
        W$ = TRIM$(MID$(REST$, PW+5))
        PL = INSTR(UCASE$(W$), "LIMIT")
        IF PL > 0 THEN
            LIMIT = VAL(TRIM$(MID$(W$, PL+5)))
            W$ = TRIM$(LEFT$(W$, PL-1))
        END IF

        EQ = INSTR(W$, "=")
        IF EQ = 0 THEN SQL_STATUS=52: SQL_MSG$="BAD WHERE": RETURN
        WCOL$ = TRIM$(LEFT$(W$, EQ-1))
        WVAL$ = TRIM$(MID$(W$, EQ+1))
        IF UCASE$(WCOL$) = "KEY" THEN WHEREKEY = 1
    ELSE
        PL2 = INSTR(UCASE$(REST$), "LIMIT")
        IF PL2 > 0 THEN LIMIT = VAL(TRIM$(MID$(REST$, PL2+5)))
    END IF

    REM Load index for this table once (fast lookups)
    GOSUB LoadIndexForTable

    IF WHEREKEY = 1 THEN
        POS$ = IDX{WVAL$}
        IF POS$ = "" THEN SQL_MSG$="0 ROWS": RETURN
        C = INSTR(POS$, ",")
        FNO = VAL(LEFT$(POS$, C-1))
        RNO = VAL(MID$(POS$, C+1))
        IF FNO = 0 THEN SQL_MSG$="0 ROWS": RETURN
        GOSUB FetchByPos
        IF OUT$ <> "" THEN SQL_RESULT$ = OUT$ + CHR$(10)
        SQL_MSG$ = "OK"
        RETURN
    END IF

    METAKEY$ = "CUR": GOSUB GetMeta
    CURFILE = VAL(METAVAL$)
    IF CURFILE <= 0 THEN CURFILE = 1

    ROWS = 0
    FOR FN = 1 TO CURFILE
        GOSUB MakeDBName
        OPEN DBFN$ FOR INPUT AS #1
        RN = 0
        WHILE NOT EOF(1)
            INPUT #1, L$
            RN = RN + 1
            IF (RN MOD 50) = 0 THEN X = SLEEP(YIELDSEC)

            IF INSTR(L$, "R|" + TBL$ + "|") <> 1 THEN GOTO NextRow

            REM parse KEY quickly: R|table|key|
            REST$ = MID$(L$, LEN("R|" + TBL$ + "|") + 1)
            P1 = INSTR(REST$, "|")
            IF P1 = 0 THEN GOTO NextRow
            KEY$ = LEFT$(REST$, P1-1)

            POS$ = IDX{KEY$}
            IF POS$ = "" THEN GOTO NextRow

            C = INSTR(POS$, ",")
            PFN = VAL(LEFT$(POS$, C-1))
            PRN = VAL(MID$(POS$, C+1))
            IF PFN = 0 THEN GOTO NextRow
            IF PFN <> FN OR PRN <> RN THEN GOTO NextRow   REM only latest version

            IF WCOL$ <> "" THEN
                NEED$ = "|" + WCOL$ + "=" + WVAL$
                IF INSTR(L$, NEED$) = 0 THEN GOTO NextRow
            END IF

            SQL_RESULT$ = SQL_RESULT$ + L$ + CHR$(10)
            ROWS = ROWS + 1
            IF LIMIT > 0 AND ROWS >= LIMIT THEN
                CLOSE #1: SQL_MSG$="OK":
            RETURN

NextRow:
        WEND
        CLOSE #1
    NEXT FN

    SQL_MSG$ = "OK"
    RETURN


REM ==============================================================
REM  UPDATE t KEY k SET col=val   (append new version)
REM ==============================================================
DoUpdate:
    TMP$ = TRIM$(MID$(ST$, 7))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=60: SQL_MSG$="BAD UPDATE": RETURN
    TBL$ = TRIM$(LEFT$(TMP$, SP-1))
    REST$ = TRIM$(MID$(TMP$, SP+1))

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=61: SQL_MSG$="NO SUCH TABLE":
        RETURN

    PKPOS = INSTR(UCASE$(REST$), "KEY")
    IF PKPOS = 0 THEN
        SQL_STATUS=62: SQL_MSG$="UPDATE REQUIRES KEY":
        RETURN
    TMP2$ = TRIM$(MID$(REST$, PKPOS+3))
    SP2 = INSTR(TMP2$, " ")
    IF SP2 = 0 THEN
        SQL_STATUS=63: SQL_MSG$="UPDATE REQUIRES SET":
        RETURN
    KEY$ = TRIM$(LEFT$(TMP2$, SP2-1))
    REST2$ = TRIM$(MID$(TMP2$, SP2+1))

    SPOS = INSTR(UCASE$(REST2$), "SET")
    IF SPOS = 0 THEN
        SQL_STATUS=64: SQL_MSG$="UPDATE REQUIRES SET":
        RETURN
    SET$ = TRIM$(MID$(REST2$, SPOS+3))
    EQ = INSTR(SET$, "=")
    IF EQ = 0 THEN SQL_STATUS=65: SQL_MSG$="BAD SET": RETURN
    UCOL$ = TRIM$(LEFT$(SET$, EQ-1))
    UVAL$ = TRIM$(MID$(SET$, EQ+1))

    REM Load idx for table and fetch current record if present
    GOSUB LoadIndexForTable
    POS$ = IDX{KEY$}
    CUR$ = ""
    IF POS$ <> "" THEN
        C = INSTR(POS$, ",")
        FNO = VAL(LEFT$(POS$, C-1))
        RNO = VAL(MID$(POS$, C+1))
        IF FNO <> 0 THEN
            GOSUB FetchByPos
            CUR$ = OUT$
        END IF
    END IF

    IF CUR$ = "" THEN CUR$ = "R|" + TBL$ + "|" + KEY$

    REM replace/add field
    NEED$ = "|" + UCOL$ + "="
    P = INSTR(CUR$, NEED$)
    IF P = 0 THEN
        REC$ = CUR$ + "|" + UCOL$ + "=" + UVAL$
    ELSE
        PVAL = P + LEN(NEED$)
        RESTX$ = MID$(CUR$, PVAL)
        NXT = INSTR(RESTX$, "|")
        IF NXT = 0 THEN
            REC$ = LEFT$(CUR$, PVAL-1) + UVAL$
        ELSE
            REC$ = LEFT$(CUR$, PVAL-1) + UVAL$ + MID$(RESTX$, NXT)
        END IF
    END IF

    GOSUB AppendRecord
    SQL_MSG$ = "UPDATED " + TBL$ + " KEY " + KEY$
    RETURN


REM ==============================================================
REM  REPLACE t KEY k VALUES (...)
REM ==============================================================
DoReplace:
    TMP$ = TRIM$(MID$(ST$, 8))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=70: SQL_MSG$="BAD REPLACE": RETURN
    TBL$ = TRIM$(LEFT$(TMP$, SP-1))
    REST$ = TRIM$(MID$(TMP$, SP+1))

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=71: SQL_MSG$="NO SUCH TABLE":
        RETURN
    END IF

    PKPOS = INSTR(UCASE$(REST$), "KEY")
    IF PKPOS = 0 THEN
        SQL_STATUS=72: SQL_MSG$="REPLACE REQUIRES KEY":
        RETURN
    END IF
    TMP2$ = TRIM$(MID$(REST$, PKPOS+3))
    SP2 = INSTR(TMP2$, " ")
    IF SP2 = 0 THEN
        SQL_STATUS=73: SQL_MSG$="REPLACE REQUIRES VALUES":
        RETURN
    END IF
    KEY$ = TRIM$(LEFT$(TMP2$, SP2-1))
    REST2$ = TRIM$(MID$(TMP2$, SP2+1))

    VPOS = INSTR(UCASE$(REST2$), "VALUES")
    IF VPOS = 0 THEN
        SQL_STATUS=74: SQL_MSG$="REPLACE REQUIRES VALUES":
        RETURN
    END IF
    VSTR$ = TRIM$(MID$(REST2$, VPOS+6))
    OP = INSTR(VSTR$, "("): CP = INSTR(VSTR$, ")")
    IF OP=0 OR CP=0 OR CP<OP THEN
        SQL_STATUS=75: SQL_MSG$="BAD VALUES":
        RETURN
    END IF
    VALS$ = TRIM$(MID$(VSTR$, OP+1, CP-OP-1))

    REC$ = "R|" + TBL$ + "|" + KEY$
    CI = 1
    WHILE 1
        COL$ = GetCSVToken$(COLS$, CI)
        IF COL$ = "" THEN EXIT WHILE
        VV$  = GetCSVToken$(VALS$, CI)
        REC$ = REC$ + "|" + COL$ + "=" + VV$
        CI = CI + 1
    WEND

    GOSUB AppendRecord
    SQL_MSG$ = "REPLACED " + TBL$ + " KEY " + KEY$
    RETURN


REM ==============================================================
REM  DELETE FROM t KEY k  (tombstone in idx)
REM ==============================================================
DoDelete:
    PF = INSTR(UP$, "FROM")
    IF PF = 0 THEN SQL_STATUS=80: SQL_MSG$="BAD DELETE": RETURN
    TMP$ = TRIM$(MID$(ST$, PF+4))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=81: SQL_MSG$="BAD DELETE": RETURN
    TBL$ = TRIM$(LEFT$(TMP$, SP-1))
    REST$ = TRIM$(MID$(TMP$, SP+1))

    PKPOS = INSTR(UCASE$(REST$), "KEY")
    IF PKPOS = 0 THEN
        SQL_STATUS=82: SQL_MSG$="DELETE REQUIRES KEY":
        RETURN
    END IF
    KEY$ = TRIM$(MID$(REST$, PKPOS+3))

    OPEN IDXFN$ FOR APPEND AS #1
    PRINT #1, "I|"; TBL$; "|"; KEY$; "|0|0"
    CLOSE #1

    SQL_MSG$ = "DELETED " + TBL$ + " KEY " + KEY$
    RETURN


REM ==============================================================
REM  SEARCH: SQL_STMT$ = "table|term|col(optional)"
REM  Scans latest versions only (using idx map)
REM ==============================================================
SearchCmd:
    SQL_RESULT$ = ""

    TBL$ = GetPipeToken$(SQL_STMT$, 1)
    TERM$ = GetPipeToken$(SQL_STMT$, 2)
    COLF$ = GetPipeToken$(SQL_STMT$, 3)

    IF TBL$ = "" OR TERM$ = "" THEN
        SQL_STATUS=90: SQL_MSG$="SEARCH NEEDS table|term":
        RETURN
    END IF

    GOSUB GetSchema
    IF COLS$ = "" THEN SQL_STATUS=91: SQL_MSG$="NO SUCH TABLE": RETURN

    GOSUB LoadIndexForTable

    METAKEY$ = "CUR": GOSUB GetMeta
    CURFILE = VAL(METAVAL$)
    IF CURFILE <= 0 THEN CURFILE = 1

    ROWS = 0
    FOR FN = 1 TO CURFILE
        GOSUB MakeDBName
        OPEN DBFN$ FOR INPUT AS #1
        RN = 0
        WHILE NOT EOF(1)
            INPUT #1, L$
            RN = RN + 1
            IF (RN MOD 50) = 0 THEN X = SLEEP(YIELDSEC)

            IF INSTR(L$, "R|" + TBL$ + "|") <> 1 THEN GOTO SNext

            REST$ = MID$(L$, LEN("R|" + TBL$ + "|") + 1)
            P1 = INSTR(REST$, "|")
            IF P1 = 0 THEN GOTO SNext
            KEY$ = LEFT$(REST$, P1-1)

            POS$ = IDX{KEY$}
            IF POS$ = "" THEN GOTO SNext
            C = INSTR(POS$, ",")
            PFN = VAL(LEFT$(POS$, C-1))
            PRN = VAL(MID$(POS$, C+1))
            IF PFN = 0 THEN GOTO SNext
            IF PFN <> FN OR PRN <> RN THEN GOTO SNext

            IF COLF$ = "" THEN
                IF INSTR(UCASE$(L$), UCASE$(TERM$)) > 0 THEN
                    SQL_RESULT$ = SQL_RESULT$ + L$ + CHR$(10)
                END IF
            ELSE
                NEED$ = "|" + COLF$ + "="
                IF INSTR(UCASE$(L$), UCASE$(NEED$ + TERM$)) > 0 THEN
                    SQL_RESULT$ = SQL_RESULT$ + L$ + CHR$(10)
                END IF
            END IF
SNext:
        WEND
        CLOSE #1
    NEXT FN

    SQL_MSG$ = "OK"
    RETURN


REM ==============================================================
REM  TRANSACTIONS
REM ==============================================================
TxnBegin:
    OPEN TXNFN$ FOR OUTPUT AS #1
    CLOSE #1
    OPEN IDXFN$ FOR APPEND AS #1
    PRINT #1, "M|TXN|1"
    CLOSE #1
    SQL_MSG$ = "TXN BEGIN"
    RETURN

TxnRollback:
    OPEN TXNFN$ FOR OUTPUT AS #1
    CLOSE #1
    OPEN IDXFN$ FOR APPEND AS #1
    PRINT #1, "M|TXN|0"
    CLOSE #1
    SQL_MSG$ = "TXN ROLLBACK"
    RETURN

TxnCommit:
    METAKEY$ = "TXN": GOSUB GetMeta
    IF VAL(METAVAL$) <> 1 THEN SQL_MSG$="NO TXN": RETURN

    OPEN TXNFN$ FOR INPUT AS #1
    N = 0
    WHILE NOT EOF(1)
        INPUT #1, L$
        L$ = TRIM$(L$)
        IF L$ <> "" THEN
            N = N + 1
            OLD$ = SQL_STMT$
            OLDM$ = SQL_MODE$
            SQL_MODE$ = "RW"
            SQL_STMT$ = L$
            GOSUB ExecSQL
            SQL_STMT$ = OLD$
            SQL_MODE$ = OLDM$
        END IF
        IF (N MOD 20) = 0 THEN X = SLEEP(YIELDSEC)
    WEND
    CLOSE #1

    OPEN TXNFN$ FOR OUTPUT AS #1
    CLOSE #1
    OPEN IDXFN$ FOR APPEND AS #1
    PRINT #1, "M|TXN|0"
    CLOSE #1

    SQL_MSG$ = "TXN COMMIT (" + STR$(N) + " stmts)"
    RETURN


REM ==============================================================
REM  COMPACT: rewrite idx with latest-wins only (schemas/meta/index/F/R)
REM ==============================================================
CompactIdx:
    DIM SC{}
    DIM IX{}
    DIM FB{}
    DIM RC{}
    DIM META{}

    REM Pass 1: scan idx, keep latest values in maps
    OPEN IDXFN$ FOR INPUT AS #1
    N = 0
    WHILE NOT EOF(1)
        INPUT #1, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        L$ = TRIM$(L$)

        IF INSTR(L$, "S|") = 1 THEN
            REST$ = MID$(L$, 3)
            T$ = GetPipeToken$(REST$, 1)
            C$ = GetPipeToken$(REST$, 2)
            P$ = GetPipeToken$(REST$, 3)
            SC{T$} = C$ + "|" + P$
        END IF

        IF INSTR(L$, "I|") = 1 THEN
            REST$ = MID$(L$, 3)
            T$ = GetPipeToken$(REST$, 1)
            K$ = GetPipeToken$(REST$, 2)
            F$ = GetPipeToken$(REST$, 3)
            R$ = GetPipeToken$(REST$, 4)
            IX{T$ + "|" + K$} = F$ + "|" + R$
        END IF

        IF INSTR(L$, "F|") = 1 THEN
            REST$ = MID$(L$, 3)
            FN$ = GetPipeToken$(REST$, 1)
            B$  = GetPipeToken$(REST$, 2)
            FB{FN$} = B$
        END IF

        IF INSTR(L$, "R|") = 1 THEN
            REST$ = MID$(L$, 3)
            FN$ = GetPipeToken$(REST$, 1)
            C$  = GetPipeToken$(REST$, 2)
            RC{FN$} = C$
        END IF

        IF INSTR(L$, "M|") = 1 THEN
            REST$ = MID$(L$, 3)
            K$ = GetPipeToken$(REST$, 1)
            V$ = GetPipeToken$(REST$, 2)
            META{K$} = V$
        END IF
    WEND
    CLOSE #1

    TMPFN$ = DBPFX$ + "-idxnew.dat"
    OPEN TMPFN$ FOR OUTPUT AS #1

    REM Write meta
    IF META{"CUR"} <> "" THEN PRINT #1, "M|CUR|"; META{"CUR"}
    IF META{"TXN"} <> "" THEN PRINT #1, "M|TXN|"; META{"TXN"}

    REM Write schemas
    REM We don't have a built-in iterator spec here, so we re-scan the old idx
    REM and output only when it matches the final map value (dedupe).
    OPEN IDXFN$ FOR INPUT AS #2
    N = 0
    WHILE NOT EOF(2)
        INPUT #2, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        L$ = TRIM$(L$)

        IF INSTR(L$, "S|") = 1 THEN
            REST$ = MID$(L$, 3)
            T$ = GetPipeToken$(REST$, 1)
            C$ = GetPipeToken$(REST$, 2)
            P$ = GetPipeToken$(REST$, 3)
            IF SC{T$} = (C$ + "|" + P$) THEN
                PRINT #1, "S|"; T$; "|"; C$; "|"; P$
                SC{T$} = ""   REM mark written
            END IF
        END IF
    WEND
    CLOSE #2

    REM Write F/R and I similarly by rescanning and matching final maps
    OPEN IDXFN$ FOR INPUT AS #2
    N = 0
    WHILE NOT EOF(2)
        INPUT #2, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        L$ = TRIM$(L$)

        IF INSTR(L$, "F|") = 1 THEN
            REST$ = MID$(L$, 3)
            FN$ = GetPipeToken$(REST$, 1)
            B$  = GetPipeToken$(REST$, 2)
            IF FB{FN$} = B$ THEN
                PRINT #1, "F|"; FN$; "|"; B$
                FB{FN$} = ""
            END IF
        END IF

        IF INSTR(L$, "R|") = 1 THEN
            REST$ = MID$(L$, 3)
            FN$ = GetPipeToken$(REST$, 1)
            C$  = GetPipeToken$(REST$, 2)
            IF RC{FN$} = C$ THEN
                PRINT #1, "R|"; FN$; "|"; C$
                RC{FN$} = ""
            END IF
        END IF

        IF INSTR(L$, "I|") = 1 THEN
            REST$ = MID$(L$, 3)
            T$ = GetPipeToken$(REST$, 1)
            K$ = GetPipeToken$(REST$, 2)
            F$ = GetPipeToken$(REST$, 3)
            R$ = GetPipeToken$(REST$, 4)
            IF IX{T$ + "|" + K$} = (F$ + "|" + R$) THEN
                PRINT #1, "I|"; T$; "|"; K$; "|"; F$; "|"; R$
                IX{T$ + "|" + K$} = ""
            END IF
        END IF
    WEND
    CLOSE #2

    CLOSE #1

    REM Copy tmp over real idx
    OPEN TMPFN$ FOR INPUT AS #1
    OPEN IDXFN$ FOR OUTPUT AS #2
    WHILE NOT EOF(1)
        INPUT #1, L$
        PRINT #2, L$
    WEND
    CLOSE #1
    CLOSE #2

    REM Clear tmp
    OPEN TMPFN$ FOR OUTPUT AS #1
    CLOSE #1

    SQL_MSG$ = "COMPACT OK"
    RETURN


REM ==============================================================
REM  REINDEX: rebuild idx by scanning db files (keeps schemas),
REM          writes fresh M/F/R/I, then COMPACT for cleanliness
REM ==============================================================
ReindexAll:
    REM Keep latest schemas from existing idx
    DIM SC{}
    OPEN IDXFN$ FOR INPUT AS #1
    N = 0
    WHILE NOT EOF(1)
        INPUT #1, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        L$ = TRIM$(L$)
        IF INSTR(L$, "S|") = 1 THEN
            REST$ = MID$(L$, 3)
            T$ = GetPipeToken$(REST$, 1)
            C$ = GetPipeToken$(REST$, 2)
            P$ = GetPipeToken$(REST$, 3)
            SC{T$} = C$ + "|" + P$
        END IF
    WEND
    CLOSE #1

    METAKEY$ = "CUR": GOSUB GetMeta
    CURFILE = VAL(METAVAL$)
    IF CURFILE <= 0 THEN CURFILE = 1

    TMPFN$ = DBPFX$ + "-idxnew.dat"
    OPEN TMPFN$ FOR OUTPUT AS #1

    PRINT #1, "M|CUR|"; CURFILE
    PRINT #1, "M|TXN|0"

    REM Write schemas by rescanning old idx and matching SC map (dedupe)
    OPEN IDXFN$ FOR INPUT AS #2
    N = 0
    WHILE NOT EOF(2)
        INPUT #2, L$
        N = N + 1
        IF (N MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
        L$ = TRIM$(L$)
        IF INSTR(L$, "S|") = 1 THEN
            REST$ = MID$(L$, 3)
            T$ = GetPipeToken$(REST$, 1)
            C$ = GetPipeToken$(REST$, 2)
            P$ = GetPipeToken$(REST$, 3)
            IF SC{T$} = (C$ + "|" + P$) THEN
                PRINT #1, "S|"; T$; "|"; C$; "|"; P$
                SC{T$} = ""
            END IF
        END IF
    WEND
    CLOSE #2

    REM Scan each db file and emit I entries + F/R
    FOR FN = 1 TO CURFILE
        BYTES = 0
        RECNO = 0
        GOSUB MakeDBName
        OPEN DBFN$ FOR INPUT AS #2
        WHILE NOT EOF(2)
            INPUT #2, L$
            RECNO = RECNO + 1
            IF (RECNO MOD 50) = 0 THEN X = SLEEP(YIELDSEC)
            BYTES = BYTES + LEN(L$) + 2
            IF INSTR(L$, "R|") <> 1 THEN GOTO RNext

            REST$ = MID$(L$, 3)
            T$ = GetPipeToken$(REST$, 1)
            K$ = GetPipeToken$(REST$, 2)
            IF T$ <> "" AND K$ <> "" THEN
                PRINT #1, "I|"; T$; "|"; K$; "|"; FN; "|"; RECNO
            END IF
RNext:
        WEND
        CLOSE #2

        PRINT #1, "F|"; FN; "|"; BYTES
        PRINT #1, "R|"; FN; "|"; RECNO
    NEXT FN

    CLOSE #1

    REM Copy tmp over idx
    OPEN TMPFN$ FOR INPUT AS #1
    OPEN IDXFN$ FOR OUTPUT AS #2
    WHILE NOT EOF(1)
        INPUT #1, L$
        PRINT #2, L$
    WEND
    CLOSE #1
    CLOSE #2

    OPEN TMPFN$ FOR OUTPUT AS #1
    CLOSE #1

    REM Final cleanup pass
    GOSUB CompactIdx
    SQL_MSG$ = "REINDEX OK"
    RETURN


REM ==============================================================
REM  Token helpers (simple, no-quote CSV)
REM ==============================================================
GetPipeToken$:
    REM IN: S$, N  OUT: token
    GetPipeToken$ = GetDelimToken$(S$, "|", N)
    RETURN

GetCSVToken$:
    REM IN: S$, N  OUT: token
    GetCSVToken$ = GetDelimToken$(S$, ",", N)
    RETURN

GetDelimToken$:
    REM Very small tokenizer: N is 1-based
    TMP$ = S$
    P = 1
    K = 1
    WHILE 1
        Q = INSTR(MID$(TMP$, P), D$)
        IF Q = 0 THEN
            PART$ = MID$(TMP$, P)
        ELSE
            PART$ = MID$(TMP$, P, Q-1)
        END IF

        IF K = N THEN
            GetDelimToken$ = TRIM$(PART$)
            RETURN
        END IF

        IF Q = 0 THEN
            GetDelimToken$ = ""
            RETURN
        END IF

        P = P + Q
        K = K + 1
    WEND
    RETURN

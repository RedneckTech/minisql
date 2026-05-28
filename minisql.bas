REM ==============================================================
REM  MINISQL.BAS  v0.5.0  (LABEL-BASED / CHAINABLE)
REM --------------------------------------------------------------
REM  ISAM-based SQL engine for 3270BBS.
REM  Uses the platform's built-in INDEXED file system as the
REM  storage foundation instead of custom flat-file management.
REM
REM  FILENAMES:
REM    <db>.<table>.idx   - ISAM file per user table
REM    <db>.schema.idx    - ISAM system table for schemas
REM    <db>.log.dat        - event log (file handle #1, always open)
REM    batch.dat           - transaction batch queue
REM
REM  FILE HANDLES:
REM    #1 - log file (kept open during session)
REM    #2 - schema ISAM (open/close per use)
REM    #3 - target table ISAM (open/close per operation)
REM    #4 - batch file (intermittent)
REM
REM  COMMON API:
REM    SQL_CMD$    = "INITDB"|"EXEC"|"BEGIN"|"COMMIT"
REM                  "ROLLBACK"|"SEARCH"
REM    SQL_DB$     = database prefix
REM    SQL_STMT$   = SQL statement or search spec
REM    SQL_MODE$   = "RW"|"RO"|"AO"
REM
REM  OUTPUTS:
REM    SQL_STATUS  = 0 ok, nonzero error
REM    SQL_MSG$    = message
REM    SQL_RESULT$ = results (lines separated by CHR$(10))
REM ==============================================================
REM Copyright 2025 by FARMER. ALL rights reserved

REM ==============================================================
REM  Program start
REM ==============================================================
START:
    COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$
    COMMON SQL_RESULT$, SQL_STATUS, SQL_MSG$

    SQL_STATUS = 0
    SQL_MSG$ = ""
    SQL_RESULT$ = ""

    IF SQL_DB$ = "" THEN
        SQL_STATUS = 10
        SQL_MSG$ = "SQL_DB$ REQUIRED"
        END
    END IF

    GOSUB SanitizeDB
    GOSUB InitLog

    CMD$ = UCASE$(TRIM$(SQL_CMD$))
    IF SQL_MODE$ = "" THEN SQL_MODE$ = "RW"
    SQL_MODE$ = UCASE$(SQL_MODE$)

    SELECT CASE CMD$
        CASE "INITDB":   GOSUB InitDB
        CASE "EXEC":     GOSUB ExecSQL
        CASE "BEGIN":    GOSUB TxnBegin
        CASE "COMMIT":   GOSUB TxnCommit
        CASE "ROLLBACK": GOSUB TxnRollback
        CASE "SEARCH":   GOSUB SearchCmd
        CASE ELSE
            SQL_STATUS = 99
            SQL_MSG$ = "UNKNOWN CMD"
    END SELECT

    LBL$ = "CLOSED": MSG$ = "Database session end": GOSUB LogEvent
    CLOSE #1
    END


REM ==============================================================
REM  Helpers: sanitize DB name ( '_' -> '-' )
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
REM  Init/Open log file and read options header
REM ==============================================================
InitLog:
    LOGFN$ = DBPFX$ + ".log.dat"
    BATFN$ = "batch.dat"
    SYSFN$ = DBPFX$ + ".schema.idx"

    DIM OPT{}
    OPT{"100"} = "0.5.0"
    OPT{"101"} = "0"
    OPT{"102"} = "10000"
    FOR I = 103 TO 109
        OPT{STR$(I)} = "0"
    NEXT I
    OPT{"200"} = "1"
    OPT{"201"} = "1"
    FOR I = 202 TO 209
        OPT{STR$(I)} = "0"
    NEXT I
    OPT{"300"} = "1"
    OPT{"301"} = "100"
    FOR I = 302 TO 309
        OPT{STR$(I)} = "0"
    NEXT I

    OPEN LOGFN$ FOR INPUT AS #1
    IF EOF(1) THEN
        CLOSE #1
        OPEN LOGFN$ FOR OUTPUT AS #1
        HDR$ = "HDR|" + DBPFX$ + "|" + OPT{"100"} + "|"
        PRINT #1, HDR$ + DATE$() + "T" + TIME$()
        PRINT #1, "OPT|100|" + OPT{"100"}
        FOR I = 101 TO 109
            PRINT #1, "OPT|" + STR$(I) + "|" + OPT{STR$(I)}
        NEXT I
        FOR I = 200 TO 209
            PRINT #1, "OPT|" + STR$(I) + "|" + OPT{STR$(I)}
        NEXT I
        FOR I = 300 TO 309
            PRINT #1, "OPT|" + STR$(I) + "|" + OPT{STR$(I)}
        NEXT I
        LBL$ = "OPEN"
        MSG$ = "Log created for database " + DBPFX$
        GOSUB LogEvent
        RETURN
    END IF

    WHILE NOT EOF(1)
        INPUT #1, L$
        L$ = TRIM$(L$)
        IF INSTR(L$, "OPT|") = 1 THEN
            REST$ = MID$(L$, 5)
            P = INSTR(REST$, "|")
            IF P > 0 THEN
                K$ = LEFT$(REST$, P-1)
                V$ = MID$(REST$, P+1)
                OPT{K$} = V$
            END IF
        END IF
    WEND
    CLOSE #1

    OPEN LOGFN$ FOR APPEND AS #1
    LBL$ = "OPEN"
    MSG$ = "Database " + DBPFX$ + " opened"
    GOSUB LogEvent
    RETURN


REM ==============================================================
REM  Log an event with label  (IN: LBL$, MSG$)
REM  Uses OPT{"200"} (LOG_ENABLED) and OPT{"201"} (LOG_LEVEL)
REM    LOG_LEVEL: 0=errors, 1=normal, 2=verbose
REM ==============================================================
LogEvent:
    IF OPT{"200"} <> "1" THEN RETURN
    LV = VAL(OPT{"201"})
    IF LV = 0 AND LBL$ <> "ERROR" THEN RETURN
    E$ = "EVENT|" + LBL$ + "|" + DATE$() + "T" + TIME$()
    PRINT #1, E$ + "|" + MSG$
    RETURN


REM ==============================================================
REM  INITDB - create schema ISAM and seed it
REM ==============================================================
InitDB:
    GOSUB EnsureSchemaTable
    LBL$ = "OPEN"
    MSG$ = "Database " + DBPFX$ + " initialized"
    GOSUB LogEvent
    SQL_MSG$ = "INITDB OK"
    RETURN

EnsureSchemaTable:
    OPEN SYSFN$ FOR INPUT AS #2
    CLOSE #2
    OPEN SYSFN$ FOR INDEXED AS #2 KEY = "name"
    DIM S{}
    S{"name"} = "_schema_meta"
    S{"value"} = "v1"
    PUT #2, S{}
    CLOSE #2
    RETURN


REM ==============================================================
REM  Schema helpers
REM ==============================================================
GetSchema:
    REM IN: TBL$  OUT: COLS$, PK$, SEQ
    COLS$ = ""
    PK$ = ""
    SEQ = 0
    OPEN SYSFN$ FOR INDEXED AS #2 KEY = "name"
    DIM S{}
    GET #2, S{}, KEY = TBL$
    IF FOUND(2) THEN
        COLS$ = S{"cols"}
        PK$ = S{"pk"}
        IF S{"seq"} <> "" THEN SEQ = VAL(S{"seq"})
    END IF
    CLOSE #2
    RETURN

PutSchema:
    REM IN: TBL$, COLS$, PK$  (SEQ optional, default 1)
    OPEN SYSFN$ FOR INDEXED AS #2 KEY = "name"
    DIM S{}
    S{"name"} = TBL$
    S{"cols"} = COLS$
    S{"pk"} = PK$
    S{"seq"} = "1"
    PUT #2, S{}
    CLOSE #2
    RETURN

UpdateSeq:
    REM IN: TBL$, new SEQ value
    OPEN SYSFN$ FOR INDEXED AS #2 KEY = "name"
    DIM S{}
    GET #2, S{}, KEY = TBL$
    IF FOUND(2) THEN
        S{"seq"} = STR$(SEQ)
        PUT #2, S{}
    END IF
    CLOSE #2
    RETURN

DelSchema:
    REM IN: TBL$
    OPEN SYSFN$ FOR INDEXED AS #2 KEY = "name"
    DELETE #2, KEY = TBL$
    CLOSE #2
    RETURN


REM ==============================================================
REM  Table file helpers
REM ==============================================================
GetTableFN:
    REM IN: TBL$  OUT: TFN$
    TFN$ = DBPFX$ + "." + TBL$ + ".idx"
    RETURN

OpenTableISAM:
    REM IN: TBL$  Uses #3
    GOSUB GetTableFN
    OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
    RETURN

CloseTableISAM:
    CLOSE #3
    RETURN


REM ==============================================================
REM  EXEC SQL dispatcher
REM ==============================================================
ExecSQL:
    ST$ = TRIM$(SQL_STMT$)
    IF ST$ = "" THEN SQL_STATUS=11: SQL_MSG$="EMPTY SQL": RETURN

    UP$ = UCASE$(ST$)

    IF OPT{"300"} = "1" THEN
        OPEN BATFN$ FOR INPUT AS #4
        IF NOT EOF(4) THEN
            INPUT #4, L$
            L$ = TRIM$(L$)
            IF L$ = "BEGIN" THEN
                CLOSE #4
                IF LEFT$(UP$, 6) <> "SELECT" THEN
                    OPEN BATFN$ FOR APPEND AS #4
                    PRINT #4, ST$
                    CLOSE #4
                    SQL_MSG$ = "QUEUED (TXN)"
                    RETURN
                END IF
            ELSE
                CLOSE #4
            END IF
        ELSE
            CLOSE #4
        END IF
    END IF

    IF SQL_MODE$ = "RO" THEN
        IF LEFT$(UP$, 6) <> "SELECT" THEN
            SQL_STATUS=20: SQL_MSG$="READ-ONLY MODE"
            LBL$ = "WARNING"
            MSG$ = "Write denied in RO mode"
            GOSUB LogEvent
            RETURN
        END IF
    END IF
    IF SQL_MODE$ = "AO" THEN
        IF LEFT$(UP$, 6) <> "INSERT" THEN
            SQL_STATUS=21: SQL_MSG$="APPEND-ONLY MODE"
            LBL$ = "WARNING"
            MSG$ = "Non-INSERT denied in AO mode"
            GOSUB LogEvent
            RETURN
        END IF
    END IF

    IF LEFT$(UP$, 12) = "CREATE TABLE" THEN GOSUB DoCreate: RETURN
    IF LEFT$(UP$, 6) = "INSERT" THEN GOSUB DoInsert: RETURN
    IF LEFT$(UP$, 6) = "SELECT" THEN GOSUB DoSelect: RETURN
    IF LEFT$(UP$, 6) = "UPDATE" THEN GOSUB DoUpdate: RETURN
    IF LEFT$(UP$, 7) = "REPLACE" THEN GOSUB DoReplace: RETURN
    IF LEFT$(UP$, 6) = "DELETE" THEN GOSUB DoDelete: RETURN
    IF LEFT$(UP$, 4) = "DROP" THEN GOSUB DoDrop: RETURN
    IF LEFT$(UP$, 4) = "SHOW" THEN GOSUB DoShow: RETURN
    IF LEFT$(UP$, 8) = "DESCRIBE" THEN GOSUB DoDescribe: RETURN
    IF LEFT$(UP$, 12) = "ALTER TABLE" THEN GOSUB DoAlter: RETURN

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

    GOSUB GetSchema
    IF COLS$ <> "" THEN SQL_STATUS=33: SQL_MSG$="TABLE EXISTS": RETURN

    OP = INSTR(REST$, "(")
    CP = INSTR(REST$, ")")
    IF OP = 0 OR CP = 0 OR CP < OP THEN
        SQL_STATUS=32: SQL_MSG$="BAD COL LIST"
        RETURN
    END IF
    COLS$ = TRIM$(MID$(REST$, OP+1, CP-OP-1))

    PK$ = "key"
    PPK = INSTR(UCASE$(REST$), "PK")
    IF PPK > 0 THEN
        PK$ = TRIM$(MID$(REST$, PPK+2))
        IF PK$ = "" THEN PK$ = "key"
    END IF

    GOSUB GetTableFN
    OPEN TFN$ FOR OUTPUT AS #3
    CLOSE #3

    GOSUB PutSchema
    LBL$ = "UPDATED": MSG$ = "TABLE CREATED " + TBL$: GOSUB LogEvent
    SQL_MSG$ = "TABLE CREATED: " + TBL$
    RETURN


REM ==============================================================
REM  INSERT INTO t [KEY k|*] VALUES (v1,v2,...)
REM  KEY optional — omitting or using KEY * auto-generates a
REM  numeric key from the table's sequence counter.
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
        AUTO = 1
        REST2$ = REST$
    ELSE
        TMP2$ = TRIM$(MID$(REST$, PKPOS+3))
        SP2 = INSTR(TMP2$, " ")
        IF SP2 = 0 THEN
            SQL_STATUS=43: SQL_MSG$="INSERT REQUIRES VALUES"
            RETURN
        END IF
        KEY$ = TRIM$(LEFT$(TMP2$, SP2-1))
        IF KEY$ = "*" THEN
            AUTO = 1
        ELSE
            AUTO = 0
        END IF
        REST2$ = TRIM$(MID$(TMP2$, SP2+1))
    END IF

    IF AUTO = 1 THEN
        SEQ = SEQ + 1
        KEY$ = STR$(SEQ)
        GOSUB UpdateSeq
    ELSE
        TFN$ = DBPFX$ + "." + TBL$ + ".idx"
        OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
        DIM D{}
        GET #3, D{}, KEY = KEY$
        CLOSE #3
        IF FOUND(3) THEN
            SQL_STATUS=47: SQL_MSG$="DUPLICATE KEY"
            RETURN
        END IF
    END IF

    VPOS = INSTR(UCASE$(REST2$), "VALUES")
    IF VPOS = 0 THEN
        SQL_STATUS=44: SQL_MSG$="INSERT REQUIRES VALUES"
        RETURN
    END IF
    VSTR$ = TRIM$(MID$(REST2$, VPOS+6))
    OP = INSTR(VSTR$, "("): CP = INSTR(VSTR$, ")")
    IF OP=0 OR CP=0 OR CP<OP THEN
        SQL_STATUS=45: SQL_MSG$="BAD VALUES"
        RETURN
    END IF
    VALS$ = TRIM$(MID$(VSTR$, OP+1, CP-OP-1))

    GOSUB AppendRecord
    SQL_MSG$ = "INSERTED " + TBL$ + " KEY " + KEY$
    RETURN


REM ==============================================================
REM  Append a record using ISAM PUT
REM  IN: TBL$, COLS$, KEY$, VALS$
REM ==============================================================
AppendRecord:
    STEMP$ = TBL$
    KTEMP$ = KEY$
    CTEMP$ = COLS$
    VTEMP$ = VALS$
    DIM R{}
    R{"key"} = KTEMP$
    CI = 1
    WHILE 1
        S$ = CTEMP$: D$ = ",": N = CI: GOSUB GetDelimToken$
        COL$ = GETD$
        IF COL$ = "" THEN EXIT WHILE
        S$ = VTEMP$: D$ = ",": N = CI: GOSUB GetDelimToken$
        VV$ = GETD$
        R{COL$} = VV$
        CI = CI + 1
    WEND

    TFN$ = DBPFX$ + "." + STEMP$ + ".idx"
    OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
    PUT #3, R{}
    CLOSE #3
    LBL$ = "APPENDED"
    MSG$ = "INSERT " + STEMP$ + " KEY " + KTEMP$
    GOSUB LogEvent
    RETURN


REM ==============================================================
REM  SELECT * FROM t [WHERE KEY=val | WHERE col=val]
REM                  [ORDER BY col [ASC|DESC]] [LIMIT n]
REM ==============================================================
DoSelect:
    SQL_RESULT$ = ""
    LIMIT = 0
    SELALL = 1
    HASDIST = 0
    SELCOLS$ = ""

    PF = INSTR(UP$, "FROM")
    IF PF = 0 THEN SQL_STATUS=50: SQL_MSG$="BAD SELECT": RETURN

    ISCOUNT = 0
    SELTMP$ = TRIM$(MID$(ST$, 7, PF - 7))
    IF LEFT$(UCASE$(SELTMP$), 6) = "COUNT(" THEN
        ISCOUNT = 1
        SELALL = 1
    END IF
    IF ISCOUNT = 0 THEN
        IF UCASE$(LEFT$(SELTMP$, 8)) = "DISTINCT" THEN
            HASDIST = 1
            SELTMP$ = TRIM$(MID$(SELTMP$, 9))
        END IF
        IF SELTMP$ <> "" AND SELTMP$ <> "*" THEN
            SELALL = 0
            SELCOLS$ = SELTMP$
        END IF
    END IF

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

    W$ = ""
    WHEREKEY = 0
    WKEYVAL$ = ""
    OCOL$ = "": ODIR$ = ""

    PW = INSTR(UCASE$(REST$), "WHERE")
    PO = INSTR(UCASE$(REST$), "ORDER BY")
    PL = INSTR(UCASE$(REST$), "LIMIT")

    IF PW > 0 THEN
        WEND$ = LEN(REST$) + 1
        IF PO > 0 AND PO > PW THEN WEND$ = PO
        IF PL > 0 AND PL > PW AND PL < WEND$ THEN WEND$ = PL
        W$ = TRIM$(MID$(REST$, PW+5, WEND$-PW-5))

        WU$ = UCASE$(W$)
        IF LEFT$(WU$, 4) = "KEY=" THEN WHEREKEY = 1
        IF LEFT$(WU$, 5) = "KEY =" THEN WHEREKEY = 1
        IF WHEREKEY = 1 THEN
            EQ = INSTR(W$, "=")
            WKEYVAL$ = TRIM$(MID$(W$, EQ+1))
        END IF
    END IF

    IF PO > 0 THEN
        OEND$ = LEN(REST$) + 1
        IF PL > 0 AND PL > PO THEN OEND$ = PL
        OCLAUSE$ = TRIM$(MID$(REST$, PO+9, OEND$-PO-9))
        OSP = INSTR(OCLAUSE$, " ")
        IF OSP = 0 THEN
            OCOL$ = OCLAUSE$
            ODIR$ = "ASC"
        ELSE
            OCOL$ = TRIM$(LEFT$(OCLAUSE$, OSP-1))
            ODIR$ = TRIM$(MID$(OCLAUSE$, OSP+1))
            ODIR$ = UCASE$(ODIR$)
            IF ODIR$ <> "DESC" THEN ODIR$ = "ASC"
        END IF
    END IF

    IF PL > 0 THEN
        LIMIT = VAL(TRIM$(MID$(REST$, PL+5)))
        IF LIMIT < 0 THEN LIMIT = 0
    END IF

    STBL$ = TBL$
    SCOLS$ = COLS$
    SPK$ = PK$

    IF WHEREKEY = 1 THEN
        TFN$ = DBPFX$ + "." + STBL$ + ".idx"
        OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
        DIM R{}
        GET #3, R{}, KEY = WKEYVAL$
        IF FOUND(3) THEN
            GOSUB BuildRowFromRec
            SQL_RESULT$ = FMT$ + CHR$(10)
        END IF
        CLOSE #3
        SQL_MSG$ = "OK"
        RETURN
    END IF

    TFN$ = DBPFX$ + "." + STBL$ + ".idx"
    OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
    DIM R{}
    RESET #3

    HASSORT = 0
    IF OCOL$ <> "" THEN HASSORT = 1
    MAXROW = 500
    DIM RSLT$(MAXROW)
    RCNT = 0
    ROWS = 0

    WHILE NOT EOF(3)
        GET #3, R{}, NEXT
        IF NOT FOUND(3) THEN GOTO SNX3

        IF W$ <> "" THEN
            GOSUB EvalWhere
            IF MATCH = 0 THEN GOTO SNX3
        END IF

        GOSUB BuildRowFromRec

        DUP = 0
        IF HASDIST = 1 THEN
            FOR DI = 0 TO RCNT - 1
                IF RSLT$(DI) = FMT$ THEN DUP = 1: EXIT FOR
            NEXT DI
        END IF

        IF DUP = 0 THEN
            IF HASSORT = 1 OR HASDIST = 1 THEN
                IF RCNT < MAXROW THEN
                    RSLT$(RCNT) = FMT$
                    RCNT = RCNT + 1
                END IF
            ELSE
                SQL_RESULT$ = SQL_RESULT$ + FMT$ + CHR$(10)
            END IF
        END IF

        ROWS = ROWS + 1
        IF LIMIT > 0 AND ROWS >= LIMIT THEN EXIT WHILE
SNX3:
        IF (ROWS MOD 50) = 0 THEN X = SLEEP(0.25)
    WEND
    CLOSE #3

    IF ISCOUNT = 1 THEN
        SQL_RESULT$ = "COUNT=" + STR$(ROWS)
        SQL_MSG$ = "OK"
        RETURN
    END IF

    IF HASSORT = 1 AND RCNT > 1 THEN
        GOSUB SortResultRows
    END IF

    IF HASSORT = 1 OR HASDIST = 1 THEN
        FOR SI = 0 TO RCNT - 1
            SQL_RESULT$ = SQL_RESULT$ + RSLT$(SI) + CHR$(10)
        NEXT SI
    END IF

    SQL_MSG$ = "OK"
    RETURN

REM  Build a result row from the current R{}
REM  IN: R{}, SPK$, SCOLS$, SELALL, SELCOLS$  OUT: FMT$
BuildRowFromRec:
    FMT$ = "R|" + SPK$ + "|" + R{SPK$}
    IF SELALL = 0 THEN
        COLSET$ = SELCOLS$
    ELSE
        COLSET$ = SCOLS$
    END IF
    CI = 1
    WHILE 1
        S$ = COLSET$: D$ = ",": N = CI: GOSUB GetDelimToken$
        C$ = GETD$
        IF C$ = "" THEN EXIT WHILE
        FMT$ = FMT$ + "|" + C$ + "=" + R{C$}
        CI = CI + 1
    WEND
    RETURN

REM  Sort RSLT$ array by OCOL$ in ODIR$ order
SortResultRows:
    FOR SI = 0 TO RCNT - 2
        FOR SJ = SI + 1 TO RCNT - 1
            NEED$ = "|" + OCOL$ + "="
            PI = INSTR(RSLT$(SI), NEED$)
            PJ = INSTR(RSLT$(SJ), NEED$)
            VI$ = ""
            VJ$ = ""
            IF PI > 0 THEN
                VI$ = MID$(RSLT$(SI), PI + LEN(NEED$))
                NXI = INSTR(VI$, "|")
                IF NXI > 0 THEN VI$ = LEFT$(VI$, NXI-1)
            END IF
            IF PJ > 0 THEN
                VJ$ = MID$(RSLT$(SJ), PJ + LEN(NEED$))
                NXJ = INSTR(VJ$, "|")
                IF NXJ > 0 THEN VJ$ = LEFT$(VJ$, NXJ-1)
            END IF

            SWAP = 0
            IF ODIR$ = "ASC" THEN
                IF VI$ > VJ$ THEN SWAP = 1
            ELSE
                IF VI$ < VJ$ THEN SWAP = 1
            END IF

            IF SWAP = 1 THEN
                TMP$ = RSLT$(SI)
                RSLT$(SI) = RSLT$(SJ)
                RSLT$(SJ) = TMP$
            END IF
        NEXT SJ
        IF (SI MOD 50) = 0 THEN X = SLEEP(0.25)
    NEXT SI
    RETURN


REM ==============================================================
REM  Evaluate a WHERE clause against row R{}
REM  IN: W$, R{}  OUT: MATCH (0/1)
REM  Supports: AND, OR, =, <, >, <=, >=, <>, LIKE
REM ==============================================================
EvalWhere:
    MATCH = 0
    IF W$ = "" THEN MATCH = 1: RETURN

    WOR$ = W$
    WP = 1
    WLEN = LEN(WOR$)
    WHILE 1
        WU$ = UCASE$(MID$(WOR$, WP))
        ORI = INSTR(WU$, " OR ")
        IF ORI = 0 THEN
            ANDP$ = MID$(WOR$, WP)
        ELSE
            ANDP$ = MID$(WOR$, WP, ORI - 1)
        END IF

        ANDMATCH = 1
        AP = 1
        WHILE AP <= LEN(ANDP$)
            AU$ = UCASE$(MID$(ANDP$, AP))
            ANI = INSTR(AU$, " AND ")
            IF ANI = 0 THEN
                CON$ = TRIM$(MID$(ANDP$, AP))
                AP = LEN(ANDP$) + 1
            ELSE
                CON$ = TRIM$(MID$(ANDP$, AP, ANI - 1))
                AP = AP + ANI + 4
            END IF
            IF CON$ <> "" THEN
                CACHE_CON$ = CON$
                GOSUB EvalSingleCond
                IF MATCH = 0 THEN ANDMATCH = 0
            END IF
        WEND

        IF ANDMATCH = 1 THEN MATCH = 1: RETURN
        IF ORI = 0 THEN EXIT WHILE
        WP = WP + ORI + 3
    WEND
    RETURN


REM ==============================================================
REM  Evaluate a single condition against row R{}
REM  IN: CON$, R{}  OUT: MATCH
REM  Operators: =, <, >, <=, >=, <>, LIKE
REM ==============================================================
EvalSingleCond:
    MATCH = 0
    CU$ = UCASE$(TRIM$(CON$))
    OPC = 0
    CCOL$ = ""
    CVAL$ = ""

    LI = INSTR(CU$, " LIKE ")
    IF LI > 0 THEN
        CCOL$ = TRIM$(LEFT$(CON$, LI - 1))
        CVAL$ = TRIM$(MID$(CON$, LI + 6))
        OPC = 7
        GOTO ES_EVAL
    END IF

    FOR OI = 1 TO LEN(CU$)
        O2$ = MID$(CU$, OI, 2)
        IF O2$ = "<=" THEN OPC = 4: GOTO ES_FOUND
        IF O2$ = ">=" THEN OPC = 5: GOTO ES_FOUND
        IF O2$ = "<>" THEN OPC = 6: GOTO ES_FOUND
        O1$ = MID$(CU$, OI, 1)
        IF O1$ = "=" THEN OPC = 1: GOTO ES_FOUND
        IF O1$ = "<" THEN OPC = 2: GOTO ES_FOUND
        IF O1$ = ">" THEN OPC = 3: GOTO ES_FOUND
    NEXT OI
    RETURN

ES_FOUND:
    CCOL$ = TRIM$(LEFT$(CON$, OI - 1))
    IF OPC >= 4 THEN
        CVAL$ = TRIM$(MID$(CON$, OI + 2))
    ELSE
        CVAL$ = TRIM$(MID$(CON$, OI + 1))
    END IF

ES_EVAL:
    IF CCOL$ = "" THEN RETURN
    RV$ = R{CCOL$}
    IF OPC = 1 THEN
        IF RV$ = CVAL$ THEN MATCH = 1
    ELSEIF OPC = 2 THEN
        IF RV$ < CVAL$ THEN MATCH = 1
    ELSEIF OPC = 3 THEN
        IF RV$ > CVAL$ THEN MATCH = 1
    ELSEIF OPC = 4 THEN
        IF RV$ <= CVAL$ THEN MATCH = 1
    ELSEIF OPC = 5 THEN
        IF RV$ >= CVAL$ THEN MATCH = 1
    ELSEIF OPC = 6 THEN
        IF RV$ <> CVAL$ THEN MATCH = 1
    ELSEIF OPC = 7 THEN
        RVU$ = UCASE$(RV$)
        LUV$ = UCASE$(CVAL$)
        IF LEFT$(LUV$, 1) = "%" AND RIGHT$(LUV$, 1) = "%" THEN
            T$ = MID$(LUV$, 2, LEN(LUV$) - 2)
            IF INSTR(RVU$, T$) > 0 THEN MATCH = 1
        ELSEIF LEFT$(LUV$, 1) = "%" THEN
            T$ = MID$(LUV$, 2)
            IF RIGHT$(RVU$, LEN(T$)) = T$ THEN MATCH = 1
        ELSEIF RIGHT$(LUV$, 1) = "%" THEN
            T$ = LEFT$(LUV$, LEN(LUV$) - 1)
            IF LEFT$(RVU$, LEN(T$)) = T$ THEN MATCH = 1
        ELSE
            IF RVU$ = LUV$ THEN MATCH = 1
        END IF
    END IF
    RETURN


REM ==============================================================
REM  Validate column exists in schema
REM  IN: COL$, COLS$  OUT: VALID (0/1)
REM ==============================================================
ValidateCol:
    VALID = 0
    IF COL$ = "" THEN RETURN
    CI = 1
    WHILE 1
        S$ = COLS$: D$ = ",": N = CI: GOSUB GetDelimToken$
        C$ = GETD$
        IF C$ = "" THEN EXIT WHILE
        IF UCASE$(C$) = UCASE$(COL$) THEN VALID = 1: RETURN
        CI = CI + 1
    WEND
    RETURN
DoUpdate:
    TMP$ = TRIM$(MID$(ST$, 7))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=60: SQL_MSG$="BAD UPDATE": RETURN
    TBL$ = TRIM$(LEFT$(TMP$, SP-1))
    REST$ = TRIM$(MID$(TMP$, SP+1))

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=61: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF

    USP = INSTR(UCASE$(REST$), "SET")
    IF USP = 0 THEN
        SQL_STATUS=64: SQL_MSG$="UPDATE REQUIRES SET"
        RETURN
    END IF
    SET$ = TRIM$(MID$(REST$, USP+3))

    UKP = INSTR(UCASE$(REST$), "KEY")
    UWP = INSTR(UCASE$(REST$), "WHERE")

    IF UKP > 0 AND UKP < USP THEN
        KEY$ = TRIM$(MID$(REST$, UKP+4, USP-UKP-4))
        IF KEY$ = "" THEN
            SQL_STATUS=62: SQL_MSG$="BAD KEY"
            RETURN
        END IF

        TFN$ = DBPFX$ + "." + TBL$ + ".idx"
        OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
        DIM R{}
        GET #3, R{}, KEY = KEY$
        IF NOT FOUND(3) THEN
            CLOSE #3: SQL_STATUS=66: SQL_MSG$="KEY NOT FOUND"
            RETURN
        END IF

        SETLOG$ = ""
        SCI = 1
        WHILE 1
            S$ = SET$: D$ = ",": N = SCI: GOSUB GetDelimToken$
            ASGN$ = GETD$
            IF ASGN$ = "" THEN EXIT WHILE
            EQ = INSTR(ASGN$, "=")
            IF EQ = 0 THEN
                CLOSE #3: SQL_STATUS=65: SQL_MSG$="BAD SET"
                RETURN
            END IF
            UCOL$ = TRIM$(LEFT$(ASGN$, EQ-1))
            UVAL$ = TRIM$(MID$(ASGN$, EQ+1))
            IF SETLOG$ <> "" THEN SETLOG$ = SETLOG$ + ","
            SETLOG$ = SETLOG$ + UCOL$ + "=" + UVAL$
            R{UCOL$} = UVAL$
            SCI = SCI + 1
        WEND

        PUT #3, R{}
        CLOSE #3
        LBL$ = "UPDATED"
        MSG$ = "UPDATE " + TBL$ + " KEY " + KEY$ + " "
        MSG$ = MSG$ + SETLOG$
        GOSUB LogEvent
        SQL_MSG$ = "UPDATED " + TBL$ + " KEY " + KEY$
        RETURN

    ELSEIF UWP > 0 AND UWP < USP THEN
        W$ = TRIM$(MID$(REST$, UWP+5, USP-UWP-5))

        TFN$ = DBPFX$ + "." + TBL$ + ".idx"
        OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
        DIM R{}
        RESET #3
        UPDCNT = 0
        WHILE NOT EOF(3)
            GET #3, R{}, NEXT
            IF NOT FOUND(3) THEN GOTO UPBX
            GOSUB EvalWhere
            IF MATCH = 1 THEN
                SCI = 1
                WHILE 1
                    S$ = SET$: D$ = ",": N = SCI
                    GOSUB GetDelimToken$
                    ASGN$ = GETD$
                    IF ASGN$ = "" THEN EXIT WHILE
                    EQ = INSTR(ASGN$, "=")
                    IF EQ > 0 THEN
                        UCOL$ = TRIM$(LEFT$(ASGN$, EQ-1))
                        UVAL$ = TRIM$(MID$(ASGN$, EQ+1))
                        R{UCOL$} = UVAL$
                    END IF
                    SCI = SCI + 1
                WEND
                PUT #3, R{}
                UPDCNT = UPDCNT + 1
            END IF
UPBX:
            IF (UPDCNT MOD 50) = 0 THEN X = SLEEP(0.25)
        WEND
        CLOSE #3
        LBL$ = "UPDATED"
        MSG$ = "BULK UPDATE " + TBL$ + " "
        MSG$ = MSG$ + STR$(UPDCNT) + " rows"
        GOSUB LogEvent
        SQL_MSG$ = "UPDATED " + STR$(UPDCNT)
        SQL_MSG$ = SQL_MSG$ + " ROWS IN " + TBL$
        RETURN
    END IF

    SQL_STATUS=62: SQL_MSG$="UPDATE NEEDS KEY OR WHERE"
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
        SQL_STATUS=71: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF

    PKPOS = INSTR(UCASE$(REST$), "KEY")
    IF PKPOS = 0 THEN
        SQL_STATUS=72: SQL_MSG$="REPLACE REQUIRES KEY"
        RETURN
    END IF
    TMP2$ = TRIM$(MID$(REST$, PKPOS+3))
    SP2 = INSTR(TMP2$, " ")
    IF SP2 = 0 THEN
        SQL_STATUS=73: SQL_MSG$="REPLACE REQUIRES VALUES"
        RETURN
    END IF
    KEY$ = TRIM$(LEFT$(TMP2$, SP2-1))
    REST2$ = TRIM$(MID$(TMP2$, SP2+1))

    VPOS = INSTR(UCASE$(REST2$), "VALUES")
    IF VPOS = 0 THEN
        SQL_STATUS=74: SQL_MSG$="REPLACE REQUIRES VALUES"
        RETURN
    END IF
    VSTR$ = TRIM$(MID$(REST2$, VPOS+6))
    OP = INSTR(VSTR$, "("): CP = INSTR(VSTR$, ")")
    IF OP=0 OR CP=0 OR CP<OP THEN
        SQL_STATUS=75: SQL_MSG$="BAD VALUES"
        RETURN
    END IF
    VALS$ = TRIM$(MID$(VSTR$, OP+1, CP-OP-1))

    DIM R{}
    R{"key"} = KEY$
    CI = 1
    WHILE 1
        S$ = COLS$: D$ = ",": N = CI: GOSUB GetDelimToken$
        COL$ = GETD$
        IF COL$ = "" THEN EXIT WHILE
        S$ = VALS$: D$ = ",": N = CI: GOSUB GetDelimToken$
        VV$ = GETD$
        R{COL$} = VV$
        CI = CI + 1
    WEND

    TFN$ = DBPFX$ + "." + TBL$ + ".idx"
    OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
    PUT #3, R{}
    CLOSE #3
    LBL$ = "UPDATED"
    MSG$ = "REPLACE " + TBL$ + " KEY " + KEY$
    GOSUB LogEvent
    SQL_MSG$ = "REPLACED " + TBL$ + " KEY " + KEY$
    RETURN


REM ==============================================================
REM  DELETE FROM t KEY k
REM ==============================================================
DoDelete:
    PF = INSTR(UP$, "FROM")
    IF PF = 0 THEN SQL_STATUS=80: SQL_MSG$="BAD DELETE": RETURN
    TMP$ = TRIM$(MID$(ST$, PF+4))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=81: SQL_MSG$="BAD DELETE": RETURN
    TBL$ = TRIM$(LEFT$(TMP$, SP-1))
    REST$ = TRIM$(MID$(TMP$, SP+1))

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=61: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF

    PKPOS = INSTR(UCASE$(REST$), "KEY")
    WP = INSTR(UCASE$(REST$), "WHERE")

    IF PKPOS > 0 THEN
        KEY$ = TRIM$(MID$(REST$, PKPOS+3))
        TFN$ = DBPFX$ + "." + TBL$ + ".idx"
        OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
        DELETE #3, KEY = KEY$
        CLOSE #3
        LBL$ = "DELETED"
        MSG$ = "DELETE " + TBL$ + " KEY " + KEY$
        GOSUB LogEvent
        SQL_MSG$ = "DELETED " + TBL$ + " KEY " + KEY$
        RETURN

    ELSEIF WP > 0 THEN
        W$ = TRIM$(MID$(REST$, WP+5))

        TFN$ = DBPFX$ + "." + TBL$ + ".idx"
        OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
        DIM R{}
        RESET #3
        DELCNT = 0
        WHILE NOT EOF(3)
            GET #3, R{}, NEXT
            IF NOT FOUND(3) THEN GOTO DLNX
            GOSUB EvalWhere
            IF MATCH = 1 THEN
                DELETE #3, KEY = R{"key"}
                DELCNT = DELCNT + 1
            END IF
DLNX:
            IF (DELCNT MOD 50) = 0 THEN X = SLEEP(0.25)
        WEND
        CLOSE #3
        LBL$ = "DELETED"
        MSG$ = "BULK DELETE " + TBL$ + " "
        MSG$ = MSG$ + STR$(DELCNT) + " rows"
        GOSUB LogEvent
        SQL_MSG$ = "DELETED " + STR$(DELCNT)
        SQL_MSG$ = SQL_MSG$ + " ROWS FROM " + TBL$
        RETURN
    END IF

    SQL_STATUS=82: SQL_MSG$="DELETE REQUIRES KEY/WHERE"
    RETURN


REM ==============================================================
REM  DROP TABLE t
REM ==============================================================
DoDrop:
    TMP$ = TRIM$(MID$(ST$, 5))
    IF TMP$ = "" THEN SQL_STATUS=85: SQL_MSG$="BAD DROP": RETURN
    TBL$ = TMP$

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=86: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF

    GOSUB GetTableFN
    OPEN TFN$ FOR OUTPUT AS #3
    CLOSE #3

    GOSUB DelSchema
    LBL$ = "DELETED": MSG$ = "DROP TABLE " + TBL$: GOSUB LogEvent
    SQL_MSG$ = "DROPPED TABLE " + TBL$
    RETURN


REM ==============================================================
REM  SHOW TABLES
REM ==============================================================
DoShow:
    IF UCASE$(TRIM$(ST$)) <> "SHOW TABLES" THEN
        SQL_STATUS=88: SQL_MSG$="BAD SHOW"
        RETURN
    END IF
    SQL_RESULT$ = ""
    OPEN SYSFN$ FOR INDEXED AS #2 KEY = "name"
    DIM S{}
    RESET #2
    WHILE NOT EOF(2)
        GET #2, S{}, NEXT
        IF FOUND(2) AND S{"name"} <> "_schema_meta" THEN
            SQL_RESULT$ = SQL_RESULT$ + S{"name"} + CHR$(10)
        END IF
        X = SLEEP(0.1)
    WEND
    CLOSE #2
    SQL_MSG$ = "OK"
    RETURN


REM ==============================================================
REM  DESCRIBE table
REM ==============================================================
DoDescribe:
    TMP$ = TRIM$(MID$(ST$, 9))
    IF TMP$ = "" THEN SQL_STATUS=89: SQL_MSG$="BAD DESCRIBE": RETURN
    TBL$ = TMP$
    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=51: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF
    SQL_RESULT$ = "TBL=" + TBL$ + CHR$(10)
    SQL_RESULT$ = SQL_RESULT$ + "COLS=" + COLS$ + CHR$(10)
    SQL_RESULT$ = SQL_RESULT$ + "PK=" + PK$
    SQL_MSG$ = "OK"
    RETURN


REM ==============================================================
REM  ALTER TABLE t ADD col / DROP col
REM ==============================================================
DoAlter:
    TMP$ = TRIM$(MID$(ST$, 12))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=87: SQL_MSG$="BAD ALTER": RETURN
    TBL$ = TRIM$(LEFT$(TMP$, SP-1))
    REST$ = TRIM$(MID$(TMP$, SP+1))
    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=51: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF
    AU$ = UCASE$(REST$)
    IF LEFT$(AU$, 4) = "ADD " THEN
        NEWCOL$ = TRIM$(MID$(REST$, 5))
        COL$ = NEWCOL$: GOSUB ValidateCol
        IF VALID = 1 THEN
            SQL_STATUS=87: SQL_MSG$="COLUMN EXISTS"
            RETURN
        END IF
        COLS$ = COLS$ + "," + NEWCOL$
        GOSUB PutSchema
        SQL_MSG$ = "ALTER ADD " + NEWCOL$ + " TO " + TBL$
        RETURN
    ELSEIF LEFT$(AU$, 5) = "DROP " THEN
        DCOL$ = TRIM$(MID$(REST$, 6))
        NEWCOLS$ = ""
        CI = 1
        WHILE 1
            S$ = COLS$: D$ = ",": N = CI: GOSUB GetDelimToken$
            C$ = GETD$
            IF C$ = "" THEN EXIT WHILE
            IF UCASE$(C$) <> UCASE$(DCOL$) THEN
                IF NEWCOLS$ <> "" THEN NEWCOLS$ = NEWCOLS$ + ","
                NEWCOLS$ = NEWCOLS$ + C$
            END IF
            CI = CI + 1
        WEND
        COLS$ = NEWCOLS$
        GOSUB PutSchema
        SQL_MSG$ = "ALTER DROP " + DCOL$ + " FROM " + TBL$
        LBL$ = "UPDATED"
        MSG$ = "ALTER TABLE " + TBL$ + " DROP " + DCOL$
        GOSUB LogEvent
        RETURN
    END IF
    SQL_STATUS=87: SQL_MSG$="BAD ALTER"
    RETURN


REM ==============================================================
REM  SEARCH: SQL_STMT$ = "table|term|col(optional)|mode(optional)"
REM  modes: CONTAINS (default), EXACT, PREFIX, SUFFIX
REM ==============================================================
SearchCmd:
    SQL_RESULT$ = ""

    S$ = SQL_STMT$: D$ = "|": N = 1: GOSUB GetDelimToken$
    TBL$ = GETD$
    S$ = SQL_STMT$: D$ = "|": N = 2: GOSUB GetDelimToken$
    TERM$ = GETD$
    S$ = SQL_STMT$: D$ = "|": N = 3: GOSUB GetDelimToken$
    COLF$ = GETD$
    S$ = SQL_STMT$: D$ = "|": N = 4: GOSUB GetDelimToken$
    SMODE$ = UCASE$(GETD$)

    IF TBL$ = "" OR TERM$ = "" THEN
        SQL_STATUS=90: SQL_MSG$="SEARCH NEEDS table|term"
        RETURN
    END IF
    IF SMODE$ = "" THEN SMODE$ = "CONTAINS"

    GOSUB GetSchema
    IF COLS$ = "" THEN SQL_STATUS=91: SQL_MSG$="NO SUCH TABLE": RETURN

    STBL$ = TBL$
    SCOLS$ = COLS$
    SPK$ = PK$
    STERM$ = UCASE$(TERM$)

    TFN$ = DBPFX$ + "." + STBL$ + ".idx"
    OPEN TFN$ FOR INDEXED AS #3 KEY = "key"
    DIM R{}
    RESET #3
    RC = 0
    WHILE NOT EOF(3)
        GET #3, R{}, NEXT
        IF NOT FOUND(3) THEN GOTO SCNX3
        IF COLF$ = "" THEN
            FOUND$ = "0"
            CI = 1
            WHILE 1
                S$ = SCOLS$: D$ = ",": N = CI: GOSUB GetDelimToken$
                C$ = GETD$
                IF C$ = "" THEN EXIT WHILE
                GOSUB MatchField
                IF MATCH = 1 THEN FOUND$ = "1"
                CI = CI + 1
            WEND
            IF FOUND$ = "1" THEN GOSUB BuildResultRow
        ELSE
            C$ = COLF$
            GOSUB MatchField
            IF MATCH = 1 THEN GOSUB BuildResultRow
        END IF
SCNX3:
        IF (RC MOD 50) = 0 THEN X = SLEEP(0.25)
    WEND
    CLOSE #3
    SQL_MSG$ = "OK"
    RETURN

REM  Match a field value against the search term
REM  IN: C$, R{}, STERM$, SMODE$  OUT: MATCH
MatchField:
    MATCH = 0
    FV$ = UCASE$(R{C$})
    IF SMODE$ = "EXACT" THEN
        IF FV$ = STERM$ THEN MATCH = 1
    ELSEIF SMODE$ = "PREFIX" THEN
        IF LEFT$(FV$, LEN(STERM$)) = STERM$ THEN MATCH = 1
    ELSEIF SMODE$ = "SUFFIX" THEN
        IF LEN(FV$) >= LEN(STERM$) THEN
            IF RIGHT$(FV$, LEN(STERM$)) = STERM$ THEN MATCH = 1
        END IF
    ELSE
        IF INSTR(FV$, STERM$) > 0 THEN MATCH = 1
    END IF
    RETURN

REM  Build result row for SEARCH (uses R{}, SPK$, SCOLS$)
BuildResultRow:
    FMT$ = "R|" + SPK$ + "|" + R{SPK$}
    CI = 1
    WHILE 1
        S$ = SCOLS$: D$ = ",": N = CI: GOSUB GetDelimToken$
        C$ = GETD$
        IF C$ = "" THEN EXIT WHILE
        FMT$ = FMT$ + "|" + C$ + "=" + R{C$}
        CI = CI + 1
    WEND
    SQL_RESULT$ = SQL_RESULT$ + FMT$ + CHR$(10)
    RC = RC + 1
    RETURN


REM ==============================================================
REM  TRANSACTIONS using batch.dat
REM ==============================================================
TxnBegin:
    OPEN BATFN$ FOR OUTPUT AS #4
    PRINT #4, "BEGIN"
    CLOSE #4
    LBL$ = "OPEN": MSG$ = "Transaction started": GOSUB LogEvent
    SQL_MSG$ = "TXN BEGIN"
    RETURN

TxnRollback:
    OPEN BATFN$ FOR OUTPUT AS #4
    CLOSE #4
    LBL$ = "CLOSED": MSG$ = "Transaction rolled back": GOSUB LogEvent
    SQL_MSG$ = "TXN ROLLBACK"
    RETURN

TxnCommit:
    OPEN BATFN$ FOR INPUT AS #4
    IF EOF(4) THEN CLOSE #4: SQL_MSG$="NO TXN": RETURN
    INPUT #4, L$
    L$ = TRIM$(L$)
    IF L$ <> "BEGIN" THEN CLOSE #4: SQL_MSG$="NO TXN": RETURN

    N = 0
    OLD$ = SQL_STMT$
    OLDM$ = SQL_MODE$
    SQL_MODE$ = "RW"
    WHILE NOT EOF(4)
        INPUT #4, L$
        L$ = TRIM$(L$)
        IF L$ <> "" THEN
            N = N + 1
            SQL_STMT$ = L$
            GOSUB ExecSQL
            IF SQL_STATUS <> 0 THEN
                CLOSE #4
                OPEN BATFN$ FOR OUTPUT AS #4
                CLOSE #4
                SQL_STMT$ = OLD$
                SQL_MODE$ = OLDM$
                TMPMSG$ = SQL_MSG$
                SQL_MSG$ = "TXN ABORTED AT STMT "
                SQL_MSG$ = SQL_MSG$ + STR$(N) + ": " + TMPMSG$
                LBL$ = "ERROR"
                MSG$ = "Transaction aborted at stmt " + STR$(N)
                GOSUB LogEvent
                RETURN
            END IF
        END IF
    WEND
    CLOSE #4

    OPEN BATFN$ FOR OUTPUT AS #4
    CLOSE #4
    SQL_STMT$ = OLD$
    SQL_MODE$ = OLDM$
    LBL$ = "CLOSED"
    MSG$ = "Transaction committed (" + STR$(N) + " stmts)"
    GOSUB LogEvent
    SQL_MSG$ = "TXN COMMIT (" + STR$(N) + " stmts)"
    RETURN


REM ==============================================================
REM  Token helper (uses S$, D$, N as input, returns GETD$)
REM ==============================================================
GetDelimToken$:
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
            GETD$ = TRIM$(PART$)
            RETURN
        END IF
        IF Q = 0 THEN
            GETD$ = ""
            RETURN
        END IF
        P = P + Q
        K = K + 1
    WEND
    RETURN

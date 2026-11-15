REM ==============================================================
REM  MINISQL.BAS  v0.6.0  (LABEL-BASED / CHAINABLE)
REM --------------------------------------------------------------
REM  ISAM-based SQL engine for 3270BBS.
REM  Uses the platform's built-in INDEXED file system as the
REM  storage foundation instead of custom flat-file management.
REM
REM  FILENAMES (data names: letters/digits/'_', ONE dot only):
REM    <db>_<table>.idx   - ISAM file per user table
REM    <db>_schema.idx    - ISAM system table for schemas
REM    <db>_log.dat       - event log (file handle #1, always open)
REM    batch.dat          - transaction batch queue
REM    Filename encoding: '-' -> '_', '_' -> '__' (reversible).
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
REM  Helpers: sanitize DB name for use in a data filename
REM  Data filenames allow letters, digits and '_' and ONE dot.
REM  Any other character is converted to '_'.
REM ==============================================================
SanitizeDB:
    IN$ = SQL_DB$
    GOSUB EscName
    DBPFX$ = ESC$
    IF DBPFX$ = "" THEN DBPFX$ = "DB"
    RETURN


REM ==============================================================
REM  Reversible filename encoding
REM  Data filenames allow letters, digits and '_' only.
REM  '_' -> '__' and '-' -> '_' so a-b and a_b cannot collide.
REM  Any other character maps to '_'.
REM ==============================================================
EscName:
    REM IN: IN$  OUT: ESC$
    ESC$ = ""
    FOR J = 1 TO LEN(IN$)
        C$ = MID$(IN$, J, 1)
        IF C$ = "_" THEN
            ESC$ = ESC$ + "__"
        ELSEIF C$ = "-" THEN
            ESC$ = ESC$ + "_"
        ELSEIF C$ >= "0" AND C$ <= "9" THEN
            ESC$ = ESC$ + C$
        ELSEIF UCASE$(C$) >= "A" AND UCASE$(C$) <= "Z" THEN
            ESC$ = ESC$ + C$
        ELSE
            ESC$ = ESC$ + "_"
        END IF
    NEXT J
    RETURN


REM ==============================================================
REM  Init/Open log file and read options header
REM  The log file is created with APPEND first: FOR INPUT on a
REM  missing file is a runtime error on this interpreter.
REM ==============================================================
InitLog:
    LOGF$ = DBPFX$ + "_log.dat"
    BATF$ = "batch.dat"
    SYSF$ = DBPFX$ + "_schema.idx"

    DIM OPT{}
    OPT{"100"} = "0.6.0"
    OPT{"101"} = "0"
    OPT{"102"} = "10000"
    FOR I = 103 TO 109
        OPT{TRIM$(STR$(I))} = "0"
    NEXT I
    OPT{"200"} = "1"
    OPT{"201"} = "1"
    FOR I = 202 TO 209
        OPT{TRIM$(STR$(I))} = "0"
    NEXT I
    OPT{"300"} = "1"
    OPT{"301"} = "100"
    FOR I = 302 TO 309
        OPT{TRIM$(STR$(I))} = "0"
    NEXT I

    OPEN LOGF$ FOR APPEND AS #1
    CLOSE #1
    OPEN LOGF$ FOR INPUT AS #1
    IF EOF(1) THEN
        CLOSE #1
        OPEN LOGF$ FOR APPEND AS #1
        HDR$ = "HDR|" + DBPFX$ + "|" + OPT{"100"} + "|"
        PRINT #1, HDR$ + DATE$() + "T" + TIME$()
        PRINT #1, "OPT|100|" + OPT{"100"}
        FOR I = 101 TO 109
            K$ = TRIM$(STR$(I))
            PRINT #1, "OPT|" + K$ + "|" + OPT{K$}
        NEXT I
        FOR I = 200 TO 209
            K$ = TRIM$(STR$(I))
            PRINT #1, "OPT|" + K$ + "|" + OPT{K$}
        NEXT I
        FOR I = 300 TO 309
            K$ = TRIM$(STR$(I))
            PRINT #1, "OPT|" + K$ + "|" + OPT{K$}
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
                K$ = TRIM$(LEFT$(REST$, P-1))
                V$ = MID$(REST$, P+1)
                OPT{K$} = V$
            END IF
        END IF
    WEND
    CLOSE #1

    OPEN LOGF$ FOR APPEND AS #1
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
    OPEN SYSF$ FOR APPEND AS #2
    CLOSE #2
    OPEN SYSF$ FOR INDEXED AS #2 KEY = "name"
    DIM S{}
    S{"name"} = "_schema_meta"
    S{"value"} = "v1"
    S{"seq"} = "0"
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
    OPEN SYSF$ FOR APPEND AS #2
    CLOSE #2
    OPEN SYSF$ FOR INDEXED AS #2 KEY = "name"
    DIM S{}
    GET #2, S{}, KEY = TBL$
    IF FOUND(2) THEN
        COLS$ = S{"cols"}
        PK$ = S{"pk"}
        SEQ = VAL(S{"seq"})
    END IF
    CLOSE #2
    RETURN

PutSchema:
    REM IN: TBL$, COLS$, PK$, NEWSEQ
    OPEN SYSF$ FOR INDEXED AS #2 KEY = "name"
    DIM S{}
    S{"name"} = TBL$
    S{"cols"} = COLS$
    S{"pk"} = PK$
    S{"seq"} = TRIM$(STR$(NEWSEQ))
    PUT #2, S{}
    CLOSE #2
    RETURN

UpdateSeq:
    REM IN: TBL$, SEQ (new sequence value)
    OPEN SYSF$ FOR INDEXED AS #2 KEY = "name"
    DIM S{}
    GET #2, S{}, KEY = TBL$
    IF FOUND(2) THEN
        S{"seq"} = TRIM$(STR$(SEQ))
        PUT #2, S{}
    END IF
    CLOSE #2
    RETURN

DelSchema:
    REM IN: TBL$
    OPEN SYSF$ FOR INDEXED AS #2 KEY = "name"
    DELETE #2, KEY = TBL$
    CLOSE #2
    RETURN


REM ==============================================================
REM  Table file helpers
REM ==============================================================
GetTableF:
    REM IN: TBL$  OUT: TF$
    IN$ = TBL$
    GOSUB EscName
    TF$ = DBPFX$ + "_" + ESC$ + ".idx"
    RETURN

CheckTbl:
    REM IN: TBL$  OUT: BADNAME (0=ok 1=bad)
    REM Letters, digits, '-' and '_' only; total name <= 32 chars
    BADNAME = 0
    IF TBL$ = "" THEN BADNAME = 1
    IF BADNAME = 0 THEN
        IN$ = TBL$
        GOSUB EscName
        IF LEN(DBPFX$) + LEN(ESC$) + 5 > 32 THEN BADNAME = 1
    END IF
    IF BADNAME = 0 THEN
        FOR TJ = 1 TO LEN(TBL$)
            TC$ = MID$(TBL$, TJ, 1)
            TV = 0
            IF TC$ = "-" OR TC$ = "_" THEN TV = 1
            IF TC$ >= "0" AND TC$ <= "9" THEN TV = 1
            IF UCASE$(TC$) >= "A" AND UCASE$(TC$) <= "Z" THEN TV = 1
            IF TV = 0 THEN BADNAME = 1
        NEXT TJ
    END IF
    RETURN

BadName:
    SQL_STATUS = 13
    SQL_MSG$ = "BAD TABLE NAME"
    RETURN

CheckCol:
    REM IN: C$  OUT: BADCOL (0=ok 1=bad)
    REM Letters, digits, '-' and '_' only; 'key' is reserved.
    BADCOL = 0
    IF C$ = "" THEN BADCOL = 1
    IF LCASE$(C$) = "key" THEN BADCOL = 1
    IF BADCOL = 0 THEN
        FOR CJ = 1 TO LEN(C$)
            CC$ = MID$(C$, CJ, 1)
            CV = 0
            IF CC$ = "-" OR CC$ = "_" THEN CV = 1
            IF CC$ >= "0" AND CC$ <= "9" THEN CV = 1
            IF UCASE$(CC$) >= "A" AND UCASE$(CC$) <= "Z" THEN CV = 1
            IF CV = 0 THEN BADCOL = 1
        NEXT CJ
    END IF
    RETURN

BadAlter:
    SQL_STATUS = 87
    SQL_MSG$ = "BAD ALTER"
    RETURN

NormList:
    REM IN: L$  OUT: NL$ (lowercased comma-separated list)
    NL$ = ""
    CI = 1
    WHILE 1
        S$ = L$: D$ = ",": N = CI: GOSUB GetToken
        C$ = GETD$
        IF C$ = "" THEN GOTO NLX
        IF NL$ <> "" THEN NL$ = NL$ + ","
        NL$ = NL$ + LCASE$(C$)
        CI = CI + 1
    WEND
NLX:
    RETURN


REM ==============================================================
REM  EXEC SQL dispatcher
REM ==============================================================
ExecSQL:
    ST$ = TRIM$(SQL_STMT$)
    IF ST$ = "" THEN SQL_STATUS=11: SQL_MSG$="EMPTY SQL": RETURN

    UP$ = UCASE$(ST$)

    REM Mode checks run BEFORE the transaction queue check so a
    REM disallowed write cannot be queued and later committed as RW.
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

    IF OPT{"300"} = "1" THEN
        OPEN BATF$ FOR APPEND AS #4
        CLOSE #4
        OPEN BATF$ FOR INPUT AS #4
        IF NOT EOF(4) THEN
            INPUT #4, L$
            L$ = TRIM$(L$)
            IF L$ = "BEGIN" THEN
                CLOSE #4
                IF LEFT$(UP$, 6) <> "SELECT" THEN
                    OPEN BATF$ FOR APPEND AS #4
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

    IF LEFT$(UP$, 12) = "CREATE TABLE" THEN GOSUB DoCreate: RETURN
    IF LEFT$(UP$, 6) = "INSERT" THEN GOSUB DoInsert: RETURN
    IF LEFT$(UP$, 6) = "SELECT" THEN GOSUB DoSelect: RETURN
    IF LEFT$(UP$, 6) = "UPDATE" THEN GOSUB DoUpdate: RETURN
    IF LEFT$(UP$, 7) = "REPLACE" THEN GOSUB DoReplace: RETURN
    IF LEFT$(UP$, 6) = "DELETE" THEN GOSUB DoDelete: RETURN
    IF LEFT$(UP$, 4) = "DROP" THEN GOSUB DoDrop: RETURN
    IF LEFT$(UP$, 4) = "SHOW" THEN GOSUB DoShow: RETURN
    IF LEFT$(UP$, 8) = "DESCRIBE" THEN GOSUB DoDescribe: RETURN
    IF LEFT$(UP$, 11) = "ALTER TABLE" THEN GOSUB DoAlter: RETURN

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
    TBL$ = LCASE$(TRIM$(LEFT$(TMP$, SP-1)))
    REST$ = TRIM$(MID$(TMP$, SP+1))
    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN

    GOSUB GetSchema
    IF COLS$ <> "" THEN SQL_STATUS=33: SQL_MSG$="TABLE EXISTS": RETURN

    OP = INSTR(REST$, "(")
    CP = INSTR(REST$, ")")
    IF OP = 0 OR CP = 0 OR CP < OP THEN
        SQL_STATUS=32: SQL_MSG$="BAD COL LIST"
        RETURN
    END IF
    L$ = TRIM$(MID$(REST$, OP+1, CP-OP-1))
    GOSUB NormList
    COLS$ = NL$
    IF COLS$ = "" THEN SQL_STATUS=32: SQL_MSG$="BAD COL LIST": RETURN

    REM "key" is the reserved ISAM key field name
    CI = 1
    MORECOL = 1
    WHILE MORECOL = 1
        S$ = COLS$: D$ = ",": N = CI: GOSUB GetToken
        C$ = GETD$
        IF C$ = "" THEN
            MORECOL = 0
        ELSE
            GOSUB CheckCol
            IF BADCOL = 1 THEN
                SQL_STATUS = 32
                SQL_MSG$ = "BAD COLUMN NAME"
                RETURN
            END IF
            CI = CI + 1
        END IF
    WEND

    PK$ = "key"
    RTAIL$ = TRIM$(MID$(REST$, CP+1))
    PPK = INSTR(UCASE$(RTAIL$), "PK")
    IF PPK > 0 THEN
        PK$ = LCASE$(TRIM$(MID$(RTAIL$, PPK+2)))
        IF PK$ = "" THEN PK$ = "key"
    END IF

    GOSUB GetTableF
    OPEN TF$ FOR OUTPUT AS #3
    CLOSE #3

    NEWSEQ = 0
    GOSUB PutSchema
    LBL$ = "UPDATED": MSG$ = "TABLE CREATED " + TBL$: GOSUB LogEvent
    SQL_MSG$ = "TABLE CREATED: " + TBL$
    RETURN


REM ==============================================================
REM  INSERT INTO t [KEY k|*] VALUES (v1,v2,...)
REM  KEY optional - omitting or using KEY * auto-generates a
REM  numeric key from the table's sequence counter.
REM ==============================================================
DoInsert:
    P = INSTR(UP$, "INTO")
    IF P = 0 THEN SQL_STATUS=40: SQL_MSG$="BAD INSERT": RETURN
    TMP$ = TRIM$(MID$(ST$, P+4))

    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=41: SQL_MSG$="BAD INSERT": RETURN
    TBL$ = LCASE$(TRIM$(LEFT$(TMP$, SP-1)))
    REST$ = TRIM$(MID$(TMP$, SP+1))
    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN

    GOSUB GetSchema
    IF COLS$ = "" THEN SQL_STATUS=46: SQL_MSG$="NO SUCH TABLE": RETURN

    VPOS = INSTR(UCASE$(REST$), "VALUES")
    IF VPOS = 0 THEN
        SQL_STATUS=44: SQL_MSG$="INSERT REQUIRES VALUES"
        RETURN
    END IF
    PRE$ = TRIM$(LEFT$(REST$, VPOS-1))
    AUTO = 1
    KVAL$ = ""
    IF LEFT$(UCASE$(PRE$), 4) = "KEY " THEN
        KVAL$ = TRIM$(MID$(PRE$, 4))
        IF KVAL$ = "" THEN
            SQL_STATUS=43: SQL_MSG$="BAD KEY"
            RETURN
        END IF
        IF KVAL$ = "*" THEN AUTO = 1 ELSE AUTO = 0
    ELSEIF PRE$ <> "" THEN
        SQL_STATUS=41: SQL_MSG$="BAD INSERT"
        RETURN
    END IF

    IF AUTO = 1 THEN
AutoKey:
        SEQ = SEQ + 1
        KVAL$ = TRIM$(STR$(SEQ))
        GOSUB GetTableF
        OPEN TF$ FOR INDEXED AS #3 KEY = "key"
        DIM D{}
        GET #3, D{}, KEY = KVAL$
        KFND = FOUND(3)
        CLOSE #3
        IF KFND = 1 THEN
            WC = SEQ: GOSUB Watchdog
            GOTO AutoKey
        END IF
        GOSUB UpdateSeq
    ELSE
        GOSUB GetTableF
        OPEN TF$ FOR INDEXED AS #3 KEY = "key"
        DIM D{}
        GET #3, D{}, KEY = KVAL$
        KFND = FOUND(3)
        CLOSE #3
        IF KFND = 1 THEN
            SQL_STATUS=47: SQL_MSG$="DUPLICATE KEY"
            RETURN
        END IF
    END IF

    VSTR$ = TRIM$(MID$(REST$, VPOS+6))
    OP = INSTR(VSTR$, "("): CP = INSTR(VSTR$, ")")
    IF OP=0 OR CP=0 OR CP<OP THEN
        SQL_STATUS=45: SQL_MSG$="BAD VALUES"
        RETURN
    END IF
    VALS$ = TRIM$(MID$(VSTR$, OP+1, CP-OP-1))

    GOSUB AppendRecord
    SQL_MSG$ = "INSERTED " + TBL$ + " KEY " + KVAL$
    RETURN


REM ==============================================================
REM  Append a record using ISAM PUT
REM  IN: TBL$, COLS$, KVAL$, VALS$
REM ==============================================================
AppendRecord:
    STEMP$ = TBL$
    KTEMP$ = KVAL$
    CTEMP$ = COLS$
    VTEMP$ = VALS$
    DIM R{}
    R{"key"} = KTEMP$
    CI = 1
    WHILE 1
        S$ = CTEMP$: D$ = ",": N = CI: GOSUB GetToken
        COL$ = GETD$
        IF COL$ = "" THEN GOTO ARX
        S$ = VTEMP$: D$ = ",": N = CI: GOSUB GetToken
        VV$ = GETD$
        R{COL$} = VV$
        CI = CI + 1
    WEND
ARX:

    GOSUB GetTableF
    OPEN TF$ FOR INDEXED AS #3 KEY = "key"
    PUT #3, R{}
    CLOSE #3

    LBL$ = "APPENDED"
    MSG$ = "INSERT " + STEMP$ + " KEY " + KTEMP$
    GOSUB LogEvent
    RETURN


REM ==============================================================
REM  SELECT * FROM t [WHERE KEY=val | WHERE cond]
REM          [ORDER BY col [ASC|DESC]] [LIMIT n]
REM ==============================================================
DoSelect:
    SQL_RESULT$ = ""
    LIMIT = -1
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
            L$ = SELTMP$
            GOSUB NormList
            SELCOLS$ = NL$
        END IF
    END IF

    TMP$ = TRIM$(MID$(ST$, PF+4))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN
        TBL$ = LCASE$(TRIM$(TMP$))
        REST$ = ""
    ELSE
        TBL$ = LCASE$(TRIM$(LEFT$(TMP$, SP-1)))
        REST$ = TRIM$(MID$(TMP$, SP+1))
    END IF
    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN

    GOSUB GetSchema
    IF COLS$ = "" THEN SQL_STATUS=51: SQL_MSG$="NO SUCH TABLE": RETURN

    IF SELALL = 0 THEN
        SCI = 1
        WHILE 1
            S$ = SELCOLS$: D$ = ",": N = SCI: GOSUB GetToken
            C$ = GETD$
            IF C$ = "" THEN GOTO DSVX
            COL$ = C$: GOSUB ValidateCol
            IF VALID = 0 THEN
                SQL_STATUS=52: SQL_MSG$="BAD SELECT COL"
                RETURN
            END IF
            SCI = SCI + 1
        WEND
DSVX:
    END IF

    W$ = ""
    WHEREKEY = 0
    WKEYVAL$ = ""
    OCOL$ = "": ODIR$ = ""

    PW = INSTR(UCASE$(REST$), "WHERE")
    PO = INSTR(UCASE$(REST$), "ORDER BY")
    PL = INSTR(UCASE$(REST$), "LIMIT")

    IF PW > 0 THEN
        WENDX = LEN(REST$) + 1
        IF PO > 0 AND PO > PW THEN WENDX = PO
        IF PL > 0 AND PL > PW AND PL < WENDX THEN WENDX = PL
        W$ = TRIM$(MID$(REST$, PW+5, WENDX-PW-5))

        WU$ = UCASE$(W$)
        IF LEFT$(WU$, 4) = "KEY=" THEN WHEREKEY = 1
        IF LEFT$(WU$, 5) = "KEY =" THEN WHEREKEY = 1
        IF WHEREKEY = 1 THEN
            IF INSTR(WU$, " AND ") > 0 THEN WHEREKEY = 0
            IF INSTR(WU$, " OR ") > 0 THEN WHEREKEY = 0
        END IF
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
            ODIR$ = UCASE$(TRIM$(MID$(OCLAUSE$, OSP+1)))
            IF ODIR$ <> "DESC" THEN ODIR$ = "ASC"
        END IF
        OCOL$ = LCASE$(OCOL$)
    END IF

    IF PL > 0 THEN
        LIMIT = VAL(TRIM$(MID$(REST$, PL+5)))
        IF LIMIT < 0 THEN LIMIT = 0
    END IF

    IF OCOL$ <> "" THEN
        IF OCOL$ <> "key" THEN
            COL$ = OCOL$: GOSUB ValidateCol
            IF VALID = 0 THEN
                SQL_STATUS=52: SQL_MSG$="BAD ORDER COL"
                RETURN
            END IF
        END IF
    END IF

    IF LIMIT = 0 THEN
        SQL_MSG$ = "OK"
        RETURN
    END IF

    STBL$ = TBL$
    SCOLS$ = COLS$
    SPK$ = PK$

    IF WHEREKEY = 1 THEN
        GOSUB GetTableF
        OPEN TF$ FOR INDEXED AS #3 KEY = "key"
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

    GOSUB GetTableF
    OPEN TF$ FOR INDEXED AS #3 KEY = "key"
    HASSORT = 0
    IF OCOL$ <> "" THEN HASSORT = 1
    DIM RSLT$(500)
    RCNT = 0
    ROWS = 0
    RESET #3

    WHILE NOT EOF(3)
        DIM R{}
        GET #3, R{}, NEXT
        IF NOT FOUND(3) THEN GOTO SNX3

        IF W$ <> "" THEN
            GOSUB EvalWhere
            IF MATCH = 0 THEN GOTO SNX3
        END IF

        IF ISCOUNT = 0 THEN
            GOSUB BuildRowFromRec

            DUP = 0
            IF HASDIST = 1 THEN
                PV$ = FMT$
                GOSUB ProjOf
                PP$ = PRJ$
                FOR DI = 0 TO RCNT - 1
                    PV$ = RSLT$(DI)
                    GOSUB ProjOf
                    IF PRJ$ = PP$ THEN DUP = 1
                NEXT DI
            END IF

            IF DUP = 0 THEN
                IF HASSORT = 1 OR HASDIST = 1 THEN
                    IF RCNT < 500 THEN
                        RSLT$(RCNT) = FMT$
                        RCNT = RCNT + 1
                    ELSE
                        IF LEN(SQL_RESULT$) + LEN(FMT$) < 2000 THEN
                            SQL_RESULT$ = SQL_RESULT$ + FMT$ + CHR$(10)
                        END IF
                    END IF
                ELSE
                    IF LEN(SQL_RESULT$) + LEN(FMT$) < 2000 THEN
                        SQL_RESULT$ = SQL_RESULT$ + FMT$ + CHR$(10)
                    END IF
                END IF
            END IF
        END IF

        ROWS = ROWS + 1
        IF LIMIT > 0 AND ROWS >= LIMIT THEN GOTO DSX
SNX3:
        WC = ROWS: GOSUB Watchdog
    WEND
DSX:
    CLOSE #3

    IF ISCOUNT = 1 THEN
        SQL_RESULT$ = "COUNT=" + TRIM$(STR$(ROWS))
        SQL_MSG$ = "OK"
        RETURN
    END IF

    IF HASSORT = 1 AND RCNT > 1 THEN
        GOSUB SortResultRows
    END IF

    IF HASSORT = 1 OR HASDIST = 1 THEN
        FOR RI = 0 TO RCNT - 1
            IF LEN(SQL_RESULT$) + LEN(RSLT$(RI)) < 2000 THEN
                SQL_RESULT$ = SQL_RESULT$ + RSLT$(RI) + CHR$(10)
            END IF
        NEXT RI
    END IF

    SQL_MSG$ = "OK"
    RETURN

REM  Strip the "R|pkname|pkvalue|" prefix from a result row
REM  IN: PV$  OUT: PRJ$
ProjOf:
    PRJ$ = PV$
    FOR QI = 1 TO 3
        Q1 = INSTR(PRJ$, "|")
        IF Q1 > 0 THEN PRJ$ = MID$(PRJ$, Q1+1)
    NEXT QI
    RETURN

REM===============================================================
REM  Build a result row from the current R{}
REM  IN: R{}, SPK$, SCOLS$, SELALL, SELCOLS$  OUT: FMT$
REM===============================================================
BuildRowFromRec:
    FMT$ = "R|" + SPK$ + "|" + R{"key"}
    IF SELALL = 0 THEN
        COLSET$ = SELCOLS$
    ELSE
        COLSET$ = SCOLS$
    END IF
    CI = 1
    WHILE 1
        S$ = COLSET$: D$ = ",": N = CI: GOSUB GetToken
        C$ = GETD$
        IF C$ = "" THEN GOTO BRX
        FMT$ = FMT$ + "|" + C$ + "=" + R{C$}
        CI = CI + 1
    WEND
BRX:
    RETURN

REM  Sort RSLT$ array by OCOL$ in ODIR$ order
SortResultRows:
    FOR SI = 0 TO RCNT - 2
        FOR SJ = SI + 1 TO RCNT - 1
            NEED$ = "|" + OCOL$ + "="
            VI$ = ""
            VJ$ = ""
            IF OCOL$ = "key" THEN
                SV$ = RSLT$(SI)
                GOSUB SortKeyVal
                VI$ = SVV$
                SV$ = RSLT$(SJ)
                GOSUB SortKeyVal
                VJ$ = SVV$
            ELSE
                PX = INSTR(RSLT$(SI), NEED$)
                PJ = INSTR(RSLT$(SJ), NEED$)
                IF PX > 0 THEN
                    VI$ = MID$(RSLT$(SI), PX + LEN(NEED$))
                    NXI = INSTR(VI$, "|")
                    IF NXI > 0 THEN VI$ = LEFT$(VI$, NXI-1)
                END IF
                IF PJ > 0 THEN
                    VJ$ = MID$(RSLT$(SJ), PJ + LEN(NEED$))
                    NXJ = INSTR(VJ$, "|")
                    IF NXJ > 0 THEN VJ$ = LEFT$(VJ$, NXJ-1)
                END IF
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
        WC = SI: GOSUB Watchdog
    NEXT SI
    RETURN

SortKeyVal:
    REM IN: SV$  OUT: SVV$ (second pipe field = pk value)
    SVV$ = ""
    Q1 = INSTR(SV$, "|")
    IF Q1 > 0 THEN
        QQ$ = MID$(SV$, Q1+1)
        Q2 = INSTR(QQ$, "|")
        IF Q2 > 0 THEN
            RR$ = MID$(QQ$, Q2+1)
            Q3 = INSTR(RR$, "|")
            IF Q3 > 0 THEN SVV$ = LEFT$(RR$, Q3-1)
        END IF
    END IF
    RETURN


REM ==============================================================
REM  Watchdog - yield CPU every 50 iterations
REM  IN: WC (counter)  sleeps when WC MOD 50 = 0
REM ==============================================================
Watchdog:
    IF (WC MOD 50) = 0 THEN X = SLEEP(0.25)
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
        MATCH = 0
        IF ORI = 0 THEN GOTO EWX
        WP = WP + ORI + 3
    WEND
EWX:
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
        CCOL$ = LCASE$(TRIM$(LEFT$(CON$, LI - 1)))
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
    CCOL$ = LCASE$(TRIM$(LEFT$(CON$, OI - 1)))
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
        S$ = COLS$: D$ = ",": N = CI: GOSUB GetToken
        C$ = GETD$
        IF C$ = "" THEN GOTO VCX
        IF UCASE$(C$) = UCASE$(COL$) THEN VALID = 1: RETURN
        CI = CI + 1
    WEND
VCX:
    RETURN

CheckSet:
    REM IN: SET$, COLS$  OUT: SETBAD (0/1)
    SETBAD = 0
    SCI = 1
    WHILE 1
        S$ = SET$: D$ = ",": N = SCI: GOSUB GetToken
        ASGN$ = GETD$
        IF ASGN$ = "" THEN GOTO CSX
        EQ = INSTR(ASGN$, "=")
        IF EQ = 0 THEN
            SETBAD = 1
        ELSE
            COL$ = LCASE$(TRIM$(LEFT$(ASGN$, EQ-1)))
            GOSUB ValidateCol
            IF VALID = 0 THEN SETBAD = 1
        END IF
        SCI = SCI + 1
    WEND
CSX:
    RETURN

DoUpdate:
    TMP$ = TRIM$(MID$(ST$, 7))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=60: SQL_MSG$="BAD UPDATE": RETURN
    TBL$ = LCASE$(TRIM$(LEFT$(TMP$, SP-1)))
    REST$ = TRIM$(MID$(TMP$, SP+1))
    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=61: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF

    RU$ = UCASE$(REST$)

    IF LEFT$(RU$, 4) = "KEY " THEN
        KSP = INSTR(RU$, " SET ")
        IF KSP = 0 THEN
            SQL_STATUS=64: SQL_MSG$="UPDATE REQUIRES SET"
            RETURN
        END IF
        KVAL$ = TRIM$(MID$(REST$, 4, KSP-4))
        IF KVAL$ = "" THEN
            SQL_STATUS=62: SQL_MSG$="BAD KEY"
            RETURN
        END IF
        SET$ = TRIM$(MID$(REST$, KSP+5))
        GOSUB CheckSet
        IF SETBAD = 1 THEN SQL_STATUS=65: SQL_MSG$="BAD SET": RETURN

        GOSUB GetTableF
        OPEN TF$ FOR INDEXED AS #3 KEY = "key"
        DIM R{}
        GET #3, R{}, KEY = KVAL$
        IF NOT FOUND(3) THEN
            CLOSE #3: SQL_STATUS=66: SQL_MSG$="KEY NOT FOUND"
            RETURN
        END IF

        SETLOG$ = ""
        SCI = 1
        WHILE 1
            S$ = SET$: D$ = ",": N = SCI: GOSUB GetToken
            ASGN$ = GETD$
            IF ASGN$ = "" THEN GOTO UKX
            EQ = INSTR(ASGN$, "=")
            UCOL$ = LCASE$(TRIM$(LEFT$(ASGN$, EQ-1)))
            UVAL$ = TRIM$(MID$(ASGN$, EQ+1))
            IF SETLOG$ <> "" THEN SETLOG$ = SETLOG$ + ","
            SETLOG$ = SETLOG$ + UCOL$ + "=" + UVAL$
            R{UCOL$} = UVAL$
            SCI = SCI + 1
        WEND
UKX:

        PUT #3, R{}
        CLOSE #3
        LBL$ = "UPDATED"
        MSG$ = "UPDATE " + TBL$ + " KEY " + KVAL$ + " "
        MSG$ = MSG$ + SETLOG$
        GOSUB LogEvent
        SQL_MSG$ = "UPDATED " + TBL$ + " KEY " + KVAL$
        RETURN

    ELSEIF LEFT$(RU$, 4) = "SET " THEN
        SETALL$ = TRIM$(MID$(REST$, 5))
        UWP = INSTR(UCASE$(SETALL$), " WHERE ")
        IF UWP = 0 THEN
            SQL_STATUS=62: SQL_MSG$="UPDATE NEEDS WHERE"
            RETURN
        END IF
        SET$ = TRIM$(LEFT$(SETALL$, UWP-1))
        W$ = TRIM$(MID$(SETALL$, UWP+6))
        GOSUB CheckSet
        IF SETBAD = 1 THEN SQL_STATUS=65: SQL_MSG$="BAD SET": RETURN

        GOSUB GetTableF
        OPEN TF$ FOR INDEXED AS #3 KEY = "key"
        RESET #3
        UPDCNT = 0
        WHILE NOT EOF(3)
            DIM R{}
            GET #3, R{}, NEXT
            IF NOT FOUND(3) THEN GOTO UPBX
            GOSUB EvalWhere
            IF MATCH = 1 THEN
                SCI = 1
                MORESET = 1
                WHILE MORESET = 1
                    S$ = SET$: D$ = ",": N = SCI
                    GOSUB GetToken
                    ASGN$ = GETD$
                    IF ASGN$ = "" THEN
                        MORESET = 0
                    ELSE
                        EQ = INSTR(ASGN$, "=")
                        IF EQ > 0 THEN
                            UCOL$ = LCASE$(TRIM$(LEFT$(ASGN$, EQ-1)))
                            UVAL$ = TRIM$(MID$(ASGN$, EQ+1))
                            R{UCOL$} = UVAL$
                        END IF
                        SCI = SCI + 1
                    END IF
                WEND
                PUT #3, R{}
                UPDCNT = UPDCNT + 1
            END IF
UPBX:
            WC = UPDCNT: GOSUB Watchdog
        WEND
        CLOSE #3
        LBL$ = "UPDATED"
        MSG$ = "BULK UPDATE " + TBL$ + " "
        MSG$ = MSG$ + TRIM$(STR$(UPDCNT)) + " rows"
        GOSUB LogEvent
        SQL_MSG$ = "UPDATED " + TRIM$(STR$(UPDCNT))
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
    TBL$ = LCASE$(TRIM$(LEFT$(TMP$, SP-1)))
    REST$ = TRIM$(MID$(TMP$, SP+1))
    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=71: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF

    RU$ = UCASE$(REST$)
    IF LEFT$(RU$, 4) <> "KEY " THEN
        SQL_STATUS=72: SQL_MSG$="REPLACE REQUIRES KEY"
        RETURN
    END IF
    VPOS = INSTR(RU$, " VALUES ")
    IF VPOS = 0 THEN
        SQL_STATUS=73: SQL_MSG$="REPLACE REQUIRES VALUES"
        RETURN
    END IF
    KVAL$ = TRIM$(MID$(REST$, 4, VPOS-4))
    IF KVAL$ = "" THEN
        SQL_STATUS=72: SQL_MSG$="REPLACE REQUIRES KEY"
        RETURN
    END IF
    VSTR$ = TRIM$(MID$(REST$, VPOS+8))
    OP = INSTR(VSTR$, "("): CP = INSTR(VSTR$, ")")
    IF OP=0 OR CP=0 OR CP<OP THEN
        SQL_STATUS=75: SQL_MSG$="BAD VALUES"
        RETURN
    END IF
    VALS$ = TRIM$(MID$(VSTR$, OP+1, CP-OP-1))

    DIM R{}
    R{"key"} = KVAL$
    CI = 1
    WHILE 1
        S$ = COLS$: D$ = ",": N = CI: GOSUB GetToken
        COL$ = GETD$
        IF COL$ = "" THEN GOTO RPX
        S$ = VALS$: D$ = ",": N = CI: GOSUB GetToken
        VV$ = GETD$
        R{COL$} = VV$
        CI = CI + 1
    WEND
RPX:

    GOSUB GetTableF
    OPEN TF$ FOR INDEXED AS #3 KEY = "key"
    PUT #3, R{}
    CLOSE #3
    LBL$ = "UPDATED"
    MSG$ = "REPLACE " + TBL$ + " KEY " + KVAL$
    GOSUB LogEvent
    SQL_MSG$ = "REPLACED " + TBL$ + " KEY " + KVAL$
    RETURN


REM ==============================================================
REM  DELETE FROM t KEY k  |  DELETE FROM t WHERE cond
REM ==============================================================
DoDelete:
    PF = INSTR(UP$, "FROM")
    IF PF = 0 THEN SQL_STATUS=80: SQL_MSG$="BAD DELETE": RETURN
    TMP$ = TRIM$(MID$(ST$, PF+4))
    SP = INSTR(TMP$, " ")
    IF SP = 0 THEN SQL_STATUS=81: SQL_MSG$="BAD DELETE": RETURN
    TBL$ = LCASE$(TRIM$(LEFT$(TMP$, SP-1)))
    REST$ = TRIM$(MID$(TMP$, SP+1))
    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=61: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF

    RU$ = UCASE$(REST$)

    IF LEFT$(RU$, 4) = "KEY " THEN
        KVAL$ = TRIM$(MID$(REST$, 4))
        IF KVAL$ = "" THEN
            SQL_STATUS=82: SQL_MSG$="DELETE REQUIRES KEY/WHERE"
            RETURN
        END IF
        GOSUB GetTableF
        OPEN TF$ FOR INDEXED AS #3 KEY = "key"
        DELETE #3, KEY = KVAL$
        CLOSE #3
        LBL$ = "DELETED"
        MSG$ = "DELETE " + TBL$ + " KEY " + KVAL$
        GOSUB LogEvent
        SQL_MSG$ = "DELETED " + TBL$ + " KEY " + KVAL$
        RETURN

    ELSEIF LEFT$(RU$, 6) = "WHERE " THEN
        W$ = TRIM$(MID$(REST$, 7))

        GOSUB GetTableF
        OPEN TF$ FOR INDEXED AS #3 KEY = "key"
        RESET #3
        DELCNT = 0
        WHILE NOT EOF(3)
            DIM R{}
            GET #3, R{}, NEXT
            IF NOT FOUND(3) THEN GOTO DLNX
            GOSUB EvalWhere
            IF MATCH = 1 THEN
                DELETE #3, KEY = R{"key"}
                DELCNT = DELCNT + 1
            END IF
DLNX:
            WC = DELCNT: GOSUB Watchdog
        WEND
        CLOSE #3
        LBL$ = "DELETED"
        MSG$ = "BULK DELETE " + TBL$ + " "
        MSG$ = MSG$ + TRIM$(STR$(DELCNT)) + " rows"
        GOSUB LogEvent
        SQL_MSG$ = "DELETED " + TRIM$(STR$(DELCNT))
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
    IF LEFT$(UCASE$(TMP$), 5) = "TABLE" THEN
        TMP$ = TRIM$(MID$(TMP$, 6))
    END IF
    IF TMP$ = "" THEN SQL_STATUS=85: SQL_MSG$="BAD DROP": RETURN
    TBL$ = LCASE$(TRIM$(TMP$))
    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=86: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF

    GOSUB GetTableF
    OPEN TF$ FOR OUTPUT AS #3
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
    OPEN SYSF$ FOR INDEXED AS #2 KEY = "name"
    RESET #2
    WHILE NOT EOF(2)
        DIM S{}
        GET #2, S{}, NEXT
        IF FOUND(2) THEN
            IF S{"name"} <> "_schema_meta" THEN
                IF LEN(SQL_RESULT$) + LEN(S{"name"}) < 2000 THEN
                    SQL_RESULT$ = SQL_RESULT$ + S{"name"} + CHR$(10)
                END IF
            END IF
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
    TBL$ = LCASE$(TRIM$(TMP$))
    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN
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
    TBL$ = LCASE$(TRIM$(LEFT$(TMP$, SP-1)))
    REST$ = TRIM$(MID$(TMP$, SP+1))
    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN

    GOSUB GetSchema
    IF COLS$ = "" THEN
        SQL_STATUS=51: SQL_MSG$="NO SUCH TABLE"
        RETURN
    END IF

    AU$ = UCASE$(REST$)
    IF LEFT$(AU$, 4) = "ADD " THEN
        NEWCOL$ = LCASE$(TRIM$(MID$(REST$, 5)))
        IF NEWCOL$="" THEN GOSUB BadAlter: RETURN
        C$ = NEWCOL$
        GOSUB CheckCol
        IF BADCOL = 1 THEN
            SQL_STATUS=87: SQL_MSG$="BAD COLUMN NAME"
            RETURN
        END IF
        COL$ = NEWCOL$: GOSUB ValidateCol
        IF VALID = 1 THEN
            SQL_STATUS=87: SQL_MSG$="COLUMN EXISTS"
            RETURN
        END IF
        COLS$ = COLS$ + "," + NEWCOL$
        NEWSEQ = SEQ
        GOSUB PutSchema
        SQL_MSG$ = "ALTER ADD " + NEWCOL$ + " TO " + TBL$
        RETURN
    ELSEIF LEFT$(AU$, 5) = "DROP " THEN
        DCOL$ = LCASE$(TRIM$(MID$(REST$, 6)))
        IF DCOL$ = "" THEN SQL_STATUS=87: SQL_MSG$="BAD ALTER": RETURN
        IF DCOL$ = LCASE$(PK$) THEN
            SQL_STATUS=87: SQL_MSG$="CANNOT DROP PK"
            RETURN
        END IF
        COL$ = DCOL$: GOSUB ValidateCol
        IF VALID = 0 THEN
            SQL_STATUS=87: SQL_MSG$="NO SUCH COLUMN"
            RETURN
        END IF
        NEWCOLS$ = ""
        CI = 1
        WHILE 1
            S$ = COLS$: D$ = ",": N = CI: GOSUB GetToken
            C$ = GETD$
            IF C$ = "" THEN GOTO ADX
            IF UCASE$(C$) <> UCASE$(DCOL$) THEN
                IF NEWCOLS$ <> "" THEN NEWCOLS$ = NEWCOLS$ + ","
                NEWCOLS$ = NEWCOLS$ + C$
            END IF
            CI = CI + 1
        WEND
ADX:
        COLS$ = NEWCOLS$
        NEWSEQ = SEQ
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

    S$ = SQL_STMT$: D$ = "|": N = 1: GOSUB GetToken
    TBL$ = LCASE$(GETD$)
    S$ = SQL_STMT$: D$ = "|": N = 2: GOSUB GetToken
    TERM$ = GETD$
    S$ = SQL_STMT$: D$ = "|": N = 3: GOSUB GetToken
    COLF$ = LCASE$(GETD$)
    S$ = SQL_STMT$: D$ = "|": N = 4: GOSUB GetToken
    SMODE$ = UCASE$(GETD$)

    IF TBL$ = "" OR TERM$ = "" THEN
        SQL_STATUS=90: SQL_MSG$="SEARCH NEEDS table|term"
        RETURN
    END IF
    IF SMODE$ = "" THEN SMODE$ = "CONTAINS"

    GOSUB CheckTbl
    IF BADNAME = 1 THEN GOSUB BadName: RETURN

    GOSUB GetSchema
    IF COLS$ = "" THEN SQL_STATUS=91: SQL_MSG$="NO SUCH TABLE": RETURN

    IF COLF$ <> "" THEN
        COL$ = COLF$: GOSUB ValidateCol
        IF VALID = 0 THEN
            SQL_STATUS=92: SQL_MSG$="BAD SEARCH COL"
            RETURN
        END IF
    END IF

    STBL$ = TBL$
    SCOLS$ = COLS$
    SPK$ = PK$
    STERM$ = UCASE$(TERM$)

    GOSUB GetTableF
    OPEN TF$ FOR INDEXED AS #3 KEY = "key"
    RESET #3
    RC = 0
    WHILE NOT EOF(3)
        DIM R{}
        GET #3, R{}, NEXT
        IF NOT FOUND(3) THEN GOTO SCNX3
        IF COLF$ = "" THEN
            HIT$ = "0"
            CI = 1
            MORECOL = 1
            WHILE MORECOL = 1
                S$ = SCOLS$: D$ = ",": N = CI: GOSUB GetToken
                C$ = GETD$
                IF C$ = "" THEN
                    MORECOL = 0
                ELSE
                    GOSUB MatchField
                    IF MATCH = 1 THEN HIT$ = "1"
                    CI = CI + 1
                END IF
            WEND
            IF HIT$ = "1" THEN GOSUB BuildResultRow
        ELSE
            C$ = COLF$
            GOSUB MatchField
            IF MATCH = 1 THEN GOSUB BuildResultRow
        END IF
SCNX3:
        WC = RC: GOSUB Watchdog
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
    FMT$ = "R|" + SPK$ + "|" + R{"key"}
    CI = 1
    WHILE 1
        S$ = SCOLS$: D$ = ",": N = CI: GOSUB GetToken
        C$ = GETD$
        IF C$ = "" THEN GOTO BRRX
        FMT$ = FMT$ + "|" + C$ + "=" + R{C$}
        CI = CI + 1
    WEND
BRRX:
    IF LEN(SQL_RESULT$) + LEN(FMT$) < 2000 THEN
        SQL_RESULT$ = SQL_RESULT$ + FMT$ + CHR$(10)
    END IF
    RC = RC + 1
    RETURN


REM ==============================================================
REM  TRANSACTIONS using batch.dat
REM ==============================================================
TxnBegin:
    OPEN BATF$ FOR OUTPUT AS #4
    PRINT #4, "BEGIN"
    CLOSE #4
    LBL$ = "OPEN": MSG$ = "Transaction started": GOSUB LogEvent
    SQL_MSG$ = "TXN BEGIN"
    RETURN

TxnRollback:
    OPEN BATF$ FOR OUTPUT AS #4
    CLOSE #4
    LBL$ = "CLOSED": MSG$ = "Transaction rolled back": GOSUB LogEvent
    SQL_MSG$ = "TXN ROLLBACK"
    RETURN

TxnCommit:
    OPEN BATF$ FOR APPEND AS #4
    CLOSE #4
    OPEN BATF$ FOR INPUT AS #4
    IF EOF(4) THEN CLOSE #4: SQL_MSG$="NO TXN": RETURN
    INPUT #4, L$
    L$ = TRIM$(L$)
    IF L$ <> "BEGIN" THEN CLOSE #4: SQL_MSG$="NO TXN": RETURN

    DIM BQ$(500)
    N = 0
    WHILE NOT EOF(4)
        INPUT #4, L$
        L$ = TRIM$(L$)
        IF L$ <> "" THEN
            IF N < 500 THEN
                N = N + 1
                BQ$(N) = L$
            END IF
        END IF
    WEND
    CLOSE #4

    REM Clear the queue BEFORE executing so EXEC does not re-queue
    OPEN BATF$ FOR OUTPUT AS #4
    CLOSE #4

    OLD$ = SQL_STMT$
    OLDM$ = SQL_MODE$
    SQL_MODE$ = "RW"

    MAXB = VAL(OPT{"301"})
    IF MAXB > 0 AND N > MAXB THEN
        SQL_STMT$ = OLD$
        SQL_MODE$ = OLDM$
        SQL_STATUS = 93
        SQL_MSG$ = "TXN TOO LARGE"
        LBL$ = "ERROR"
        MSG$ = "Transaction exceeds batch limit"
        GOSUB LogEvent
        RETURN
    END IF

    REM ExecSQL clobbers N (token index), so keep the count in NQ
    NQ = N
    FOR BI = 1 TO NQ
        SQL_STMT$ = BQ$(BI)
        GOSUB ExecSQL
        IF SQL_STATUS <> 0 THEN
            TMPMSG$ = SQL_MSG$
            SQL_STMT$ = OLD$
            SQL_MODE$ = OLDM$
            SQL_MSG$ = "TXN ABORTED AT STMT "
            SQL_MSG$ = SQL_MSG$ + TRIM$(STR$(BI)) + ": " + TMPMSG$
            LBL$ = "ERROR"
            MSG$ = "Transaction aborted at stmt " + TRIM$(STR$(BI))
            GOSUB LogEvent
            RETURN
        END IF
        WC = BI: GOSUB Watchdog
    NEXT BI

    SQL_STMT$ = OLD$
    SQL_MODE$ = OLDM$
    LBL$ = "CLOSED"
    MSG$ = "Transaction committed (" + TRIM$(STR$(NQ)) + " stmts)"
    GOSUB LogEvent
    SQL_MSG$ = "TXN COMMIT (" + TRIM$(STR$(NQ)) + " stmts)"
    RETURN


REM ==============================================================
REM  Token helper (uses S$, D$, N as input, returns GETD$)
REM ==============================================================
GetToken:
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

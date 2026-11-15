REM ==============================================================
REM  DBWORK.BAS  -  MiniSQL Workbench
REM  Screen-based database designer / viewer / editor.
REM  Chains into minisql.bas for every database operation.
REM ==============================================================
START:
    COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
    COMMON SQL_STATUS, SQL_MSG$
    DIM REG$(10)
    DIM TBN$(50)
    DIM TBC$(50)
    DIM COLN$(40)
    DIM RESL$(60)
    DIM NEWC$(40)
    GOSUB WB_BOOT
    SCREEN = 1
    WHILE SCREEN <> 0
        IF SCREEN = 1 THEN GOSUB SCR_START
        IF SCREEN = 2 THEN GOSUB SCR_TABLES
        IF SCREEN = 3 THEN GOSUB SCR_DESIGN
    WEND
    END


REM ==============================================================
REM  Boot: defaults, horizontal rule, batch reset, registry
REM ==============================================================
WB_BOOT:
    SQL_MODE$ = "RW"
    WB_HL$ = ""
    FOR I = 1 TO 77
        WB_HL$ = WB_HL$ + BOXCHAR$(5)
    NEXT I
    GOSUB WB_CLRBATCH
    GOSUB WB_READREG
    RETURN

WB_CLRBATCH:
    OPEN "batch.dat" FOR OUTPUT AS #5
    CLOSE #5
    RETURN


REM ==============================================================
REM  Recent-database registry (dbwork.dat, one name per line)
REM ==============================================================
WB_READREG:
    REGN = 0
    OPEN "dbwork.dat" FOR APPEND AS #5
    CLOSE #5
    OPEN "dbwork.dat" FOR INPUT AS #5
    WHILE NOT EOF(5)
        INPUT #5, L$
        L$ = TRIM$(L$)
        IF L$ <> "" THEN
            DUP = 0
            FOR I = 1 TO REGN
                IF REG$(I) = L$ THEN DUP = 1
            NEXT I
            IF DUP = 0 AND REGN < 10 THEN
                REGN = REGN + 1
                REG$(REGN) = L$
            END IF
        END IF
    WEND
    CLOSE #5
    RETURN

WB_WRITEREG:
    OPEN "dbwork.dat" FOR OUTPUT AS #5
    FOR I = 1 TO REGN
        PRINT #5, REG$(I)
    NEXT I
    CLOSE #5
    RETURN

WB_ADDREG:
    FPOS = 0
    FOR I = 1 TO REGN
        IF REG$(I) = DB$ THEN FPOS = I
    NEXT I
    IF FPOS > 0 THEN
        FOR I = FPOS TO 2 STEP -1
            REG$(I) = REG$(I-1)
        NEXT I
    ELSE
        IF REGN < 10 THEN REGN = REGN + 1
        FOR I = REGN TO 2 STEP -1
            REG$(I) = REG$(I-1)
        NEXT I
    END IF
    REG$(1) = DB$
    RETURN


REM ==============================================================
REM  Database name validation and encoding
REM  '-' -> '_', '_' -> '__'; longest file is <db>_zzlinks.idx
REM  so the encoded prefix must be <= 20 characters.
REM ==============================================================
WB_VALDB:
    DBBAD = 0
    ERR$ = ""
    IF DB$ = "" THEN
        DBBAD = 1
        ERR$ = "DATABASE NAME REQUIRED"
        RETURN
    END IF
    ENC$ = ""
    FOR I = 1 TO LEN(DB$)
        C$ = MID$(DB$, I, 1)
        OKC = 0
        IF C$ >= "0" AND C$ <= "9" THEN OKC = 1
        IF UCASE$(C$) >= "A" AND UCASE$(C$) <= "Z" THEN OKC = 1
        IF C$ = "-" THEN OKC = 1
        IF C$ = "_" THEN OKC = 1
        IF OKC = 0 THEN
            DBBAD = 1
            ERR$ = "BAD DATABASE NAME"
            RETURN
        END IF
        IF C$ = "_" THEN
            ENC$ = ENC$ + "__"
        ELSEIF C$ = "-" THEN
            ENC$ = ENC$ + "_"
        ELSE
            ENC$ = ENC$ + C$
        END IF
    NEXT I
    IF LEN(ENC$) > 20 THEN
        DBBAD = 1
        ERR$ = "DATABASE NAME TOO LONG"
    END IF
    RETURN


REM ==============================================================
REM  Engine wrappers
REM ==============================================================
WB_CHAIN:
    CHAIN "minisql.bas"
    RETURN

WB_INIT:
    SQL_CMD$ = "INITDB"
    GOSUB WB_CHAIN
    RETURN

WB_EXEC:
    SQL_CMD$ = "EXEC"
    GOSUB WB_CHAIN
    RETURN

WB_ROLLBACK:
    SQL_CMD$ = "ROLLBACK"
    GOSUB WB_CHAIN
    RETURN

WB_CHECK:
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
    END IF
    RETURN


REM ==============================================================
REM  Parsers
REM ==============================================================
WB_GETTOK:
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

WB_SPLIT:
    RESN = 0
    POS = 1
    WHILE POS <= LEN(SQL_RESULT$)
        Q = INSTR(MID$(SQL_RESULT$, POS), CHR$(10))
        IF Q = 0 THEN
            L$ = MID$(SQL_RESULT$, POS)
            POS = LEN(SQL_RESULT$) + 1
        ELSE
            L$ = MID$(SQL_RESULT$, POS, Q-1)
            POS = POS + Q
        END IF
        IF L$ <> "" AND RESN < 60 THEN
            RESN = RESN + 1
            RESL$(RESN) = L$
        END IF
    WEND
    RETURN

WB_PARSEDESC:
    DTBL$ = ""
    DCOLS$ = ""
    DPK$ = ""
    POS = 1
    FOR I = 1 TO 3
        Q = INSTR(MID$(SQL_RESULT$, POS), CHR$(10))
        IF Q = 0 THEN
            L$ = MID$(SQL_RESULT$, POS)
            POS = LEN(SQL_RESULT$) + 1
        ELSE
            L$ = MID$(SQL_RESULT$, POS, Q-1)
            POS = POS + Q
        END IF
        IF LEFT$(L$, 4) = "TBL=" THEN DTBL$ = MID$(L$, 5)
        IF LEFT$(L$, 5) = "COLS=" THEN DCOLS$ = MID$(L$, 6)
        IF LEFT$(L$, 3) = "PK=" THEN DPK$ = MID$(L$, 4)
    NEXT I
    RETURN

WB_PARSECOUNT:
    CNT = VAL(MID$(SQL_RESULT$, 7))
    RETURN


REM ==============================================================
REM  Table/column name validation
REM  Letters, digits, '-' and '_'; no reserved words or LIMIT.
REM ==============================================================
WB_VALNAME:
    VBAD = 0
    IF V$ = "" THEN
        VBAD = 1
        RETURN
    END IF
    FOR VI = 1 TO LEN(V$)
        VC$ = MID$(V$, VI, 1)
        VOK = 0
        IF VC$ >= "0" AND VC$ <= "9" THEN VOK = 1
        IF UCASE$(VC$) >= "A" AND UCASE$(VC$) <= "Z" THEN VOK = 1
        IF VC$ = "-" OR VC$ = "_" THEN VOK = 1
        IF VOK = 0 THEN
            VBAD = 1
            RETURN
        END IF
    NEXT VI
    VU$ = UCASE$(V$)
    IF INSTR(VU$, "LIMIT") > 0 THEN VBAD = 1: RETURN
    IF VU$ = "KEY" THEN VBAD = 1
    IF VU$ = "ZZLINKS" THEN VBAD = 1
    IF VU$ = "_SCHEMA_META" THEN VBAD = 1
    IF VU$ = "INTO" THEN VBAD = 1
    IF VU$ = "VALUES" THEN VBAD = 1
    IF VU$ = "FROM" THEN VBAD = 1
    IF VU$ = "WHERE" THEN VBAD = 1
    IF VU$ = "SET" THEN VBAD = 1
    IF VU$ = "TABLE" THEN VBAD = 1
    IF VU$ = "ORDER" THEN VBAD = 1
    IF VU$ = "LIKE" THEN VBAD = 1
    IF VU$ = "AND" THEN VBAD = 1
    IF VU$ = "OR" THEN VBAD = 1
    IF VU$ = "DROP" THEN VBAD = 1
    IF VU$ = "SHOW" THEN VBAD = 1
    IF VU$ = "DESCRIBE" THEN VBAD = 1
    IF VU$ = "ALTER" THEN VBAD = 1
    IF VU$ = "PK" THEN VBAD = 1
    RETURN


REM ==============================================================
REM  Load the table list and one table's columns
REM ==============================================================
WB_LOADTABLES:
    TBNT = 0
    SQL_STMT$ = "SHOW TABLES"
    GOSUB WB_EXEC
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    GOSUB WB_SPLIT
    FOR TI = 1 TO RESN
        L$ = RESL$(TI)
        IF UCASE$(L$) <> "ZZLINKS" AND TBNT < 50 THEN
            TBNT = TBNT + 1
            TBN$(TBNT) = L$
            SQL_STMT$ = "DESCRIBE " + L$
            GOSUB WB_EXEC
            IF SQL_STATUS = 0 THEN
                GOSUB WB_PARSEDESC
                TBC$(TBNT) = DCOLS$
            ELSE
                TBC$(TBNT) = ""
            END IF
        END IF
    NEXT TI
    RETURN

WB_LOADCOLS:
    COLNT = 0
    CI = 1
    WHILE 1
        S$ = TCOLS$
        D$ = ","
        N = CI
        GOSUB WB_GETTOK
        C$ = GETD$
        IF C$ = "" THEN RETURN
        IF COLNT < 40 THEN
            COLNT = COLNT + 1
            COLN$(COLNT) = C$
        END IF
        CI = CI + 1
    WEND
    RETURN


REM ==============================================================
REM  Open/create a database, ensure zzlinks, remember it
REM ==============================================================
WB_OPENDB:
    SQL_DB$ = DB$
    SQL_MODE$ = "RW"
    GOSUB WB_INIT
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    SQL_STMT$ = "CREATE TABLE zzlinks (ftbl,fcol,ttbl,tcol) PK KEY"
    GOSUB WB_EXEC
    IF SQL_STATUS <> 0 AND SQL_STATUS <> 33 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    GOSUB WB_ADDREG
    GOSUB WB_WRITEREG
    TBL$ = ""
    TCOLS$ = ""
    TPK$ = "key"
    SCREEN = 2
    RETURN


REM ==============================================================
REM  Screen kit (single-line box, 79 columns, no TAB after box)
REM ==============================================================
WB_CLS:
    CLS
    RETURN

WB_TOP:
    PRINT BOXCHAR$(1) + WB_HL$ + BOXCHAR$(2)
    RETURN

WB_SEP:
    PRINT CP310$(13) + WB_HL$ + CP310$(14)
    RETURN

WB_BOT:
    PRINT BOXCHAR$(3) + WB_HL$ + BOXCHAR$(4)
    RETURN

WB_PAD:
    T2$ = LEFT$(TEXT$, 77)
    T2$ = T2$ + SPACE$(77 - LEN(T2$))
    RETURN

WB_LINE:
    GOSUB WB_PAD
    PRINT BOXCHAR$(6) + T2$ + BOXCHAR$(6)
    RETURN

WB_HEADER:
    PRINT BOXCHAR$(1) + WB_HL$ + BOXCHAR$(2) COLOR GREEN
    TEXT$ = "  " + TITLE$
    GOSUB WB_PAD
    PRINT BOXCHAR$(6) + T2$ + BOXCHAR$(6) COLOR GREEN
    GOSUB WB_SEP
    RETURN

WB_FOOTER:
    GOSUB WB_SEP
    TEXT$ = "  " + FOOT$
    GOSUB WB_PAD
    PRINT BOXCHAR$(6) + T2$ + BOXCHAR$(6)
    GOSUB WB_BOT
    RETURN

WB_PROMPT:
    PRINT PROMPT$;
    INPUT "", ANS$
    RETURN

WB_ERR:
    PRINT ERR$ COLOR RED
    INPUT "Press ENTER...", X$
    RETURN

WB_PAUSE:
    INPUT "Press ENTER...", X$
    RETURN

WB_YES:
    PRINT PROMPT$; " (Y/N)";
    INPUT "", ANS$
    YESNO = 0
    IF UCASE$(ANS$) = "Y" THEN YESNO = 1
    RETURN


REM ==============================================================
REM  Start screen
REM ==============================================================
SCR_START:
    GOSUB WB_CLS
    TITLE$ = "MiniSQL Workbench"
    FOOT$ = "N = new database   S = sample SHOP database   Q = quit"
    GOSUB WB_HEADER
    TEXT$ = ""
    GOSUB WB_LINE
    TEXT$ = "  Recent databases:"
    GOSUB WB_LINE
    IF REGN = 0 THEN
        TEXT$ = "    (none)"
        GOSUB WB_LINE
    ELSE
        FOR I = 1 TO REGN
            TEXT$ = "    " + TRIM$(STR$(I)) + ". " + REG$(I)
            GOSUB WB_LINE
        NEXT I
    END IF
    TEXT$ = ""
    GOSUB WB_LINE
    TEXT$ = "  Design and edit MiniSQL databases."
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_FOOTER
    PROMPT$ = "Selection: "
    GOSUB WB_PROMPT
    IF UCASE$(ANS$) = "Q" THEN
        SCREEN = 0
        RETURN
    END IF
    IF UCASE$(ANS$) = "N" THEN
        PROMPT$ = "Database name: "
        GOSUB WB_PROMPT
        DB$ = UCASE$(TRIM$(ANS$))
        GOSUB WB_VALDB
        IF DBBAD = 1 THEN
            GOSUB WB_ERR
            RETURN
        END IF
        GOSUB WB_OPENDB
        RETURN
    END IF
    IF UCASE$(ANS$) = "S" THEN
        ERR$ = "SAMPLE SEED IS NOT IMPLEMENTED YET"
        GOSUB WB_ERR
        RETURN
    END IF
    IF VAL(ANS$) >= 1 AND VAL(ANS$) <= REGN THEN
        DB$ = REG$(VAL(ANS$))
        GOSUB WB_VALDB
        IF DBBAD = 1 THEN
            GOSUB WB_ERR
            RETURN
        END IF
        GOSUB WB_OPENDB
        RETURN
    END IF
    ERR$ = "UNKNOWN SELECTION"
    GOSUB WB_ERR
    RETURN


REM ==============================================================
REM  Table list
REM ==============================================================
SCR_TABLES:
    GOSUB WB_CLS
    TITLE$ = "MiniSQL Workbench"
    FOOT$ = "N=new table   M=map   S=SQL   R=refresh   Q=quit"
    GOSUB WB_HEADER
    TEXT$ = "  DB: " + DB$
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_LOADTABLES
    IF TBNT = 0 THEN
        TEXT$ = "  No tables yet."
        GOSUB WB_LINE
    ELSE
        FOR TI = 1 TO TBNT
            TEXT$ = "  " + TRIM$(STR$(TI)) + "  " + TBN$(TI)
            GOSUB WB_LINE
            TEXT$ = "       " + TBC$(TI)
            GOSUB WB_LINE
        NEXT TI
    END IF
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_FOOTER
    PROMPT$ = "Selection: "
    GOSUB WB_PROMPT
    IF UCASE$(ANS$) = "Q" THEN
        SCREEN = 0
        RETURN
    END IF
    IF UCASE$(ANS$) = "N" THEN
        GOSUB SCR_NEWTABLE
        RETURN
    END IF
    IF UCASE$(ANS$) = "R" THEN
        RETURN
    END IF
    IF UCASE$(ANS$) = "M" THEN
        ERR$ = "MAP IS NOT IMPLEMENTED YET"
        GOSUB WB_ERR
        RETURN
    END IF
    IF UCASE$(ANS$) = "S" THEN
        ERR$ = "SQL CONSOLE IS NOT IMPLEMENTED YET"
        GOSUB WB_ERR
        RETURN
    END IF
    IF VAL(ANS$) >= 1 AND VAL(ANS$) <= TBNT THEN
        TBL$ = TBN$(VAL(ANS$))
        TCOLS$ = TBC$(VAL(ANS$))
        SCREEN = 3
        RETURN
    END IF
    ERR$ = "UNKNOWN SELECTION"
    GOSUB WB_ERR
    RETURN


REM ==============================================================
REM  New table
REM ==============================================================
SCR_NEWTABLE:
    PROMPT$ = "Table name: "
    GOSUB WB_PROMPT
    TBL$ = LCASE$(TRIM$(ANS$))
    IF UCASE$(TBL$) = "ZZLINKS" OR UCASE$(TBL$) = "_SCHEMA_META" THEN
        ERR$ = "RESERVED"
        GOSUB WB_ERR
        RETURN
    END IF
    V$ = TBL$
    GOSUB WB_VALNAME
    IF VBAD = 1 THEN
        ERR$ = "BAD TABLE NAME"
        GOSUB WB_ERR
        RETURN
    END IF
    PROMPT$ = "Columns (comma list): "
    GOSUB WB_PROMPT
    TCOLS$ = LCASE$(TRIM$(ANS$))
    IF TCOLS$ = "" THEN
        ERR$ = "BAD COLUMN LIST"
        GOSUB WB_ERR
        RETURN
    END IF
    NEWN = 0
    CI = 1
    MOREC = 1
    WHILE MOREC = 1
        S$ = TCOLS$
        D$ = ","
        N = CI
        GOSUB WB_GETTOK
        C$ = GETD$
        IF C$ = "" THEN
            MOREC = 0
        ELSE
            V$ = C$
            GOSUB WB_VALNAME
            IF VBAD = 1 THEN
                ERR$ = "BAD COLUMN NAME"
                GOSUB WB_ERR
                RETURN
            END IF
            DUP = 0
            FOR DI = 1 TO NEWN
                IF NEWC$(DI) = C$ THEN DUP = 1
            NEXT DI
            IF DUP = 1 THEN
                ERR$ = "DUPLICATE COLUMN"
                GOSUB WB_ERR
                RETURN
            END IF
            NEWN = NEWN + 1
            NEWC$(NEWN) = C$
            CI = CI + 1
        END IF
    WEND
    SQL_STMT$ = "CREATE TABLE " + TBL$ + " (" + TCOLS$ + ") PK KEY"
    IF LEN(SQL_STMT$) > 1800 THEN
        ERR$ = "STATEMENT TOO LONG"
        GOSUB WB_ERR
        RETURN
    END IF
    GOSUB WB_EXEC
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    SCREEN = 3
    RETURN


REM ==============================================================
REM  Table design (Task 3 placeholder; Task 4 fills it)
REM ==============================================================
SCR_DESIGN:
    GOSUB WB_CLS
    TITLE$ = "MiniSQL Workbench"
    FOOT$ = "B=back"
    GOSUB WB_HEADER
    TEXT$ = "  Table: " + TBL$
    GOSUB WB_LINE
    TEXT$ = "  Columns: " + TCOLS$
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_FOOTER
    PROMPT$ = "Selection: "
    GOSUB WB_PROMPT
    IF UCASE$(ANS$) = "B" THEN
        SCREEN = 2
        RETURN
    END IF
    ERR$ = "UNKNOWN SELECTION"
    GOSUB WB_ERR
    RETURN

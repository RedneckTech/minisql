REM ==============================================================
REM  DBWORK.BAS  -  MiniSQL Workbench
REM  Screen-based database designer / viewer / editor.
REM  Chains into minisql.bas for every database operation.
REM ==============================================================
START:
    COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
    COMMON SQL_STATUS, SQL_MSG$
    DIM REG$(10)
    GOSUB WB_BOOT
    SCREEN = 1
    WHILE SCREEN <> 0
        IF SCREEN = 1 THEN GOSUB SCR_START
        IF SCREEN = 2 THEN GOSUB SCR_TABLES
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
REM  Table list (Task 2 placeholder; Task 3 fills it)
REM ==============================================================
SCR_TABLES:
    GOSUB WB_CLS
    TITLE$ = "MiniSQL Workbench"
    FOOT$ = "N=new table   M=map   S=SQL   Q=quit"
    GOSUB WB_HEADER
    TEXT$ = "  DB: " + DB$
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    TEXT$ = "  No tables yet."
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
        ERR$ = "NEW TABLE IS NOT IMPLEMENTED YET"
        GOSUB WB_ERR
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
    ERR$ = "UNKNOWN SELECTION"
    GOSUB WB_ERR
    RETURN

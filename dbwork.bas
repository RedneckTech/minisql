REM ==============================================================
REM  DBWORK.BAS  -  MiniSQL Workbench
REM  Screen-based database designer / viewer / editor.
REM  Chains into minisql.bas for every database operation.
REM ==============================================================
START:
    COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
    COMMON SQL_STATUS, SQL_MSG$
    GOSUB WB_BOOT
    SCREEN = 1
    WHILE SCREEN <> 0
        IF SCREEN = 1 THEN GOSUB SCR_START
    WEND
    END


REM ==============================================================
REM  Boot: defaults and the reusable horizontal rule
REM ==============================================================
WB_BOOT:
    SQL_MODE$ = "RW"
    WB_HL$ = ""
    FOR I = 1 TO 77
        WB_HL$ = WB_HL$ + BOXCHAR$(5)
    NEXT I
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
    TEXT$ = "    (none)"
    GOSUB WB_LINE
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
        ERR$ = "OPEN DB IS NOT IMPLEMENTED YET"
        GOSUB WB_ERR
        RETURN
    END IF
    IF UCASE$(ANS$) = "S" THEN
        ERR$ = "SAMPLE SEED IS NOT IMPLEMENTED YET"
        GOSUB WB_ERR
        RETURN
    END IF
    ERR$ = "UNKNOWN SELECTION"
    GOSUB WB_ERR
    RETURN

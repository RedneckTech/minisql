REM ==============================================================
REM  WBMANY.BAS  -  fixture: 25 tables in WBTEST8
REM ==============================================================
START:
    COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
    COMMON SQL_STATUS, SQL_MSG$
    SQL_DB$ = "WBTEST8"
    SQL_MODE$ = "RW"
    SQL_CMD$ = "INITDB"
    CHAIN "minisql.bas"
    FOR I = 1 TO 25
        K$ = "t" + RIGHT$("0" + TRIM$(STR$(I)), 2)
        SQL_CMD$ = "EXEC"
        SQL_STMT$ = "CREATE TABLE " + K$ + " (a,b) PK KEY"
        CHAIN "minisql.bas"
        IF (I MOD 5) = 0 THEN X = SLEEP(0.25)
    NEXT I
    PRINT "MANY DONE"
    END

REM ==============================================================
REM  WBFILL.BAS  -  test fixture: 40 rows in WBTEST7/items
REM  Queues all inserts in batch.dat, then commits them in one
REM  minisql call (no chain per row).
REM ==============================================================
START:
    COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
    COMMON SQL_STATUS, SQL_MSG$
    SQL_DB$ = "WBTEST7"
    SQL_MODE$ = "RW"
    SQL_CMD$ = "INITDB"
    CHAIN "minisql.bas"
    SQL_CMD$ = "EXEC"
    SQL_STMT$ = "CREATE TABLE items (label,val) PK KEY"
    CHAIN "minisql.bas"
    OPEN "batch.dat" FOR OUTPUT AS #1
    PRINT #1, "BEGIN"
    FOR I = 1 TO 40
        K$ = "k" + RIGHT$("0" + TRIM$(STR$(I)), 2)
        L$ = "INSERT INTO items KEY " + K$
        L$ = L$ + " VALUES (label" + TRIM$(STR$(I))
        L$ = L$ + "," + TRIM$(STR$(I)) + ")"
        PRINT #1, L$
    NEXT I
    CLOSE #1
    SQL_CMD$ = "COMMIT"
    CHAIN "minisql.bas"
    PRINT "FILL DONE"
    END

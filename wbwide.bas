REM ==============================================================
REM  WBWIDE.BAS  -  fixture: table with 40 columns in WBTEST9
REM ==============================================================
START:
    COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
    COMMON SQL_STATUS, SQL_MSG$
    SQL_DB$ = "WBTEST9"
    SQL_MODE$ = "RW"
    SQL_CMD$ = "INITDB"
    CHAIN "minisql.bas"
    SQL_CMD$ = "EXEC"
    SQL_STMT$ = "CREATE TABLE t (c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,"
    SQL_STMT$ = SQL_STMT$ + "c11,c12,c13,c14,c15,c16,c17,c18,c19,c20,"
    SQL_STMT$ = SQL_STMT$ + "c21,c22,c23,c24,c25,c26,c27,c28,c29,c30,"
    SQL_STMT$ = SQL_STMT$ + "c31,c32,c33,c34,c35,c36,c37,c38,c39,c40)"
    SQL_STMT$ = SQL_STMT$ + " PK KEY"
    CHAIN "minisql.bas"
    PRINT "WIDE DONE"
    END

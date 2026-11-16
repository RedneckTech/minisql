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
    DIM LNKF$(30)
    DIM LNKFK$(30)
    DIM LNKTT$(30)
    DIM LNKTC$(30)
    DIM LNKKEY$(30)
    DIM DLINK$(30)
    DIM DKEY$(30)
    DIM TGTCOL$(40)
    DIM ROWKEYS$(15)
    DIM ROWLINES$(15)
    DIM PAGEKEYS$(700)
    DIM RN$(40)
    DIM RV$(40)
    DIM MAPL$(100)
    DIM SEED$(100)
    GOSUB WB_BOOT
    SCREEN = 1
    WHILE SCREEN <> 0
        IF SCREEN = 1 THEN GOSUB SCR_START
        IF SCREEN = 2 THEN GOSUB SCR_TABLES
        IF SCREEN = 3 THEN GOSUB SCR_DESIGN
        IF SCREEN = 4 THEN GOSUB SCR_BROWSE
        IF SCREEN = 8 THEN GOSUB SCR_MAP
        IF SCREEN = 9 THEN GOSUB SCR_SQL
        X = SLEEP(0.25)
    WEND
    END


REM ==============================================================
REM  Boot: defaults, horizontal rule, batch reset, registry
REM ==============================================================
WB_BOOT:
    SQL_MODE$ = "RW"
    PAGESZ = 15
    TLOADED = 0
    LLOADED = 0
    RNEED = 0
    STATUS$ = ""
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
    IF INSTR(UCASE$(SQL_MSG$), "QUEUED") > 0 THEN
        PRINT "TXN QUEUE ERROR" COLOR RED
        GOSUB WB_ROLLBACK
        SQL_STATUS = 1
    END IF
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

WB_PARSEROW:
    REM IN: ROWL$  OUT: RFN, RN$(), RV$(), RKN$, RKV$
    RFN = 0
    RKN$ = ""
    RKV$ = ""
    S$ = ROWL$
    D$ = "|"
    N = 1
    GOSUB WB_GETTOK
    IF GETD$ <> "R" THEN RETURN
    S$ = ROWL$
    D$ = "|"
    N = 2
    GOSUB WB_GETTOK
    RKN$ = GETD$
    S$ = ROWL$
    D$ = "|"
    N = 3
    GOSUB WB_GETTOK
    RKV$ = GETD$
    PN = 4
    PWHILE = 1
    WHILE PWHILE = 1
        S$ = ROWL$
        D$ = "|"
        N = PN
        GOSUB WB_GETTOK
        PTOK$ = GETD$
        IF PTOK$ = "" THEN
            PWHILE = 0
        ELSE
            PEQ = INSTR(PTOK$, "=")
            IF PEQ > 0 AND RFN < 40 THEN
                RFN = RFN + 1
                RN$(RFN) = LEFT$(PTOK$, PEQ-1)
                RV$(RFN) = MID$(PTOK$, PEQ+1)
            END IF
            PN = PN + 1
        END IF
    WEND
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
    IF INSTR(VU$, "FROM") > 0 THEN VBAD = 1: RETURN
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

WB_VALVAL:
    VBAD = 0
    IF LEN(V$) > 120 THEN VBAD = 1
    IF INSTR(V$, ",") > 0 THEN VBAD = 1
    IF INSTR(V$, "|") > 0 THEN VBAD = 1
    IF INSTR(V$, ")") > 0 THEN VBAD = 1
    RETURN

WB_VALKEY:
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
        IF VC$ = "." OR VC$ = "-" OR VC$ = "_" THEN VOK = 1
        IF VOK = 0 THEN
            VBAD = 1
            RETURN
        END IF
    NEXT VI
    VU$ = UCASE$(V$)
    IF INSTR(VU$, "LIMIT") > 0 THEN VBAD = 1
    IF INSTR(VU$, "VALUES") > 0 THEN VBAD = 1
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
    X = SLEEP(0.25)
    GOSUB WB_SPLIT
    FOR TI = 1 TO RESN
        L$ = RESL$(TI)
        IF UCASE$(L$) <> "ZZLINKS" AND TBNT < 50 THEN
            TBNT = TBNT + 1
            TBN$(TBNT) = L$
            SQL_STMT$ = "DESCRIBE " + L$
            GOSUB WB_EXEC
            IF SQL_STATUS = 0 THEN
                IF LEN(SQL_RESULT$) > 2000 THEN
                    TBC$(TBNT) = ""
                    ERR$ = "DESCRIBE TOO LONG"
                    GOSUB WB_ERR
                ELSE
                    GOSUB WB_PARSEDESC
                    TBC$(TBNT) = DCOLS$
                END IF
            ELSE
                TBC$(TBNT) = ""
                ERR$ = SQL_MSG$
                GOSUB WB_ERR
            END IF
            X = SLEEP(0.25)
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


WB_COUNTROWS:
    SQL_STMT$ = "SELECT COUNT(*) FROM " + TBL$
    GOSUB WB_EXEC
    IF SQL_STATUS = 0 THEN
        GOSUB WB_PARSECOUNT
        ROWS = CNT
    ELSE
        ROWS = 0
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
    END IF
    RETURN

WB_DROPCOL:
    REM IN: TBL$, DCOL$
    SQL_STMT$ = "ALTER TABLE " + TBL$ + " DROP " + DCOL$
    GOSUB WB_EXEC
    RETURN

WB_DROPTABLE:
    REM IN: TBL$
    SQL_STMT$ = "DROP TABLE " + TBL$
    GOSUB WB_EXEC
    RETURN

WB_INSERTROW:
    REM IN: TBL$, KVAL$, VALS$
    IERRLY = 0
    IF KVAL$ = "" THEN
        SQL_STMT$ = "INSERT INTO " + TBL$ + " VALUES (" + VALS$ + ")"
    ELSE
        SQL_STMT$ = "INSERT INTO " + TBL$ + " KEY " + KVAL$
        SQL_STMT$ = SQL_STMT$ + " VALUES (" + VALS$ + ")"
    END IF
    IF LEN(SQL_STMT$) > 1800 THEN
        ERR$ = "STATEMENT TOO LONG"
        GOSUB WB_ERR
        IERRLY = 1
        RETURN
    END IF
    GOSUB WB_EXEC
    RETURN

WB_LOADPAGE:
    IF PAGE <= 1 THEN
        SQL_STMT$ = "SELECT * FROM " + TBL$
        IF STARTKEY$ <> "" THEN
            SQL_STMT$ = SQL_STMT$ + " WHERE key>=" + STARTKEY$
        END IF
        SQL_STMT$ = SQL_STMT$ + " LIMIT " + TRIM$(STR$(PAGESZ))
    ELSE
        SQL_STMT$ = "SELECT * FROM " + TBL$
        SQL_STMT$ = SQL_STMT$ + " WHERE key>" + LASTKEY$
        SQL_STMT$ = SQL_STMT$ + " LIMIT " + TRIM$(STR$(PAGESZ))
    END IF
    GOSUB WB_EXEC
    ROWN = 0
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    GOSUB WB_SPLIT
    FOR RI = 1 TO RESN
        IF ROWN < PAGESZ THEN
            ROWL$ = RESL$(RI)
            GOSUB WB_PARSEROW
            ROWN = ROWN + 1
            ROWKEYS$(ROWN) = RKV$
            ROWLINES$(ROWN) = "  " + TRIM$(STR$(ROWN))
            ROWLINES$(ROWN) = ROWLINES$(ROWN) + "  key=" + RKV$
            FOR RJ = 1 TO RFN
                ROWLINES$(ROWN) = ROWLINES$(ROWN) + "  " + RN$(RJ)
                ROWLINES$(ROWN) = ROWLINES$(ROWN) + "=" + RV$(RJ)
            NEXT RJ
            IF LEN(ROWLINES$(ROWN)) > 74 THEN
                ROWLINES$(ROWN) = LEFT$(ROWLINES$(ROWN), 72) + ".."
            END IF
        END IF
    NEXT RI
    IF ROWN > 0 THEN LASTKEY$ = ROWKEYS$(ROWN)
    RETURN

WB_UPDATEROW:
    REM IN: TBL$, RK$, VALS$
    UERRLY = 0
    SQL_STMT$ = "REPLACE " + TBL$ + " KEY " + RK$
    SQL_STMT$ = SQL_STMT$ + " VALUES (" + VALS$ + ")"
    IF LEN(SQL_STMT$) > 1800 THEN
        ERR$ = "STATEMENT TOO LONG"
        GOSUB WB_ERR
        UERRLY = 1
        RETURN
    END IF
    GOSUB WB_EXEC
    RETURN

WB_DELETEROW:
    REM IN: TBL$, RK$
    SQL_STMT$ = "DELETE FROM " + TBL$ + " KEY " + RK$
    GOSUB WB_EXEC
    RETURN


WB_HASCOL:
    REM IN: HT$, HC$  OUT: HAS (0/1)
    HAS = 0
    IF HC$ = "key" THEN
        FOR TI = 1 TO TBNT
            IF TBN$(TI) = HT$ THEN HAS = 1
        NEXT TI
        RETURN
    END IF
    FOR TI = 1 TO TBNT
        IF TBN$(TI) = HT$ THEN
            HCOLS$ = TBC$(TI)
            CI = 1
            WHILE 1
                S$ = HCOLS$
                D$ = ","
                N = CI
                GOSUB WB_GETTOK
                C$ = GETD$
                IF C$ = "" THEN RETURN
                IF C$ = HC$ THEN
                    HAS = 1
                    RETURN
                END IF
                CI = CI + 1
            WEND
        END IF
    NEXT TI
    RETURN

WB_MAPLINES:
    MAPN = 0
    MAPN = MAPN + 1
    MAPL$(MAPN) = "Database map - DB: " + DB$
    MAPN = MAPN + 1
    MAPL$(MAPN) = "Tables: " + TRIM$(STR$(TBNT))
    MAPL$(MAPN) = MAPL$(MAPN) + "   Links: " + TRIM$(STR$(LNKT))
    MAPN = MAPN + 1
    MAPL$(MAPN) = ""
    FOR TI = 1 TO TBNT
        MAPN = MAPN + 1
        MAPL$(MAPN) = "  " + TBN$(TI) + ": " + TBC$(TI)
    NEXT TI
    MAPN = MAPN + 1
    MAPL$(MAPN) = ""
    MAPN = MAPN + 1
    MAPL$(MAPN) = "Links:"
    IF LNKT = 0 THEN
        MAPN = MAPN + 1
        MAPL$(MAPN) = "  (none)"
    ELSE
        FOR LI = 1 TO LNKT
            MAPN = MAPN + 1
            MAPL$(MAPN) = "  " + LNKF$(LI) + "." + LNKFK$(LI)
            MAPL$(MAPN) = MAPL$(MAPN) + " -> "
            MAPL$(MAPN) = MAPL$(MAPN) + LNKTT$(LI) + "." + LNKTC$(LI)
            HT$ = LNKF$(LI)
            HC$ = LNKFK$(LI)
            GOSUB WB_HASCOL
            IF HAS = 0 THEN MAPL$(MAPN) = MAPL$(MAPN) + " !"
            HT$ = LNKTT$(LI)
            HC$ = LNKTC$(LI)
            GOSUB WB_HASCOL
            IF HAS = 0 THEN MAPL$(MAPN) = MAPL$(MAPN) + " !"
        NEXT LI
    END IF
    RETURN


WB_TIDX:
    TIDX = 0
    FOR TI = 1 TO TBNT
        IF TBN$(TI) = TBL$ THEN TIDX = TI
    NEXT TI
    RETURN

WB_SEEDT:
    REM IN: TBL$, TCOLS$  OUT: TADD
    GOSUB WB_TIDX
    IF TIDX = 0 THEN
        SEEDN = SEEDN + 1
        SEED$(SEEDN) = "CREATE TABLE " + TBL$ + " ("
        SEED$(SEEDN) = SEED$(SEEDN) + TCOLS$ + ") PK KEY"
        TADD = 1
    ELSE
        SQL_STMT$ = "SELECT COUNT(*) FROM " + TBL$
        GOSUB WB_EXEC
        IF SQL_STATUS = 0 THEN
            GOSUB WB_PARSECOUNT
            IF CNT = 0 THEN
                TADD = 1
            ELSE
                TADD = 0
            END IF
        ELSE
            TADD = 0
        END IF
        X = SLEEP(0.25)
    END IF
    RETURN

WB_SEEDR:
    SEEDN = SEEDN + 1
    SEED$(SEEDN) = "INSERT INTO " + TBL$ + " KEY " + KVAL$
    SEED$(SEEDN) = SEED$(SEEDN) + " VALUES (" + VALS$ + ")"
    RETURN

WB_SEEDL:
    SEEDN = SEEDN + 1
    SEED$(SEEDN) = "INSERT INTO zzlinks VALUES ("
    SEED$(SEEDN) = SEED$(SEEDN) + LFT$ + "," + LFC$ + ","
    SEED$(SEEDN) = SEED$(SEEDN) + LTT$ + "," + LTC$ + ")"
    RETURN

WB_SEEDLINK:
    DUP = 0
    FOR LI = 1 TO LNKT
        IF LNKF$(LI) = LFT$ AND LNKFK$(LI) = LFC$ THEN
            IF LNKTT$(LI) = LTT$ AND LNKTC$(LI) = LTC$ THEN DUP = 1
        END IF
    NEXT LI
    IF DUP = 0 THEN GOSUB WB_SEEDL
    RETURN

WB_SEEDBATCH:
    SEEDN = 0
    TBL$ = "customers"
    TCOLS$ = "id,name,email,city"
    GOSUB WB_SEEDT
    IF TADD = 1 THEN
        KVAL$ = "c01"
        VALS$ = "c01,Alice,alice@x,Chicago"
        GOSUB WB_SEEDR
        KVAL$ = "c02"
        VALS$ = "c02,Bob,bob@x,Boston"
        GOSUB WB_SEEDR
    END IF
    TBL$ = "suppliers"
    TCOLS$ = "id,name,city"
    GOSUB WB_SEEDT
    IF TADD = 1 THEN
        KVAL$ = "s01"
        VALS$ = "s01,Acme,Chicago"
        GOSUB WB_SEEDR
        KVAL$ = "s02"
        VALS$ = "s02,Globex,Boston"
        GOSUB WB_SEEDR
    END IF
    TBL$ = "products"
    TCOLS$ = "id,name,price,stock,supplier_id"
    GOSUB WB_SEEDT
    IF TADD = 1 THEN
        KVAL$ = "p01"
        VALS$ = "p01,Widget,10,100,s01"
        GOSUB WB_SEEDR
        KVAL$ = "p02"
        VALS$ = "p02,Gadget,20,50,s02"
        GOSUB WB_SEEDR
    END IF
    TBL$ = "orders"
    TCOLS$ = "id,customer_id,date,status"
    GOSUB WB_SEEDT
    IF TADD = 1 THEN
        KVAL$ = "o01"
        VALS$ = "o01,c01,2026-01-10,open"
        GOSUB WB_SEEDR
        KVAL$ = "o02"
        VALS$ = "o02,c02,2026-01-11,shipped"
        GOSUB WB_SEEDR
    END IF
    TBL$ = "order_lines"
    TCOLS$ = "id,order_id,product_id,qty,price"
    GOSUB WB_SEEDT
    IF TADD = 1 THEN
        KVAL$ = "l01"
        VALS$ = "l01,o01,p01,2,10"
        GOSUB WB_SEEDR
        KVAL$ = "l02"
        VALS$ = "l02,o01,p02,1,20"
        GOSUB WB_SEEDR
    END IF
    TBL$ = "shipments"
    TCOLS$ = "id,order_id,carrier,date"
    GOSUB WB_SEEDT
    IF TADD = 1 THEN
        KVAL$ = "h01"
        VALS$ = "h01,o02,UPS,2026-01-12"
        GOSUB WB_SEEDR
    END IF
    LFT$ = "orders"
    LFC$ = "customer_id"
    LTT$ = "customers"
    LTC$ = "id"
    GOSUB WB_SEEDLINK
    LFT$ = "order_lines"
    LFC$ = "order_id"
    LTT$ = "orders"
    LTC$ = "id"
    GOSUB WB_SEEDLINK
    LFT$ = "order_lines"
    LFC$ = "product_id"
    LTT$ = "products"
    LTC$ = "id"
    GOSUB WB_SEEDLINK
    LFT$ = "shipments"
    LFC$ = "order_id"
    LTT$ = "orders"
    LTC$ = "id"
    GOSUB WB_SEEDLINK
    LFT$ = "products"
    LFC$ = "supplier_id"
    LTT$ = "suppliers"
    LTC$ = "id"
    GOSUB WB_SEEDLINK
    IF SEEDN > 0 THEN
        OPEN "batch.dat" FOR OUTPUT AS #5
        PRINT #5, "BEGIN"
        FOR SI = 1 TO SEEDN
            PRINT #5, SEED$(SI)
        NEXT SI
        CLOSE #5
        SQL_CMD$ = "COMMIT"
        GOSUB WB_CHAIN
    ELSE
        SQL_STATUS = 0
        SQL_MSG$ = "SAMPLE ALREADY PRESENT"
    END IF
    RETURN


REM ==============================================================
REM  Link metadata (zzlinks)
REM ==============================================================
WB_LINKROW:
    REM IN: ROWL$  OUT: LFT$, LFC$, LTT$, LTC$, LKEY$
    LFT$ = ""
    LFC$ = ""
    LTT$ = ""
    LTC$ = ""
    LKEY$ = ""
    S$ = ROWL$
    D$ = "|"
    N = 3
    GOSUB WB_GETTOK
    LKEY$ = GETD$
    FOR LJ = 4 TO 7
        S$ = ROWL$
        D$ = "|"
        N = LJ
        GOSUB WB_GETTOK
        LTOK$ = GETD$
        EQ = INSTR(LTOK$, "=")
        IF EQ > 0 THEN
            LN$ = LEFT$(LTOK$, EQ-1)
            LV$ = MID$(LTOK$, EQ+1)
            IF LN$ = "ftbl" THEN LFT$ = LV$
            IF LN$ = "fcol" THEN LFC$ = LV$
            IF LN$ = "ttbl" THEN LTT$ = LV$
            IF LN$ = "tcol" THEN LTC$ = LV$
        END IF
    NEXT LJ
    RETURN

WB_LOADLINKS:
    LNKT = 0
    SQL_STMT$ = "SELECT * FROM zzlinks"
    GOSUB WB_EXEC
    IF SQL_STATUS <> 0 THEN
        LNKT = 0
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    GOSUB WB_SPLIT
    FOR LI = 1 TO RESN
        IF LNKT < 30 THEN
            ROWL$ = RESL$(LI)
            GOSUB WB_LINKROW
            LNKT = LNKT + 1
            LNKF$(LNKT) = LFT$
            LNKFK$(LNKT) = LFC$
            LNKTT$(LNKT) = LTT$
            LNKTC$(LNKT) = LTC$
            LNKKEY$(LNKT) = LKEY$
        END IF
    NEXT LI
    RETURN

WB_SAVELINK:
    REM IN: LFT$, LFC$, LTT$, LTC$
    SQL_STMT$ = "INSERT INTO zzlinks VALUES ("
    SQL_STMT$ = SQL_STMT$ + LFT$ + "," + LFC$ + ","
    SQL_STMT$ = SQL_STMT$ + LTT$ + "," + LTC$ + ")"
    IF LEN(SQL_STMT$) > 1800 THEN
        ERR$ = "STATEMENT TOO LONG"
        GOSUB WB_ERR
        RETURN
    END IF
    GOSUB WB_EXEC
    RETURN

WB_DELLINK:
    REM IN: LK$
    SQL_STMT$ = "DELETE FROM zzlinks KEY " + LK$
    GOSUB WB_EXEC
    RETURN

WB_LINKSFOR:
    DLN = 0
    FOR LI = 1 TO LNKT
        IF LNKF$(LI) = TBL$ OR LNKTT$(LI) = TBL$ THEN
            IF DLN < 30 THEN
                DLN = DLN + 1
                IF LNKF$(LI) = TBL$ THEN
                    DLINK$(DLN) = LNKF$(LI) + "." + LNKFK$(LI)
                    DLINK$(DLN) = DLINK$(DLN) + " -> "
                    DLINK$(DLN) = DLINK$(DLN) + LNKTT$(LI)
                    DLINK$(DLN) = DLINK$(DLN) + "." + LNKTC$(LI)
                ELSE
                    DLINK$(DLN) = LNKTT$(LI) + "." + LNKTC$(LI)
                    DLINK$(DLN) = DLINK$(DLN) + " <- "
                    DLINK$(DLN) = DLINK$(DLN) + LNKF$(LI)
                    DLINK$(DLN) = DLINK$(DLN) + "." + LNKFK$(LI)
                END IF
                DKEY$(DLN) = LNKKEY$(LI)
            END IF
        END IF
    NEXT LI
    RETURN

WB_LOADTGT:
    TGTN = 0
    CI = 1
    WHILE 1
        S$ = TGTCOLS$
        D$ = ","
        N = CI
        GOSUB WB_GETTOK
        C$ = GETD$
        IF C$ = "" THEN RETURN
        IF TGTN < 40 THEN
            TGTN = TGTN + 1
            TGTCOL$(TGTN) = C$
        END IF
        CI = CI + 1
    WEND
    RETURN

WB_CLEANLINKS:
    REM IN: TBL$, DCOL$ (empty = whole table)
    CLNDEL = 0
    GOSUB WB_LOADLINKS
    FOR LI = 1 TO LNKT
        DMATCH = 0
        IF DCOL$ = "" THEN
            IF LNKF$(LI) = TBL$ OR LNKTT$(LI) = TBL$ THEN DMATCH = 1
        ELSE
            IF LNKF$(LI) = TBL$ AND LNKFK$(LI) = DCOL$ THEN DMATCH = 1
            IF LNKTT$(LI) = TBL$ AND LNKTC$(LI) = DCOL$ THEN DMATCH = 1
        END IF
        IF DMATCH = 1 THEN
            LK$ = LNKKEY$(LI)
            GOSUB WB_DELLINK
            IF SQL_STATUS = 0 THEN CLNDEL = CLNDEL + 1
            X = SLEEP(0.25)
        END IF
    NEXT LI
    LLOADED = 0
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
    SQL_STATUS = 0
    SQL_MSG$ = ""
    GOSUB WB_ADDREG
    GOSUB WB_WRITEREG
    TBL$ = ""
    TCOLS$ = ""
    TPK$ = "key"
    TLOADED = 0
    LLOADED = 0
    RNEED = 0
    STATUS$ = ""
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
    GOSUB WB_HEADER
    TEXT$ = ""
    GOSUB WB_LINE
    TEXT$ = "  Design and edit MiniSQL databases."
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_SEP
    TEXT$ = "  N = new database   S = sample SHOP database"
    GOSUB WB_LINE
    TEXT$ = "  L = recent databases   ? = help   Q = quit"
    GOSUB WB_LINE
    GOSUB WB_BOT
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
        GOSUB SCR_SEED
        RETURN
    END IF
    IF UCASE$(ANS$) = "L" THEN
        GOSUB SCR_RECENT
        RETURN
    END IF
    IF ANS$ = "?" THEN
        GOSUB SCR_HELP
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
REM  Recent databases
REM ==============================================================
SCR_RECENT:
    GOSUB WB_CLS
    TITLE$ = "MiniSQL Workbench"
    FOOT$ = "Number to open   B=back"
    GOSUB WB_HEADER
    TEXT$ = "  Recent databases:"
    GOSUB WB_LINE
    IF REGN = 0 THEN
        TEXT$ = "    (none)"
        GOSUB WB_LINE
    ELSE
        FOR I = 1 TO REGN
            TEXT$ = "    " + TRIM$(STR$(I)) + "  " + REG$(I)
            GOSUB WB_LINE
        NEXT I
    END IF
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_FOOTER
    PROMPT$ = "Selection: "
    GOSUB WB_PROMPT
    IF ANS$ = "" OR UCASE$(ANS$) = "B" THEN RETURN
    IF VAL(ANS$) >= 1 AND VAL(ANS$) <= REGN THEN
        DB$ = REG$(VAL(ANS$))
        GOSUB WB_VALDB
        IF DBBAD = 1 THEN
            GOSUB WB_ERR
            RETURN
        END IF
        GOSUB WB_OPENDB
    END IF
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
    TEXT$ = "  " + STATUS$
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    IF TLOADED = 0 THEN
        GOSUB WB_LOADTABLES
        TLOADED = 1
    END IF
    IF TBNT = 0 THEN
        TEXT$ = "  No tables yet."
        GOSUB WB_LINE
    ELSE
        FOR TI = 1 TO TBNT
            TEXT$ = "  " + TRIM$(STR$(TI)) + "  " + TBN$(TI)
            GOSUB WB_LINE
            TEXT$ = "       " + TBC$(TI)
            GOSUB WB_LINE
            IF (TI MOD 5) = 0 THEN X = SLEEP(0.1)
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
        IF TBNT >= 50 THEN
            ERR$ = "50 TABLE LIMIT"
            GOSUB WB_ERR
            RETURN
        END IF
        GOSUB SCR_NEWTABLE
        RETURN
    END IF
    IF UCASE$(ANS$) = "R" THEN
        TLOADED = 0
        RETURN
    END IF
    IF UCASE$(ANS$) = "M" THEN
        SCREEN = 8
        RETURN
    END IF
    IF UCASE$(ANS$) = "S" THEN
        SCREEN = 9
        RETURN
    END IF
    IF VAL(ANS$) >= 1 AND VAL(ANS$) <= TBNT THEN
        TBL$ = TBN$(VAL(ANS$))
        TCOLS$ = TBC$(VAL(ANS$))
        TPK$ = "key"
        STATUS$ = ""
        LLOADED = 0
        RNEED = 1
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
            IF NEWN >= 40 THEN
                ERR$ = "40 COLUMN LIMIT"
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
    TPK$ = "key"
    STATUS$ = ""
    IF TBNT < 50 THEN
        TBNT = TBNT + 1
        TBN$(TBNT) = TBL$
        TBC$(TBNT) = TCOLS$
    END IF
    TLOADED = 1
    RNEED = 1
    SCREEN = 3
    RETURN


REM ==============================================================
REM  Add a link from the current table
REM ==============================================================
WB_LINKADD:
    LFT$ = TBL$
    PRINT "From column:"
    PRINT "  1  KEY"
    FOR CI = 1 TO COLNT
        PRINT "  " + TRIM$(STR$(CI+1)) + "  " + COLN$(CI)
    NEXT CI
    PROMPT$ = "From column number: "
    GOSUB WB_PROMPT
    FC = VAL(TRIM$(ANS$))
    IF FC < 1 OR FC > COLNT + 1 THEN
        ERR$ = "BAD COLUMN NUMBER"
        GOSUB WB_ERR
        RETURN
    END IF
    IF FC = 1 THEN
        LFC$ = "key"
    ELSE
        LFC$ = COLN$(FC-1)
    END IF
    PRINT "Target table:"
    FOR TI = 1 TO TBNT
        PRINT "  " + TRIM$(STR$(TI)) + "  " + TBN$(TI)
    NEXT TI
    PROMPT$ = "Target table number: "
    GOSUB WB_PROMPT
    TT = VAL(TRIM$(ANS$))
    IF TT < 1 OR TT > TBNT THEN
        ERR$ = "BAD TABLE NUMBER"
        GOSUB WB_ERR
        RETURN
    END IF
    LTT$ = TBN$(TT)
    TGTCOLS$ = TBC$(TT)
    GOSUB WB_LOADTGT
    PRINT "Target column:"
    PRINT "  1  KEY"
    FOR CI = 1 TO TGTN
        PRINT "  " + TRIM$(STR$(CI+1)) + "  " + TGTCOL$(CI)
    NEXT CI
    PROMPT$ = "Target column number: "
    GOSUB WB_PROMPT
    TC = VAL(TRIM$(ANS$))
    IF TC < 1 OR TC > TGTN + 1 THEN
        ERR$ = "BAD COLUMN NUMBER"
        GOSUB WB_ERR
        RETURN
    END IF
    IF TC = 1 THEN
        LTC$ = "key"
    ELSE
        LTC$ = TGTCOL$(TC-1)
    END IF
    IF LLOADED = 0 THEN
        GOSUB WB_LOADLINKS
        LLOADED = 1
    END IF
    DUP = 0
    FOR LI = 1 TO LNKT
        IF LNKF$(LI) = LFT$ AND LNKFK$(LI) = LFC$ THEN
            IF LNKTT$(LI) = LTT$ AND LNKTC$(LI) = LTC$ THEN DUP = 1
        END IF
    NEXT LI
    IF DUP = 1 THEN
        ERR$ = "LINK EXISTS"
        GOSUB WB_ERR
        RETURN
    END IF
    IF LNKT >= 30 THEN
        ERR$ = "30 LINK LIMIT"
        GOSUB WB_ERR
        RETURN
    END IF
    GOSUB WB_SAVELINK
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
    ELSE
        STATUS$ = "Linked"
        LLOADED = 0
    END IF
    RETURN


REM ==============================================================
REM  Table design: columns, links, add/drop column, drop table
REM ==============================================================
SCR_DESIGN:
    IF RNEED = 1 THEN
        GOSUB WB_COUNTROWS
        RNEED = 0
    END IF
    GOSUB WB_LOADCOLS
    IF LLOADED = 0 THEN
        GOSUB WB_LOADLINKS
        LLOADED = 1
    END IF
    GOSUB WB_LINKSFOR
    GOSUB WB_CLS
    TITLE$ = "MiniSQL Workbench"
    FOOT$ = "A=add D=drop L=link X=unlink R=refr T=drop B=rows Q=back"
    GOSUB WB_HEADER
    TEXT$ = "  Table: " + TBL$
    GOSUB WB_LINE
    TEXT$ = "  KEY: " + TPK$ + "    Rows: " + TRIM$(STR$(ROWS))
    GOSUB WB_LINE
    IF DLN = 0 THEN
        TEXT$ = "  Links: (none)"
        GOSUB WB_LINE
    ELSE
        FOR LI = 1 TO DLN
            TEXT$ = "  " + TRIM$(STR$(LI)) + "  " + DLINK$(LI)
            GOSUB WB_LINE
        NEXT LI
    END IF
    TEXT$ = "  " + STATUS$
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    IF COLNT = 0 THEN
        TEXT$ = "  (no columns)"
        GOSUB WB_LINE
    ELSE
        FOR CI = 1 TO COLNT
            TEXT$ = "  " + TRIM$(STR$(CI)) + "  " + COLN$(CI)
            GOSUB WB_LINE
        NEXT CI
    END IF
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_FOOTER
    PROMPT$ = "Selection: "
    GOSUB WB_PROMPT
    IF UCASE$(ANS$) = "R" THEN
        SQL_STMT$ = "DESCRIBE " + TBL$
        GOSUB WB_EXEC
        IF SQL_STATUS = 0 THEN
            GOSUB WB_PARSEDESC
            TCOLS$ = DCOLS$
            TPK$ = DPK$
        ELSE
            ERR$ = SQL_MSG$
            GOSUB WB_ERR
        END IF
        LLOADED = 0
        RNEED = 1
        RETURN
    END IF
    IF UCASE$(ANS$) = "Q" THEN
        SCREEN = 2
        RETURN
    END IF
    IF UCASE$(ANS$) = "B" THEN
        PAGE = 1
        LASTKEY$ = ""
        SCREEN = 4
        RETURN
    END IF
    IF UCASE$(ANS$) = "A" THEN
        IF COLNT >= 40 THEN
            ERR$ = "40 COLUMN LIMIT"
            GOSUB WB_ERR
            RETURN
        END IF
        PROMPT$ = "New column: "
        GOSUB WB_PROMPT
        V$ = LCASE$(TRIM$(ANS$))
        GOSUB WB_VALNAME
        IF VBAD = 1 THEN
            ERR$ = "BAD COLUMN NAME"
            GOSUB WB_ERR
            RETURN
        END IF
        DUP = 0
        FOR CI = 1 TO COLNT
            IF COLN$(CI) = V$ THEN DUP = 1
        NEXT CI
        IF DUP = 1 THEN
            ERR$ = "COLUMN EXISTS"
            GOSUB WB_ERR
            RETURN
        END IF
        SQL_STMT$ = "ALTER TABLE " + TBL$ + " ADD " + V$
        GOSUB WB_EXEC
        IF SQL_STATUS <> 0 THEN
            ERR$ = SQL_MSG$
            GOSUB WB_ERR
        ELSE
            IF TCOLS$ = "" THEN
                TCOLS$ = V$
            ELSE
                TCOLS$ = TCOLS$ + "," + V$
            END IF
            STATUS$ = "Added " + V$
            TLOADED = 0
        END IF
        RETURN
    END IF
    ISD = 0
    IF UCASE$(ANS$) = "D" THEN
        PROMPT$ = "Column number: "
        GOSUB WB_PROMPT
        DN = VAL(TRIM$(ANS$))
        ISD = 1
    ELSEIF LEFT$(UCASE$(ANS$), 2) = "D " THEN
        S$ = ANS$
        D$ = " "
        N = 2
        GOSUB WB_GETTOK
        DN = VAL(GETD$)
        ISD = 1
    END IF
    IF ISD = 1 THEN
        IF DN < 1 OR DN > COLNT THEN
            ERR$ = "BAD COLUMN NUMBER"
            GOSUB WB_ERR
            RETURN
        END IF
        IF COLNT = 1 THEN
            ERR$ = "LAST COLUMN"
            GOSUB WB_ERR
            RETURN
        END IF
        DCOL$ = COLN$(DN)
        LNKCNT = 0
        FOR LI = 1 TO LNKT
            IF LNKF$(LI) = TBL$ AND LNKFK$(LI) = DCOL$ THEN
                LNKCNT = LNKCNT + 1
            END IF
            IF LNKTT$(LI) = TBL$ AND LNKTC$(LI) = DCOL$ THEN
                LNKCNT = LNKCNT + 1
            END IF
        NEXT LI
        PROMPT$ = "Drop column " + DCOL$
        IF LNKCNT > 0 THEN
            PROMPT$ = PROMPT$ + " (" + TRIM$(STR$(LNKCNT))
            PROMPT$ = PROMPT$ + " links)"
        END IF
        GOSUB WB_YES
        IF YESNO = 1 THEN
            GOSUB WB_DROPCOL
            IF SQL_STATUS <> 0 THEN
                ERR$ = SQL_MSG$
                GOSUB WB_ERR
            ELSE
                NEWCOLS$ = ""
                FOR CI = 1 TO COLNT
                    IF CI <> DN THEN
                        IF NEWCOLS$ <> "" THEN
                            NEWCOLS$ = NEWCOLS$ + ","
                        END IF
                        NEWCOLS$ = NEWCOLS$ + COLN$(CI)
                    END IF
                NEXT CI
                TCOLS$ = NEWCOLS$
                GOSUB WB_CLEANLINKS
                STATUS$ = "Dropped " + DCOL$
                IF CLNDEL > 0 THEN
                    STATUS$ = STATUS$ + " ("
                    STATUS$ = STATUS$ + TRIM$(STR$(CLNDEL))
                    STATUS$ = STATUS$ + " link removed)"
                END IF
                TLOADED = 0
            END IF
        END IF
        RETURN
    END IF
    IF UCASE$(ANS$) = "T" THEN
        PROMPT$ = "Type table name to confirm: "
        GOSUB WB_PROMPT
        IF UCASE$(TRIM$(ANS$)) <> UCASE$(TBL$) THEN
            PRINT "Cancelled"
            RETURN
        END IF
        GOSUB WB_DROPTABLE
        IF SQL_STATUS <> 0 THEN
            ERR$ = SQL_MSG$
            GOSUB WB_ERR
        ELSE
            DCOL$ = ""
            GOSUB WB_CLEANLINKS
            STATUS$ = "Table dropped"
            IF CLNDEL > 0 THEN
                STATUS$ = STATUS$ + " (" + TRIM$(STR$(CLNDEL))
                STATUS$ = STATUS$ + " links)"
            END IF
            TLOADED = 0
            SCREEN = 2
        END IF
        RETURN
    END IF
    IF UCASE$(ANS$) = "L" THEN
        GOSUB WB_LINKADD
        RETURN
    END IF
    IF UCASE$(ANS$) = "X" THEN
        PROMPT$ = "Link number: "
        GOSUB WB_PROMPT
        XN = VAL(TRIM$(ANS$))
        IF XN < 1 OR XN > DLN THEN
            ERR$ = "BAD LINK NUMBER"
            GOSUB WB_ERR
            RETURN
        END IF
        LK$ = DKEY$(XN)
        GOSUB WB_DELLINK
        IF SQL_STATUS <> 0 THEN
            ERR$ = SQL_MSG$
            GOSUB WB_ERR
        ELSE
            STATUS$ = "Unlinked"
            LLOADED = 0
        END IF
        RETURN
    END IF
    IF UCASE$(ANS$) = "I" THEN
        GOSUB SCR_INSERT
        RETURN
    END IF
    IF UCASE$(ANS$) = "V" THEN
        ERR$ = "VIEW ROW IS NOT IMPLEMENTED YET"
        GOSUB WB_ERR
        RETURN
    END IF
    ERR$ = "UNKNOWN SELECTION"
    GOSUB WB_ERR
    RETURN

REM ==============================================================
REM  Insert a row
REM ==============================================================
SCR_INSERT:
    PROMPT$ = "Key (blank = auto): "
    GOSUB WB_PROMPT
    KVAL$ = TRIM$(ANS$)
    IF KVAL$ <> "" THEN
        V$ = KVAL$
        GOSUB WB_VALKEY
        IF VBAD = 1 THEN
            ERR$ = "BAD KEY"
            GOSUB WB_ERR
            RETURN
        END IF
    END IF
    VALS$ = ""
    FOR CI = 1 TO COLNT
        PROMPT$ = COLN$(CI) + ": "
        GOSUB WB_PROMPT
        V$ = TRIM$(ANS$)
        GOSUB WB_VALVAL
        IF VBAD = 1 THEN
            ERR$ = "BAD VALUE"
            GOSUB WB_ERR
            RETURN
        END IF
        IF CI > 1 THEN VALS$ = VALS$ + ","
        VALS$ = VALS$ + V$
    NEXT CI
    GOSUB WB_INSERTROW
    IF IERRLY = 1 THEN RETURN
    IF SQL_STATUS = 0 THEN
        STATUS$ = "Inserted"
        RNEED = 1
    ELSEIF SQL_STATUS = 47 THEN
        ERR$ = "DUPLICATE KEY"
        GOSUB WB_ERR
    ELSE
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
    END IF
    RETURN

REM ==============================================================
REM  Row browser
REM ==============================================================
SCR_BROWSE:
    PAGE = 1
    LASTKEY$ = ""
    STARTKEY$ = ""
    GOSUB WB_LOADPAGE
    PAGEKEYS$(1) = LASTKEY$
    MOREBR = 1
    WHILE MOREBR = 1
        GOSUB WB_CLS
        TITLE$ = "MiniSQL Workbench"
        FOOT$ = "N=next P=prev V=view E=edit D=del I=ins K=key B=back"
        GOSUB WB_HEADER
        TEXT$ = "  Table: " + TBL$ + "    Page "
        TEXT$ = TEXT$ + TRIM$(STR$(PAGE))
        GOSUB WB_LINE
        TEXT$ = "  Rows: " + TRIM$(STR$(ROWN))
        GOSUB WB_LINE
        TEXT$ = "  " + STATUS$
        GOSUB WB_LINE
        TEXT$ = ""
        GOSUB WB_LINE
        IF ROWN = 0 THEN
            TEXT$ = "  No rows."
            GOSUB WB_LINE
        ELSE
            FOR RI = 1 TO ROWN
                TEXT$ = ROWLINES$(RI)
                GOSUB WB_LINE
            NEXT RI
        END IF
        GOSUB WB_FOOTER
        PROMPT$ = "Selection: "
        GOSUB WB_PROMPT
        IF UCASE$(ANS$) = "B" OR UCASE$(ANS$) = "Q" THEN
            MOREBR = 0
        ELSEIF UCASE$(ANS$) = "N" THEN
            IF ROWN = PAGESZ THEN
                PAGE = PAGE + 1
                LASTKEY$ = PAGEKEYS$(PAGE-1)
                GOSUB WB_LOADPAGE
                PAGEKEYS$(PAGE) = LASTKEY$
            END IF
        ELSEIF UCASE$(ANS$) = "P" THEN
            IF PAGE > 1 THEN
                PAGE = PAGE - 1
                IF PAGE = 1 THEN
                    LASTKEY$ = ""
                ELSE
                    LASTKEY$ = PAGEKEYS$(PAGE-1)
                END IF
                GOSUB WB_LOADPAGE
                PAGEKEYS$(PAGE) = LASTKEY$
            END IF
        ELSEIF UCASE$(ANS$) = "R" THEN
            IF PAGE = 1 THEN
                LASTKEY$ = ""
            ELSE
                LASTKEY$ = PAGEKEYS$(PAGE-1)
            END IF
            GOSUB WB_LOADPAGE
            PAGEKEYS$(PAGE) = LASTKEY$
        ELSEIF UCASE$(ANS$) = "K" THEN
            PROMPT$ = "Key: "
            GOSUB WB_PROMPT
            V$ = TRIM$(ANS$)
            GOSUB WB_VALKEY
            IF VBAD = 1 THEN
                ERR$ = "BAD KEY"
                GOSUB WB_ERR
            ELSE
                STARTKEY$ = V$
                PAGE = 1
                LASTKEY$ = ""
                GOSUB WB_LOADPAGE
                PAGEKEYS$(1) = LASTKEY$
            END IF
        ELSEIF LEFT$(UCASE$(ANS$), 2) = "K " THEN
            S$ = ANS$
            D$ = " "
            N = 2
            GOSUB WB_GETTOK
            V$ = GETD$
            GOSUB WB_VALKEY
            IF VBAD = 1 THEN
                ERR$ = "BAD KEY"
                GOSUB WB_ERR
            ELSE
                STARTKEY$ = V$
                PAGE = 1
                LASTKEY$ = ""
                GOSUB WB_LOADPAGE
                PAGEKEYS$(1) = LASTKEY$
            END IF
        ELSEIF UCASE$(ANS$) = "I" THEN
            GOSUB SCR_INSERT
            PAGE = 1
            LASTKEY$ = ""
            GOSUB WB_LOADPAGE
            PAGEKEYS$(1) = LASTKEY$
        ELSEIF LEFT$(UCASE$(ANS$), 2) = "V " THEN
            S$ = ANS$
            D$ = " "
            N = 2
            GOSUB WB_GETTOK
            VN = VAL(GETD$)
            IF VN < 1 OR VN > ROWN THEN
                ERR$ = "BAD ROW NUMBER"
                GOSUB WB_ERR
            ELSE
                SELROW = VN
                GOSUB SCR_VIEW
            END IF
        ELSEIF UCASE$(ANS$) = "V" THEN
            PROMPT$ = "Row number: "
            GOSUB WB_PROMPT
            VN = VAL(TRIM$(ANS$))
            IF VN < 1 OR VN > ROWN THEN
                ERR$ = "BAD ROW NUMBER"
                GOSUB WB_ERR
            ELSE
                SELROW = VN
                GOSUB SCR_VIEW
            END IF
        ELSEIF UCASE$(ANS$) = "E" THEN
            PROMPT$ = "Row number: "
            GOSUB WB_PROMPT
            VN = VAL(TRIM$(ANS$))
            IF VN < 1 OR VN > ROWN THEN
                ERR$ = "BAD ROW NUMBER"
                GOSUB WB_ERR
            ELSE
                SELROW = VN
                GOSUB SCR_EDIT
                PAGE = 1
                LASTKEY$ = ""
                GOSUB WB_LOADPAGE
                PAGEKEYS$(1) = LASTKEY$
            END IF
        ELSEIF LEFT$(UCASE$(ANS$), 2) = "E " THEN
            S$ = ANS$
            D$ = " "
            N = 2
            GOSUB WB_GETTOK
            VN = VAL(GETD$)
            IF VN < 1 OR VN > ROWN THEN
                ERR$ = "BAD ROW NUMBER"
                GOSUB WB_ERR
            ELSE
                SELROW = VN
                GOSUB SCR_EDIT
                PAGE = 1
                LASTKEY$ = ""
                GOSUB WB_LOADPAGE
                PAGEKEYS$(1) = LASTKEY$
            END IF
        ELSEIF UCASE$(ANS$) = "D" THEN
            PROMPT$ = "Row number: "
            GOSUB WB_PROMPT
            VN = VAL(TRIM$(ANS$))
            IF VN < 1 OR VN > ROWN THEN
                ERR$ = "BAD ROW NUMBER"
                GOSUB WB_ERR
            ELSE
                SELROW = VN
                GOSUB SCR_DELETE
                PAGE = 1
                LASTKEY$ = ""
                GOSUB WB_LOADPAGE
                PAGEKEYS$(1) = LASTKEY$
            END IF
        ELSEIF LEFT$(UCASE$(ANS$), 2) = "D " THEN
            S$ = ANS$
            D$ = " "
            N = 2
            GOSUB WB_GETTOK
            VN = VAL(GETD$)
            IF VN < 1 OR VN > ROWN THEN
                ERR$ = "BAD ROW NUMBER"
                GOSUB WB_ERR
            ELSE
                SELROW = VN
                GOSUB SCR_DELETE
                PAGE = 1
                LASTKEY$ = ""
                GOSUB WB_LOADPAGE
                PAGEKEYS$(1) = LASTKEY$
            END IF
        ELSE
            ERR$ = "UNKNOWN SELECTION"
            GOSUB WB_ERR
        END IF
        X = SLEEP(0.1)
    WEND
    SCREEN = 3
    RETURN


REM ==============================================================
REM  View one row
REM ==============================================================
SCR_VIEW:
    RK$ = ROWKEYS$(SELROW)
    SQL_STMT$ = "SELECT * FROM " + TBL$ + " WHERE KEY=" + RK$
    GOSUB WB_EXEC
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    GOSUB WB_SPLIT
    IF RESN = 0 THEN
        ERR$ = "ROW NOT FOUND"
        GOSUB WB_ERR
        RETURN
    END IF
    ROWL$ = RESL$(1)
    GOSUB WB_PARSEROW
    GOSUB WB_CLS
    TITLE$ = "MiniSQL Workbench"
    FOOT$ = "Press ENTER to return"
    GOSUB WB_HEADER
    TEXT$ = "  Table: " + TBL$ + "    Key: " + RKV$
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    FOR RJ = 1 TO RFN
        TEXT$ = "  " + RN$(RJ) + " = " + RV$(RJ)
        GOSUB WB_LINE
    NEXT RJ
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_FOOTER
    INPUT "Press ENTER...", X$
    RETURN

REM ==============================================================
REM  Edit one row
REM ==============================================================
SCR_EDIT:
    RK$ = ROWKEYS$(SELROW)
    SQL_STMT$ = "SELECT * FROM " + TBL$ + " WHERE KEY=" + RK$
    GOSUB WB_EXEC
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    GOSUB WB_SPLIT
    IF RESN = 0 THEN
        ERR$ = "ROW NOT FOUND"
        GOSUB WB_ERR
        RETURN
    END IF
    ROWL$ = RESL$(1)
    GOSUB WB_PARSEROW
    GOSUB WB_CLS
    TITLE$ = "MiniSQL Workbench"
    FOOT$ = "Empty keeps; @ clears; @@ is @"
    GOSUB WB_HEADER
    TEXT$ = "  Edit " + TBL$ + "    Key: " + RK$
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_FOOTER
    VALS$ = ""
    CLEARED = 0
    FOR CI = 1 TO COLNT
        CUR$ = ""
        FOR RJ = 1 TO RFN
            IF RN$(RJ) = COLN$(CI) THEN CUR$ = RV$(RJ)
        NEXT RJ
        PROMPT$ = COLN$(CI) + " [" + CUR$ + "]: "
        GOSUB WB_PROMPT
        IF ANS$ = "@" THEN
            VV$ = ""
            CLEARED = 1
        ELSEIF ANS$ = "@@" THEN
            VV$ = "@"
        ELSEIF ANS$ = "" THEN
            VV$ = CUR$
        ELSE
            VV$ = TRIM$(ANS$)
        END IF
        V$ = VV$
        GOSUB WB_VALVAL
        IF VBAD = 1 THEN
            ERR$ = "BAD VALUE"
            GOSUB WB_ERR
            RETURN
        END IF
        IF CI > 1 THEN VALS$ = VALS$ + ","
        VALS$ = VALS$ + VV$
    NEXT CI
    GOSUB WB_UPDATEROW
    IF UERRLY = 1 THEN RETURN
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    IF CLEARED = 1 THEN
        STATUS$ = "Cleared"
    ELSE
        STATUS$ = "Updated"
    END IF
    RETURN


REM ==============================================================
REM  Delete one row
REM ==============================================================
SCR_DELETE:
    RK$ = ROWKEYS$(SELROW)
    PROMPT$ = "Delete row " + TRIM$(STR$(SELROW))
    GOSUB WB_YES
    IF YESNO = 0 THEN RETURN
    GOSUB WB_DELETEROW
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
        RETURN
    END IF
    STATUS$ = "Deleted"
    RNEED = 1
    RETURN

REM ==============================================================
REM  Database map
REM ==============================================================
SCR_MAP:
    IF TLOADED = 0 THEN
        GOSUB WB_LOADTABLES
        TLOADED = 1
    END IF
    IF LLOADED = 0 THEN
        GOSUB WB_LOADLINKS
        LLOADED = 1
    END IF
    GOSUB WB_MAPLINES
    MPAGE = 1
    MOREM = 1
    WHILE MOREM = 1
        GOSUB WB_CLS
        TITLE$ = "MiniSQL Workbench"
        FOOT$ = "N=next  P=prev  R=refresh  B=back"
        GOSUB WB_HEADER
        MP1 = (MPAGE - 1) * 18 + 1
        MP2 = MP1 + 17
        IF MP2 > MAPN THEN MP2 = MAPN
        FOR MI = MP1 TO MP2
            TEXT$ = MAPL$(MI)
            GOSUB WB_LINE
        NEXT MI
        GOSUB WB_FOOTER
        PROMPT$ = "Selection: "
        GOSUB WB_PROMPT
        IF UCASE$(ANS$) = "B" OR UCASE$(ANS$) = "Q" THEN
            MOREM = 0
        ELSEIF UCASE$(ANS$) = "N" THEN
            IF MP2 < MAPN THEN MPAGE = MPAGE + 1
        ELSEIF UCASE$(ANS$) = "P" THEN
            IF MPAGE > 1 THEN MPAGE = MPAGE - 1
        ELSEIF UCASE$(ANS$) = "R" THEN
            TLOADED = 0
            LLOADED = 0
            GOSUB WB_LOADTABLES
            TLOADED = 1
            GOSUB WB_LOADLINKS
            LLOADED = 1
            GOSUB WB_MAPLINES
            MPAGE = 1
        ELSE
            ERR$ = "UNKNOWN SELECTION"
            GOSUB WB_ERR
        END IF
        X = SLEEP(0.1)
    WEND
    SCREEN = 2
    RETURN

REM ==============================================================
REM  SQL console
REM ==============================================================
WB_SHOWDESC:
    GOSUB WB_PARSEDESC
    PRINT "TBL="; DTBL$
    PRINT "COLS="; DCOLS$
    PRINT "PK="; DPK$
    RETURN

WB_SHOWRESULT:
    GOSUB WB_SPLIT
    SL = 0
    FOR SI = 1 TO RESN
        PRINT RESL$(SI)
        SL = SL + 1
        IF SL >= 20 THEN
            INPUT "Press ENTER...", X$
            SL = 0
        END IF
    NEXT SI
    RETURN

SCR_SQL:
    MORES = 1
    WHILE MORES = 1
        GOSUB WB_CLS
        TITLE$ = "MiniSQL Workbench"
        FOOT$ = "Empty or B = back"
        GOSUB WB_HEADER
        TEXT$ = "  DB: " + DB$
        GOSUB WB_LINE
        TEXT$ = "  SQL console"
        GOSUB WB_LINE
        TEXT$ = ""
        GOSUB WB_LINE
        GOSUB WB_FOOTER
        PROMPT$ = "SQL> "
        GOSUB WB_PROMPT
        IF ANS$ = "" OR UCASE$(ANS$) = "B" THEN
            MORES = 0
        ELSE
            SQL_STMT$ = ANS$
            U$ = UCASE$(ANS$)
            RESV = 0
            IF INSTR(U$, "ZZLINKS") > 0 THEN RESV = 1
            IF INSTR(U$, "_SCHEMA_META") > 0 THEN RESV = 1
            IF RESV = 1 THEN
                PRINT "RESERVED" COLOR RED
                INPUT "Press ENTER...", X$
            ELSE
                GOSUB WB_EXEC
                PRINT "STATUS: "; SQL_STATUS
                PRINT SQL_MSG$
                IF SQL_STATUS = 0 THEN
                    IF LEFT$(SQL_RESULT$, 6) = "COUNT=" THEN
                        PRINT SQL_RESULT$
                    ELSEIF LEFT$(SQL_RESULT$, 4) = "TBL=" THEN
                        GOSUB WB_SHOWDESC
                    ELSEIF SQL_RESULT$ <> "" THEN
                        GOSUB WB_SHOWRESULT
                    END IF
                    TLOADED = 0
                    LLOADED = 0
                    RNEED = 1
                END IF
                INPUT "Press ENTER...", X$
            END IF
        END IF
        X = SLEEP(0.1)
    WEND
    SCREEN = 2
    RETURN

REM ==============================================================
REM  Sample SHOP seed
REM ==============================================================
SCR_SEED:
    DB$ = "SHOP"
    GOSUB WB_VALDB
    IF DBBAD = 1 THEN
        GOSUB WB_ERR
        SCREEN = 1
        RETURN
    END IF
    GOSUB WB_OPENDB
    IF SQL_STATUS <> 0 THEN
        SCREEN = 1
        RETURN
    END IF
    X = SLEEP(0.25)
    TLOADED = 0
    GOSUB WB_LOADTABLES
    TLOADED = 1
    X = SLEEP(0.25)
    IF TBNT > 0 THEN
        PROMPT$ = "SHOP exists - merge sample?"
        GOSUB WB_YES
        IF YESNO = 0 THEN
            SCREEN = 2
            RETURN
        END IF
    END IF
    LLOADED = 0
    GOSUB WB_LOADLINKS
    LLOADED = 1
    X = SLEEP(0.25)
    GOSUB WB_SEEDBATCH
    IF SQL_STATUS <> 0 THEN
        ERR$ = SQL_MSG$
        GOSUB WB_ERR
    ELSE
        STATUS$ = "Sample seeded"
    END IF
    TLOADED = 0
    LLOADED = 0
    SCREEN = 2
    RETURN

REM ==============================================================
REM  Help and limits
REM ==============================================================
SCR_HELP:
    GOSUB WB_CLS
    TITLE$ = "MiniSQL Workbench"
    FOOT$ = "Press ENTER to return"
    GOSUB WB_HEADER
    TEXT$ = "  Limits:"
    GOSUB WB_LINE
    TEXT$ = "   50 tables, 40 columns per table, 30 links"
    GOSUB WB_LINE
    TEXT$ = "   values <=120 chars; statements <=1800 chars"
    GOSUB WB_LINE
    TEXT$ = "   row pages = 15"
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    TEXT$ = "  Values reject comma, pipe, right paren."
    GOSUB WB_LINE
    TEXT$ = "  Names: letters/digits/-/_ only; no LIMIT."
    GOSUB WB_LINE
    TEXT$ = "  Edit: empty keeps, @ clears, @@ is @."
    GOSUB WB_LINE
    TEXT$ = "  Links are design notes; MiniSQL does not enforce."
    GOSUB WB_LINE
    TEXT$ = ""
    GOSUB WB_LINE
    GOSUB WB_FOOTER
    INPUT "Press ENTER...", X$
    RETURN

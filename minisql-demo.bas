REM ==============================================================
REM  minisql-demo.bas  —  Interactive MiniSQL demo with sample data
REM ==============================================================
REM  RUN this program directly to explore MiniSQL features.
REM  Pre-populates a demo employee database and provides a menu
REM  to exercise CREATE, INSERT, SELECT, UPDATE, DELETE, REPLACE,
REM  COUNT, DISTINCT, ORDER BY, WHERE, LIKE, SEARCH, SHOW,
REM  DESCRIBE, ALTER, DROP, and TRANSACTIONS.
REM ==============================================================
START:
    COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
    COMMON SQL_STATUS, SQL_MSG$

    GOSUB InitDemo

MainMenu:
    CLS
    PRINT "========================================"
    PRINT "  MiniSQL Interactive Demo"
    PRINT "========================================"
    PRINT
    PRINT "  1.  SELECT all employees"
    PRINT "  2.  SELECT with column filter"
    PRINT "  3.  SELECT with ORDER BY"
    PRINT "  4.  SELECT DISTINCT"
    PRINT "  5.  SELECT with COUNT(*)"
    PRINT "  6.  SELECT with WHERE (exact)"
    PRINT "  7.  SELECT with WHERE (comparison)"
    PRINT "  8.  SELECT with WHERE LIKE"
    PRINT "  9.  SELECT with AND / OR"
    PRINT " 10.  INSERT new employee"
    PRINT " 11.  UPDATE employee (by KEY)"
    PRINT " 12.  UPDATE employees (bulk WHERE)"
    PRINT " 13.  DELETE employee (by KEY)"
    PRINT " 14.  DELETE employees (bulk WHERE)"
    PRINT " 15.  REPLACE employee"
    PRINT " 16.  SEARCH employees"
    PRINT " 17.  SHOW TABLES"
    PRINT " 18.  DESCRIBE employees"
    PRINT " 19.  ALTER TABLE (ADD / DROP col)"
    PRINT " 20.  Transaction demo (BEGIN/COMMIT)"
    PRINT " 21.  DROP demo table + recreate"
    PRINT
    PRINT " 99.  Exit"
    PRINT
    INPUT "Choice: ", CH

    IF CH = 99 THEN GOTO DemoExit

    SELECT CASE CH
        CASE 1:  GOSUB SelAll
        CASE 2:  GOSUB SelCols
        CASE 3:  GOSUB SelOrder
        CASE 4:  GOSUB SelDistinct
        CASE 5:  GOSUB SelCount
        CASE 6:  GOSUB SelWhereEx
        CASE 7:  GOSUB SelWhereComp
        CASE 8:  GOSUB SelWhereLike
        CASE 9:  GOSUB SelAndOr
        CASE 10: GOSUB DoInsert
        CASE 11: GOSUB DoUpdateKey
        CASE 12: GOSUB DoUpdateBulk
        CASE 13: GOSUB DoDeleteKey
        CASE 14: GOSUB DoDeleteBulk
        CASE 15: GOSUB DoReplace
        CASE 16: GOSUB DoSearch
        CASE 17: GOSUB DoShowTbl
        CASE 18: GOSUB DoDescribe
        CASE 19: GOSUB DoAlterDemo
        CASE 20: GOSUB DoTxnDemo
        CASE 21: GOSUB DoDropDemo
    END SELECT

    PRINT
    INPUT "Press ENTER to continue...", X$
    GOTO MainMenu

DemoExit:
    CLS
    PRINT "Goodbye!"
    END


REM ==============================================================
REM  Initialize demo database and populate sample data
REM ==============================================================
InitDemo:
    SQL_DB$ = "DEMODB"
    SQL_MODE$ = "RW"

    SQL_CMD$ = "INITDB"
    CHAIN "minisql.bas"

    SQL_CMD$ = "EXEC"

    SQL_STMT$ = "CREATE TABLE employees"
    SQL_STMT$ = SQL_STMT$ + " (name,title,dept,salary,loc) PK KEY"
    CHAIN "minisql.bas"

    SQL_STMT$ = "INSERT INTO employees KEY e01"
    SQL_STMT$ = SQL_STMT$ + " VALUES (Alice,Engineer,Eng"
    SQL_STMT$ = SQL_STMT$ + ",85000,Chicago)"
    CHAIN "minisql.bas"
    SQL_STMT$ = "INSERT INTO employees KEY e02"
    SQL_STMT$ = SQL_STMT$ + " VALUES (Bob,Manager,Sales"
    SQL_STMT$ = SQL_STMT$ + ",95000,Boston)"
    CHAIN "minisql.bas"
    SQL_STMT$ = "INSERT INTO employees KEY e03"
    SQL_STMT$ = SQL_STMT$ + " VALUES (Carol,Director,Eng"
    SQL_STMT$ = SQL_STMT$ + ",120000,Chicago)"
    CHAIN "minisql.bas"
    SQL_STMT$ = "INSERT INTO employees KEY e04"
    SQL_STMT$ = SQL_STMT$ + " VALUES (Dave,Engineer,Eng"
    SQL_STMT$ = SQL_STMT$ + ",88000,Austin)"
    CHAIN "minisql.bas"
    SQL_STMT$ = "INSERT INTO employees KEY e05"
    SQL_STMT$ = SQL_STMT$ + " VALUES (Eve,Manager,HR"
    SQL_STMT$ = SQL_STMT$ + ",92000,Chicago)"
    CHAIN "minisql.bas"
    SQL_STMT$ = "INSERT INTO employees KEY e06"
    SQL_STMT$ = SQL_STMT$ + " VALUES (Frank,Analyst,Sales"
    SQL_STMT$ = SQL_STMT$ + ",78000,Boston)"
    CHAIN "minisql.bas"
    SQL_STMT$ = "INSERT INTO employees KEY e07"
    SQL_STMT$ = SQL_STMT$ + " VALUES (Grace,Engineer,Eng"
    SQL_STMT$ = SQL_STMT$ + ",86000,Denver)"
    CHAIN "minisql.bas"
    SQL_STMT$ = "INSERT INTO employees KEY e08"
    SQL_STMT$ = SQL_STMT$ + " VALUES (Hank,Director,HR"
    SQL_STMT$ = SQL_STMT$ + ",115000,Austin)"
    CHAIN "minisql.bas"

    RETURN


REM ==============================================================
REM  Display SQL_RESULT$ nicely
REM ==============================================================
ShowResult:
    IF SQL_STATUS <> 0 THEN
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
        RETURN
    END IF
    IF SQL_RESULT$ = "" THEN
        PRINT SQL_MSG$
        RETURN
    END IF
    GOSUB ParseResult
    RETURN

ParseResult:
    RR$ = SQL_RESULT$
    IF LEFT$(RR$, 6) = "COUNT=" THEN
        PRINT "Count: "; MID$(RR$, 7)
        RETURN
    END IF
    IF LEFT$(RR$, 4) = "TBL=" THEN
        PRINT "Table: "; MID$(RR$, 4, INSTR(RR$+CHR$(10),CHR$(10))-1)
        P2 = INSTR(RR$, CHR$(10))
        IF P2 > 0 THEN
            RP$ = MID$(RR$, P2+1)
            PRINT RP$
        END IF
        RETURN
    END IF

    RI = 1
    WHILE 1
        S$ = RR$: D$ = CHR$(10): N = RI: GOSUB GetToken
        ROWL$ = GETD$
        IF ROWL$ = "" THEN EXIT WHILE
        IF LEFT$(ROWL$, 2) = "R|" THEN GOSUB ShowRow
        IF LEFT$(ROWL$, 2) <> "R|" THEN PRINT ROWL$
        RI = RI + 1
        IF (RI MOD 25) = 0 THEN X = SLEEP(0.05)
    WEND
    RETURN

ShowRow:
    RC$ = MID$(ROWL$, 3)
    P1 = INSTR(RC$, "|")
    IF P1 = 0 THEN PRINT RC$: RETURN
    PKN$ = LEFT$(RC$, P1-1)
    PKV$ = MID$(RC$, P1+1)
    P2 = INSTR(PKV$, "|")
    IF P2 = 0 THEN
        PRINT PKN$; "="; PKV$
        RETURN
    END IF
    PRINT PKN$; "="; LEFT$(PKV$, P2-1)
    RST$ = MID$(PKV$, P2+1)
    WHILE RST$ <> ""
        P3 = INSTR(RST$, "|")
        IF P3 = 0 THEN
            PRINT "  "; RST$
            RST$ = ""
        ELSE
            PRINT "  "; LEFT$(RST$, P3-1)
            RST$ = MID$(RST$, P3+1)
        END IF
        IF LEN(RST$) > 1000 THEN X = SLEEP(0.05)
    WEND
    PRINT
    RETURN


REM ==============================================================
REM  Menu handlers
REM ==============================================================
SelAll:
    PRINT
    PRINT "--- SELECT * FROM employees ---"
    SQL_STMT$ = "SELECT * FROM employees"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

SelCols:
    PRINT
    PRINT "--- SELECT name,title,dept ---"
    SQL_STMT$ = "SELECT name,title,dept FROM employees"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

SelOrder:
    PRINT
    INPUT "Order by (name/salary/dept) [name]: ", OB$
    IF OB$ = "" THEN OB$ = "name"
    PRINT
    INPUT "Direction (ASC/DESC) [ASC]: ", OD$
    IF OD$ = "" THEN OD$ = "ASC"
    PRINT
    PRINT "--- SELECT * ORDER BY "; OB$; " "; OD$; " ---"
    SQL_STMT$ = "SELECT * FROM employees ORDER BY " + OB$
    SQL_STMT$ = SQL_STMT$ + " " + OD$
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

SelDistinct:
    PRINT
    PRINT "--- SELECT DISTINCT dept ---"
    SQL_STMT$ = "SELECT DISTINCT dept FROM employees"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    PRINT
    PRINT "--- SELECT DISTINCT title ---"
    SQL_STMT$ = "SELECT DISTINCT title FROM employees"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

SelCount:
    PRINT
    PRINT "--- SELECT COUNT(*) ---"
    SQL_STMT$ = "SELECT COUNT(*) FROM employees"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    PRINT
    PRINT "--- SELECT COUNT(*) WHERE dept=Eng ---"
    SQL_STMT$ = "SELECT COUNT(*) FROM employees WHERE dept=Eng"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

SelWhereEx:
    PRINT
    INPUT "Column [dept]: ", WC$
    IF WC$ = "" THEN WC$ = "dept"
    INPUT "Value [Eng]: ", WV$
    IF WV$ = "" THEN WV$ = "Eng"
    PRINT
    PRINT "--- SELECT * WHERE "; WC$; "="; WV$; " ---"
    SQL_STMT$ = "SELECT * FROM employees WHERE " + WC$
    SQL_STMT$ = SQL_STMT$ + "=" + WV$
    CHAIN "minisql.bas"
    GOSUB ShowResult
    PRINT
    PRINT "--- SELECT name,title WHERE "; WC$; "="; WV$; " ---"
    SQL_STMT$ = "SELECT name,title FROM employees WHERE " + WC$
    SQL_STMT$ = SQL_STMT$ + "=" + WV$
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

SelWhereComp:
    PRINT
    PRINT "Comparison operators: =  <>  <  >  <=  >="
    INPUT "Column [salary]: ", WC$
    IF WC$ = "" THEN WC$ = "salary"
    INPUT "Operator [>]: ", OP$
    IF OP$ = "" THEN OP$ = ">"
    INPUT "Value [85000]: ", WV$
    IF WV$ = "" THEN WV$ = "85000"
    PRINT
    PRINT "--- SELECT name,"; WC$; " WHERE "; WC$; OP$; WV$; " ---"
    SQL_STMT$ = "SELECT name," + WC$ + " FROM employees WHERE "
    SQL_STMT$ = SQL_STMT$ + WC$ + OP$ + WV$
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

SelWhereLike:
    PRINT
    PRINT "LIKE patterns: %text% (contains),";
    PRINT " text% (prefix), %text (suffix)"
    INPUT "Column [name]: ", WC$
    IF WC$ = "" THEN WC$ = "name"
    INPUT "Pattern [%i%]: ", WP$
    IF WP$ = "" THEN WP$ = "%i%"
    PRINT
    PRINT "--- SELECT * WHERE "; WC$; " LIKE "; WP$; " ---"
    SQL_STMT$ = "SELECT * FROM employees WHERE " + WC$
    SQL_STMT$ = SQL_STMT$ + " LIKE " + WP$
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

SelAndOr:
    PRINT
    PRINT "--- SELECT * WHERE dept=Eng AND salary>85000 ---"
    SQL_STMT$ = "SELECT name,dept,salary FROM employees"
    SQL_STMT$ = SQL_STMT$ + " WHERE dept=Eng AND salary>=85000"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    PRINT
    PRINT "--- SELECT * WHERE dept=Eng OR dept=HR ---"
    SQL_STMT$ = "SELECT name,title,dept FROM employees"
    SQL_STMT$ = SQL_STMT$ + " WHERE dept=Eng OR dept=HR"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

DoInsert:
    PRINT
    INPUT "Key (e.g. e09): ", IK$
    IF IK$ = "" THEN RETURN
    INPUT "Name: ", IN$
    INPUT "Title: ", IT$
    INPUT "Dept: ", ID$
    INPUT "Salary: ", IS$
    INPUT "Location: ", IL$
    SQL_STMT$ = "INSERT INTO employees KEY " + IK$
    SQL_STMT$ = SQL_STMT$ + " VALUES ("
    SQL_STMT$ = SQL_STMT$ + IN$ + "," + IT$ + "," + ID$
    SQL_STMT$ = SQL_STMT$ + "," + IS$ + "," + IL$ + ")"
    PRINT
    PRINT "--- "; SQL_STMT$; " ---"
    CHAIN "minisql.bas"
    IF SQL_STATUS = 0 THEN
        PRINT SQL_MSG$
    ELSE
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
    END IF
    RETURN

DoUpdateKey:
    PRINT
    INPUT "Key to update [e01]: ", UK$
    IF UK$ = "" THEN UK$ = "e01"
    INPUT "Column to set [title]: ", UC$
    IF UC$ = "" THEN UC$ = "title"
    INPUT "New value [Sr.Engineer]: ", UV$
    IF UV$ = "" THEN UV$ = "Sr.Engineer"
    SQL_STMT$ = "UPDATE employees KEY " + UK$
    SQL_STMT$ = SQL_STMT$ + " SET " + UC$ + "=" + UV$
    PRINT
    PRINT "--- "; SQL_STMT$; " ---"
    CHAIN "minisql.bas"
    IF SQL_STATUS = 0 THEN
        PRINT SQL_MSG$
        PRINT
        PRINT "Verify:"
        SQL_STMT$ = "SELECT * FROM employees WHERE KEY=" + UK$
        CHAIN "minisql.bas"
        GOSUB ShowResult
    ELSE
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
    END IF
    RETURN

DoUpdateBulk:
    PRINT
    INPUT "WHERE column [dept]: ", WC$
    IF WC$ = "" THEN WC$ = "dept"
    INPUT "WHERE value [Eng]: ", WV$
    IF WV$ = "" THEN WV$ = "Eng"
    INPUT "SET column [salary]: ", SC$
    IF SC$ = "" THEN SC$ = "salary"
    INPUT "SET value [90000]: ", SV$
    IF SV$ = "" THEN SV$ = "90000"
    SQL_STMT$ = "UPDATE employees SET " + SC$ + "=" + SV$
    SQL_STMT$ = SQL_STMT$ + " WHERE " + WC$ + "=" + WV$
    PRINT
    PRINT "--- "; SQL_STMT$; " ---"
    CHAIN "minisql.bas"
    IF SQL_STATUS = 0 THEN
        PRINT SQL_MSG$
        PRINT
        PRINT "Verify: SELECT name,"; SC$; " FROM employees"
        PRINT "        WHERE "; WC$; "="; WV$
        SQL_STMT$ = "SELECT name," + SC$ + " FROM employees"
        SQL_STMT$ = SQL_STMT$ + " WHERE " + WC$ + "=" + WV$
        CHAIN "minisql.bas"
        GOSUB ShowResult
    ELSE
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
    END IF
    RETURN

DoDeleteKey:
    PRINT
    PRINT "WARNING: Enter key of most recently inserted record"
    INPUT "Key to delete: ", DK$
    IF DK$ = "" THEN RETURN
    SQL_STMT$ = "DELETE FROM employees KEY " + DK$
    PRINT
    PRINT "--- "; SQL_STMT$; " ---"
    CHAIN "minisql.bas"
    IF SQL_STATUS = 0 THEN
        PRINT SQL_MSG$
    ELSE
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
    END IF
    RETURN

DoDeleteBulk:
    PRINT
    INPUT "WHERE column [dept]: ", WC$
    IF WC$ = "" THEN WC$ = "dept"
    INPUT "WHERE value [HR]: ", WV$
    IF WV$ = "" THEN WV$ = "HR"
    SQL_STMT$ = "DELETE FROM employees WHERE " + WC$
    SQL_STMT$ = SQL_STMT$ + "=" + WV$
    PRINT
    PRINT "--- "; SQL_STMT$; " ---"
    CHAIN "minisql.bas"
    IF SQL_STATUS = 0 THEN
        PRINT SQL_MSG$
        PRINT
        PRINT "Verify: SELECT COUNT(*) FROM employees"
        SQL_STMT$ = "SELECT COUNT(*) FROM employees"
        CHAIN "minisql.bas"
        GOSUB ShowResult
    ELSE
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
    END IF
    RETURN

DoReplace:
    PRINT
    INPUT "Key to replace [e01]: ", RK$
    IF RK$ = "" THEN RK$ = "e01"
    INPUT "New name: ", RN$
    INPUT "New title: ", RT$
    INPUT "New dept: ", RD$
    INPUT "New salary: ", RS$
    INPUT "New location: ", RL$
    SQL_STMT$ = "REPLACE employees KEY " + RK$
    SQL_STMT$ = SQL_STMT$ + " VALUES ("
    SQL_STMT$ = SQL_STMT$ + RN$ + "," + RT$ + "," + RD$
    SQL_STMT$ = SQL_STMT$ + "," + RS$ + "," + RL$ + ")"
    PRINT
    PRINT "--- "; SQL_STMT$; " ---"
    CHAIN "minisql.bas"
    IF SQL_STATUS = 0 THEN
        PRINT SQL_MSG$
        PRINT
        PRINT "Verify:"
        SQL_STMT$ = "SELECT * FROM employees WHERE KEY=" + RK$
        CHAIN "minisql.bas"
        GOSUB ShowResult
    ELSE
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
    END IF
    RETURN

DoSearch:
    PRINT
    PRINT "Search modes: CONTAINS, EXACT, PREFIX, SUFFIX"
    INPUT "Search term: ", ST$
    IF ST$ = "" THEN RETURN
    INPUT "Search in column (blank=all) [name]: ", SC$
    IF SC$ = "" THEN SC$ = "name"
    INPUT "Search mode [CONTAINS]: ", SM$
    IF SM$ = "" THEN SM$ = "CONTAINS"
    SQL_CMD$ = "SEARCH"
    SQL_STMT$ = "employees|" + ST$ + "|" + SC$ + "|" + SM$
    PRINT
    PRINT "--- SEARCH employees for '"; ST$; "' ---"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    SQL_CMD$ = "EXEC"
    RETURN

DoShowTbl:
    PRINT
    PRINT "--- SHOW TABLES ---"
    SQL_STMT$ = "SHOW TABLES"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

DoDescribe:
    PRINT
    PRINT "--- DESCRIBE employees ---"
    SQL_STMT$ = "DESCRIBE employees"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

DoAlterDemo:
    PRINT
    PRINT "--- ALTER TABLE employees ADD phone ---"
    SQL_STMT$ = "ALTER TABLE employees ADD phone"
    CHAIN "minisql.bas"
    IF SQL_STATUS = 0 THEN
        PRINT SQL_MSG$
    ELSE
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
    END IF
    PRINT
    PRINT "--- DESCRIBE employees (verify ADD) ---"
    SQL_STMT$ = "DESCRIBE employees"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    PRINT
    PRINT "--- ALTER TABLE employees DROP phone ---"
    SQL_STMT$ = "ALTER TABLE employees DROP phone"
    CHAIN "minisql.bas"
    IF SQL_STATUS = 0 THEN
        PRINT SQL_MSG$
    ELSE
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
    END IF
    RETURN

DoTxnDemo:
    PRINT
    PRINT "--- BEGIN transaction ---"
    SQL_CMD$ = "BEGIN"
    CHAIN "minisql.bas"
    PRINT SQL_MSG$
    PRINT
    PRINT "--- Queue INSERT (will be deferred) ---"
    SQL_CMD$ = "EXEC"
    SQL_STMT$ = "INSERT INTO employees KEY tx1"
    SQL_STMT$ = SQL_STMT$ + " VALUES (TxnTest,Intern,Eng,50000,Dallas)"
    CHAIN "minisql.bas"
    PRINT SQL_MSG$
    PRINT
    PRINT "--- Queue UPDATE (will be deferred) ---"
    SQL_STMT$ = "UPDATE employees KEY tx1 SET title=Jr.Engineer"
    CHAIN "minisql.bas"
    PRINT SQL_MSG$
    PRINT
    PRINT "--- COMMIT transaction ---"
    SQL_CMD$ = "COMMIT"
    CHAIN "minisql.bas"
    PRINT SQL_MSG$
    SQL_CMD$ = "EXEC"
    PRINT
    PRINT "--- Verify: SELECT from tx1 ---"
    SQL_STMT$ = "SELECT * FROM employees WHERE KEY=tx1"
    CHAIN "minisql.bas"
    GOSUB ShowResult
    RETURN

DoDropDemo:
    PRINT
    PRINT "WARNING: This drops the demo table and recreates it."
    INPUT "Are you sure? (Y/N): ", YN$
    IF UCASE$(YN$) <> "Y" THEN RETURN
    PRINT
    PRINT "--- DROP TABLE employees ---"
    SQL_STMT$ = "DROP TABLE employees"
    CHAIN "minisql.bas"
    IF SQL_STATUS <> 0 THEN
        PRINT "ERROR "; SQL_STATUS; ": "; SQL_MSG$
        RETURN
    END IF
    PRINT SQL_MSG$
    PRINT
    PRINT "--- Recreate with fresh data ---"
    GOSUB InitDemo
    PRINT "Demo table recreated with sample data."
    RETURN


REM ==============================================================
REM  Token helper (copied from minisql.bas)
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
        X = SLEEP(0.05)
    WEND
    RETURN

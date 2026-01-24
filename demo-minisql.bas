REM ============================================================
REM  DEMO_SQL.BAS - Interactive demo for MINISQL.BAS
REM  Version: 0.2.0
REM ============================================================
REM Copyright 2025 by FARMER. ALL rights reserved

START:
  COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
  COMMON SQL_STATUS, SQL_MSG$

  SQL_DB$ = "TESTDB"
  SQL_MODE$ = "RW"
  SQL_RESULT$ = ""
  SQL_STATUS = 0
  SQL_MSG$ = ""

MAIN:
  PRINT
  PRINT "==============================="
  PRINT " MiniSQL Demo (Interactive)"
  PRINT "==============================="
  PRINT "DB  : "; SQL_DB$
  PRINT "Mode: "; SQL_MODE$
  PRINT
  PRINT "1) INITDB"
  PRINT "2) Set DB"
  PRINT "3) Set Mode (RW/RO/AO)"
  PRINT "4) CREATE TABLE (guided)"
  PRINT "5) INSERT (guided)"
  PRINT "6) SELECT (guided)"
  PRINT "7) UPDATE (guided)"
  PRINT "8) REPLACE (guided)"
  PRINT "9) DELETE (guided)"
  PRINT "A) SEARCH (guided)"
  PRINT "B) BEGIN txn"
  PRINT "C) COMMIT txn"
  PRINT "D) ROLLBACK txn"
  PRINT "E) COMPACT idx"
  PRINT "F) REINDEX idx"
  PRINT "G) EXEC raw SQL"
  PRINT "Q) Quit"
  PRINT
  INPUT "Choose: ", CH$

  CH$ = UCASE$(TRIM$(CH$))
  IF CH$="1" THEN GOSUB DO_INIT: GOTO MAIN
  IF CH$="2" THEN GOSUB DO_DB:   GOTO MAIN
  IF CH$="3" THEN GOSUB DO_MODE: GOTO MAIN
  IF CH$="4" THEN GOSUB DO_CRT:  GOTO MAIN
  IF CH$="5" THEN GOSUB DO_INS:  GOTO MAIN
  IF CH$="6" THEN GOSUB DO_SEL:  GOTO MAIN
  IF CH$="7" THEN GOSUB DO_UPD:  GOTO MAIN
  IF CH$="8" THEN GOSUB DO_REP:  GOTO MAIN
  IF CH$="9" THEN GOSUB DO_DEL:  GOTO MAIN
  IF CH$="A" THEN GOSUB DO_SCH:  GOTO MAIN
  IF CH$="B" THEN GOSUB DO_BEG:  GOTO MAIN
  IF CH$="C" THEN GOSUB DO_COM:  GOTO MAIN
  IF CH$="D" THEN GOSUB DO_ROL:  GOTO MAIN
  IF CH$="E" THEN GOSUB DO_CMP:  GOTO MAIN
  IF CH$="F" THEN GOSUB DO_RIX:  GOTO MAIN
  IF CH$="G" THEN GOSUB DO_RAW:  GOTO MAIN
  IF CH$="Q" THEN END

  PRINT "Unknown choice."
  GOSUB PAUSE
  GOTO MAIN


REM -------------------------
REM Call minisql + show output
REM -------------------------
CALL_SQL:
  SQL_STATUS = 0
  SQL_MSG$ = ""
  SQL_RESULT$ = ""

  CHAIN "minisql"

  PRINT
  PRINT "---- minisql returned ----"
  PRINT "STATUS: "; SQL_STATUS
  PRINT "MSG   : "; SQL_MSG$
  IF SQL_RESULT$<>"" THEN
    PRINT "RESULT:"
    GOSUB PRINT_RES
  ELSE
    PRINT "(no result text)"
  END IF
  PRINT "--------------------------"
  GOSUB PAUSE
  RETURN


REM -------------------------
REM Pause helper
REM -------------------------
PAUSE:
  INPUT "Press ENTER...", D$
  RETURN


REM -------------------------
REM Print SQL_RESULT$ line by line
REM -------------------------
PRINT_RES:
  S$ = SQL_RESULT$
  P = 1
PR_LOOP:
  N = INSTR(MID$(S$, P), CHR$(10))
  IF N=0 THEN
    L$ = MID$(S$, P)
    IF TRIM$(L$)<>"" THEN PRINT L$
    RETURN
  END IF
  L$ = MID$(S$, P, N-1)
  IF TRIM$(L$)<>"" THEN PRINT L$
  P = P + N
  GOTO PR_LOOP


REM -------------------------
REM Menu actions
REM -------------------------
DO_INIT:
  SQL_CMD$ = "INITDB"
  SQL_STMT$ = ""
  GOSUB CALL_SQL
  RETURN

DO_DB:
  INPUT "DB prefix: ", SQL_DB$
  SQL_DB$ = TRIM$(SQL_DB$)
  IF SQL_DB$="" THEN SQL_DB$="TESTDB"
  PRINT "DB set to "; SQL_DB$
  GOSUB PAUSE
  RETURN

DO_MODE:
  PRINT "Modes: RW=read/write  RO=select only  AO=insert only"
  INPUT "Mode: ", M$
  M$ = UCASE$(TRIM$(M$))
  IF M$<>"RW" AND M$<>"RO" AND M$<>"AO" THEN
    PRINT "Invalid, keeping "; SQL_MODE$
  ELSE
    SQL_MODE$ = M$
    PRINT "Mode set to "; SQL_MODE$
  END IF
  GOSUB PAUSE
  RETURN

DO_CRT:
  PRINT "CREATE TABLE"
  INPUT "Table: ", T$
  INPUT "Cols (a,b,c): ", C$
  INPUT "PK name (KEY): ", PK$
  T$=TRIM$(T$): C$=TRIM$(C$): PK$=TRIM$(PK$)
  IF PK$="" THEN PK$="KEY"
  SQL_CMD$="EXEC"
  SQL_STMT$="CREATE TABLE " + T$ + " (" + C$ + ")"
  SQL_STMT$=SQL_STMT$ + " PK " + PK$
  GOSUB CALL_SQL
  RETURN

DO_INS:
  PRINT "INSERT"
  INPUT "Table: ", T$
  INPUT "Key: ", K$
  INPUT "Values (v1,v2): ", V$
  T$=TRIM$(T$): K$=TRIM$(K$): V$=TRIM$(V$)
  SQL_CMD$="EXEC"
  SQL_STMT$="INSERT INTO " + T$ + " KEY " + K$
  SQL_STMT$=SQL_STMT$ + " VALUES (" + V$ + ")"
  GOSUB CALL_SQL
  RETURN

DO_SEL:
  PRINT "SELECT"
  INPUT "Table: ", T$
  INPUT "WHERE (blank ok): ", W$
  INPUT "LIMIT (blank ok): ", LIM$
  T$=TRIM$(T$): W$=TRIM$(W$): LIM$=TRIM$(LIM$)
  SQL_CMD$="EXEC"
  SQL_STMT$="SELECT * FROM " + T$
  IF W$<>"" THEN SQL_STMT$=SQL_STMT$ + " WHERE " + W$
  IF LIM$<>"" THEN SQL_STMT$=SQL_STMT$ + " LIMIT " + LIM$
  GOSUB CALL_SQL
  RETURN

DO_UPD:
  PRINT "UPDATE"
  INPUT "Table: ", T$
  INPUT "Key: ", K$
  INPUT "SET col=val: ", S$
  T$=TRIM$(T$): K$=TRIM$(K$): S$=TRIM$(S$)
  SQL_CMD$="EXEC"
  SQL_STMT$="UPDATE " + T$ + " KEY " + K$ + " SET " + S$
  GOSUB CALL_SQL
  RETURN

DO_REP:
  PRINT "REPLACE"
  INPUT "Table: ", T$
  INPUT "Key: ", K$
  INPUT "Values (v1,v2): ", V$
  T$=TRIM$(T$): K$=TRIM$(K$): V$=TRIM$(V$)
  SQL_CMD$="EXEC"
  SQL_STMT$="REPLACE " + T$ + " KEY " + K$
  SQL_STMT$=SQL_STMT$ + " VALUES (" + V$ + ")"
  GOSUB CALL_SQL
  RETURN

DO_DEL:
  PRINT "DELETE"
  INPUT "Table: ", T$
  INPUT "Key: ", K$
  T$=TRIM$(T$): K$=TRIM$(K$)
  SQL_CMD$="EXEC"
  SQL_STMT$="DELETE FROM " + T$ + " KEY " + K$
  GOSUB CALL_SQL
  RETURN

DO_SCH:
  PRINT "SEARCH (table|term|col)"
  INPUT "Table: ", T$
  INPUT "Term: ", TERM$
  INPUT "Col (blank=any): ", COL$
  T$=TRIM$(T$): TERM$=TRIM$(TERM$): COL$=TRIM$(COL$)
  SQL_CMD$="SEARCH"
  SQL_STMT$=T$ + "|" + TERM$ + "|" + COL$
  GOSUB CALL_SQL
  RETURN

DO_BEG:
  SQL_CMD$="BEGIN"
  SQL_STMT$=""
  GOSUB CALL_SQL
  RETURN

DO_COM:
  SQL_CMD$="COMMIT"
  SQL_STMT$=""
  GOSUB CALL_SQL
  RETURN

DO_ROL:
  SQL_CMD$="ROLLBACK"
  SQL_STMT$=""
  GOSUB CALL_SQL
  RETURN

DO_CMP:
  SQL_CMD$="COMPACT"
  SQL_STMT$=""
  GOSUB CALL_SQL
  RETURN

DO_RIX:
  SQL_CMD$="REINDEX"
  SQL_STMT$=""
  GOSUB CALL_SQL
  RETURN

DO_RAW:
  PRINT "Raw SQL examples:"
  PRINT " CREATE TABLE t (a,b) PK KEY"
  PRINT " INSERT INTO t KEY k VALUES (1,2)"
  PRINT " SELECT * FROM t WHERE a=1 LIMIT 5"
  PRINT " UPDATE t KEY k SET a=9"
  PRINT " REPLACE t KEY k VALUES (9,2)"
  PRINT " DELETE FROM t KEY k"
  INPUT "SQL> ", ST$
  SQL_CMD$="EXEC"
  SQL_STMT$=ST$
  GOSUB CALL_SQL
  RETURN

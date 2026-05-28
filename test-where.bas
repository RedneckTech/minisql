REM ==============================================================
REM  test_where.bas  —  Enhanced WHERE (AND/OR, comparisons, LIKE)
REM ==============================================================
COMMON SQL_CMD$, SQL_DB$, SQL_STMT$, SQL_MODE$, SQL_RESULT$
COMMON SQL_STATUS, SQL_MSG$

SQL_DB$ = "TESTSUITE"
SQL_MODE$ = "RW"
SQL_CMD$ = "EXEC"

SQL_STMT$ = "CREATE TABLE tst-whr (name,age,city) PK KEY"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "INSERT INTO tst-whr KEY r1 VALUES (Alice,25,Chicago)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-whr KEY r2 VALUES (Bob,30,Boston)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-whr KEY r3 VALUES (Carol,22,Chicago)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-whr KEY r4 VALUES (Dave,35,Denver)"
CHAIN "minisql.bas"
SQL_STMT$ = "INSERT INTO tst-whr KEY r5 VALUES (Eve,28,Austin)"
CHAIN "minisql.bas"

REM AND
SQL_STMT$ = "SELECT name FROM tst-whr"
SQL_STMT$ = SQL_STMT$ + " WHERE city=Chicago AND age>23"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM OR
SQL_STMT$ = "SELECT name FROM tst-whr"
SQL_STMT$ = SQL_STMT$ + " WHERE city=Chicago OR city=Denver"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM > and <
SQL_STMT$ = "SELECT name FROM tst-whr WHERE age>25"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "SELECT name FROM tst-whr WHERE age<26"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM >= and <=
SQL_STMT$ = "SELECT name FROM tst-whr WHERE age>=30"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STMT$ = "SELECT name FROM tst-whr WHERE age<=25"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM <>
SQL_STMT$ = "SELECT name FROM tst-whr WHERE city<>Chicago"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM LIKE (%text% - contains)
SQL_STMT$ = "SELECT name FROM tst-whr WHERE name LIKE %Al%"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM LIKE (text% - prefix)
SQL_STMT$ = "SELECT name FROM tst-whr WHERE city LIKE %Chi"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM LIKE (%text - suffix)
SQL_STMT$ = "SELECT name FROM tst-whr WHERE city LIKE %go"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

REM Combined AND + comparison
SQL_STMT$ = "SELECT name FROM tst-whr"
SQL_STMT$ = SQL_STMT$ + " WHERE age>=22 AND age<=30 AND city=Chicago"
CHAIN "minisql.bas"
IF SQL_STATUS <> 0 THEN END

SQL_STATUS = 0
SQL_MSG$ = "WHERE FEATURES OK"
END

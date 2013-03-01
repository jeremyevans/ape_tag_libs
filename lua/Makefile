CC=cc
CFLAGS=-g -Wall -I/usr/local/include
LDFLAGS=
LIBNAME=io_truncate
SOFILENAME=${LIBNAME}.so
RM=rm
LUA=lua

all:  ${SOFILENAME}

clean:
	${RM} -f ${SOFILENAME} ${LIBNAME}.o

regress: all
	${LUA} test_apetag.lua
	${LUA} test_apetag_files.lua

${SOFILENAME}: ${LIBNAME}.c
	${CC} ${CFLAGS} -c -fPIC ${LIBNAME}.c
	${CC} -shared -o ${SOFILENAME} ${LDFLAGS} ${LIBNAME}.o

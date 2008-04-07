CC=cc
CCOPTS=-g -Wall -I/usr/local/include
LDFLAGS=
LIBNAME=io_truncate
SOFILENAME=${LIBNAME}.so
RM=rm

all:  ${SOFILENAME}

clean:
	${RM} ${SOFILENAME} ${LIBNAME}.o

regress: all
	lua test_apetag.lua

${SOFILENAME}: ${LIBNAME}.c
	${CC} ${CCOPTS} -c -fPIC ${LIBNAME}.c
	${CC} -shared -o ${SOFILENAME} ${LDFLAGS} ${LIBNAME}.o

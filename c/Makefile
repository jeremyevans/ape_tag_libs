
MINORVERSION=0
MAJORVERSION=0
LIB=apetag
SONAME=lib${LIB}.so.${MAJORVERSION}
SOFILENAME=${SONAME}.${MINORVERSION}
ARFILENAME=lib${LIB}.a
APEINFO=apeinfo

AR=ar
AROPTS=rcs
CC=cc
CCOPTS=-g -Wall
LDFLAGS=
LINT=lint
LINTOPTS=-chrs
INSTALL=install
BASEDIR=/usr/local
LIBDIR=${BASEDIR}/lib
BINDIR=${BASEDIR}/bin
MANDIR=${BASEDIR}/man
INCDIR=${BASEDIR}/include

#This library tries to detect endianness, but defaults to little endian.
#If you know you need big endian:
#CCOPTS+=-DIS_BIG_ENDIAN

#If dbopen is in a different lib than libc (you'll need to specify this for
# other programs that link to the library as well)
#LDFLAGS=-ldb

#If dbopen is prototyped in db_185.h instead of db.h (you'll need to specify
# this for other programs that include apetag.h)
#CCOPTS+=-DUSE_DB_185

#If you want to enable some extra warnings
#CCOPTS+=-W -Wshadow -Wpointer-arith -Wcast-align -Wstrict-prototypes \
#        -Wsign-compare -Wmissing-prototypes -Wmissing-declarations \
#        -Wpadded -Wredundant-decls -Wunreachable-code -Wlong-long \
#        -Wundef -Wcast-qual -Waggregate-return \
#        -pedantic -ansi

all:  ${ARFILENAME} ${SOFILENAME} symlinks ${APEINFO}

clean:
	-rm -f apetag.o ${ARFILENAME} ${APEINFO} lib${LIB}.so* test/test_apetag

install: all install-symlinks
	${INSTALL} -o root -g bin -m 444 ${ARFILENAME} ${SOFILENAME} ${LIBDIR}
	${INSTALL} -o root -g bin -m 555 ${APEINFO} ${BINDIR}
	${INSTALL} -d ${MANDIR}/man1/ ${MANDIR}/man3/
	${INSTALL} -o root -g bin -m 444 apeinfo.1 ${MANDIR}/man1/
	${INSTALL} -o root -g bin -m 444 apetag.3 ${MANDIR}/man3/
	${INSTALL} -o root -g bin -m 444 apetag.h ${INCDIR}

install-symlinks:
	ln -fs ${SOFILENAME} ${LIBDIR}/lib${LIB}.so
	ln -fs ${SOFILENAME} ${LIBDIR}/${SONAME}

lint:
	${LINT} ${LINTOPTS} apetag.c
	${LINT} ${LINTOPTS} -I. apeinfo.c

regress: all test/test_apetag
	cd test && LD_LIBRARY_PATH=.. ./test_apetag

symlinks: lib${LIB}.so ${SONAME}

test/test_apetag:
	cd test && ${CC} ${CCOPTS} -I.. -L.. -l${LIB} ${LDFLAGS} \
	    -o test_apetag test_apetag.c

uninstall: uninstall-symlinks
	-rm ${LIBDIR}/${ARFILENAME} ${LIBDIR}/${SOFILENAME} \
	   ${BINDIR}/${APEINFO} ${MANDIR}/man1/apeinfo.1 \
	   ${MANDIR}/man3/apetag.3 ${INCDIR}/apetag.h
	   
uninstall-symlinks:
	-rm ${LIBDIR}/lib${LIB}.so ${LIBDIR}/${SONAME}

lib${LIB}.so:
	ln -s ${SOFILENAME} lib${LIB}.so
	
${SONAME}:
	ln -s ${SOFILENAME} ${SONAME}

${APEINFO}: apeinfo.c ${SOFILENAME}
	${CC} ${CCOPTS} -I. -L. -l${LIB} ${LDFLAGS} -o ${APEINFO} apeinfo.c

${ARFILENAME}: apetag.c apetag.h
	${CC} ${CCOPTS} -c apetag.c
	${AR} ${AROPTS} ${ARFILENAME} apetag.o

${SOFILENAME}: apetag.c apetag.h
	${CC} ${CCOPTS} -c -fPIC apetag.c
	${CC} -shared -Wl,-soname,${SONAME} -o ${SOFILENAME} ${LDFLAGS} apetag.o

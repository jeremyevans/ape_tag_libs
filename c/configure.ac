AC_INIT([libapetag], [1.1.1], [code@jeremyevans.net])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([foreign silent-rules subdir-objects])
AC_CONFIG_SRCDIR([apetag.h])
AC_PREREQ([2.59])

AC_PROG_CC_C99
AC_PROG_LIBTOOL
PKG_PROG_PKG_CONFIG


# DB (old compatibility version) detection
DB185_LIB=
DB185_HDR=

AC_DEFUN([DB185TEST_SRC],[
AC_LANG_PROGRAM([[
#include <${db185_hdr}>
DBT dbt = { sizeof(void *), dbopen };
]], [])])

dnl test compilation with an appropriate header
db185_hdrs="db.h db_185.h"
for db185_hdr in $db185_hdrs
do
	AC_MSG_CHECKING([for $db185_hdr])
	AC_COMPILE_IFELSE([DB185TEST_SRC], [
			AC_MSG_RESULT([yes])
			DB185_HDR=$db185_hdr
			break],
			[AC_MSG_RESULT([no])])
done

case $DB185_HDR in '')
AC_MSG_ERROR([One of the following headers is required: $db185_hdrs])
;;
esac

db185_hdr=$DB185_HDR

dnl test link, some systems have these functions in libc
dnl not using AC_SEARCH_LIBS here since dbopen is actually a
dnl macro on my machine which hides an internal symbol (__db185_open)
db185_lib_found=
AC_MSG_CHECKING([dbopen is available in libc])
AC_LINK_IFELSE([DB185TEST_SRC], [
		AC_MSG_RESULT([yes])
		db185_lib_found=1],
		[AC_MSG_RESULT([no])])

for db185_lib in db
do
	AC_MSG_CHECKING([dbopen is available in -l$db185_lib])
	SAVE_LDFLAGS="$LDFLAGS"
	LDFLAGS="$LDFLAGS -l$db185_lib"
	AC_LINK_IFELSE([DB185TEST_SRC], [
			AC_MSG_RESULT([yes])
			db185_lib_found=1
			DB185_LIB=-l$db185_lib],
			[AC_MSG_RESULT([no])])
	LDFLAGS="$SAVE_LDFLAGS"
	case $db185_lib_found in
	1) break ;;
	esac
done

case $db185_lib_found in '')
AC_MSG_ERROR([unable to link dbopen])
;;
esac

case $DB185_HDR in
db_185.h)
AC_DEFINE(USE_DB_185)
;;
esac
AC_SUBST([DB185_LIB])


# Detect a few extra CFLAGS
TRY_CFLAGS='-W -Wshadow -Wpointer-arith -Wcast-align -Wstrict-prototypes
	-Wsign-compare -Wmissing-prototypes -Wmissing-declarations
	-Wpadded -Wunreachable-code -Wlong-long
	-Wundef -Wcast-qual -Waggregate-return
	-pedantic'

for flag in $TRY_CFLAGS
do
	SAVE_CFLAGS="$CFLAGS"
	CFLAGS="$CFLAGS $flag"
	AC_MSG_CHECKING([if compiler supports $flag])
	AC_COMPILE_IFELSE([int main(void) { return 0; }], [
			  AC_MSG_RESULT([yes])
			  my_CFLAGS="$my_CFLAGS $flag"
			  ],
			  [
			  AC_MSG_RESULT([no])
			  CFLAGS="$SAVE_CFLAGS"
			  ])

done
AC_SUBST([my_CFLAGS])


AC_SYS_LARGEFILE
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_FILES([libapetag.pc Makefile])
AC_OUTPUT

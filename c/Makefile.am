ACLOCAL_AMFLAGS = -I m4
AM_LDFLAGS = $(DB185_LIB)
AM_CFLAGS = $(my_CFLAGS)
SUBDIRS =
pkgconfig_DATA = libapetag.pc
pkgconfigdir = $(libdir)/pkgconfig

lib_LTLIBRARIES = libapetag.la

bin_PROGRAMS = apeinfo
ape_HEADERS = apetag.h
apedir = $(includedir)

libapetag_la_DEPENDENCIES = $(ape_HEADERS)
libapetag_la_LDFLAGS = -version-info 0:0:0
libapetag_la_SOURCES = apetag.c
apeinfo_LDADD = libapetag.la
apeinfo_SOURCES = apeinfo.c

check_PROGRAMS = test/test_apetag test/test_apetag_files
TESTS = $(check_PROGRAMS)
test_test_apetag_SOURCES = test/test_apetag.c
test_test_apetag_CFLAGS = -DTEST_TAGS_DIR=\"$(top_srcdir)/test/tags\"
test_test_apetag_files_SOURCES = test/test_apetag_files.c
test_test_apetag_files_CFLAGS = -DTEST_TAGS_DIR=\"$(top_srcdir)/../test-files\"

dist_man1_MANS = apeinfo.1
dist_man3_MANS = apetag.3

EXTRA_DIST = CHANGELOG MIT-LICENSE \
	test/tags/example2.tag \
	test/tags/empty_ape.tag \
	test/tags/empty_id3.tag \
	test/tags/empty_file.tag \
	test/tags/example1_id3.tag \
	test/tags/example2_id3.tag \
	test/tags/empty_ape_id3.tag \
	test/tags/example1.tag

LINT=lint
LINTOPTS=-chrs

lint:
	${LINT} ${LINTOPTS} apetag.c
	${LINT} ${LINTOPTS} -I. apeinfo.c

MAINEXT      = pgtap
EXTENSION    = $(MAINEXT)
EXTVERSION   = $(shell grep default_version $(MAINEXT).control | \
			   sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")
NUMVERSION   = $(shell echo $(EXTVERSION) | sed -e 's/\([[:digit:]]*[.][[:digit:]]*\).*/\1/')
VERSION_FILES = sql/$(MAINEXT)--$(EXTVERSION).sql sql/$(MAINEXT)-core--$(EXTVERSION).sql sql/$(MAINEXT)-schema--$(EXTVERSION).sql
BASE_FILES 	 = $(subst --$(EXTVERSION),,$(VERSION_FILES)) sql/uninstall_$(MAINEXT).sql
_IN_FILES 	 = $(wildcard sql/*--*.sql.in)
_IN_PATCHED	 = $(_IN_FILES:.in=)
TESTS        = $(wildcard test/sql/*.sql)
EXTRA_CLEAN  = $(VERSION_FILES) sql/pgtap.sql sql/uninstall_pgtap.sql sql/pgtap-core.sql sql/pgtap-schema.sql doc/*.html
EXTRA_CLEAN  += $(wildcard sql/*.orig) # These are files left behind by patch
DOCS         = doc/pgtap.mmd
PG_CONFIG   ?= pg_config

#
# Test configuration. This must be done BEFORE including PGXS
#

# If you need to, you can manually pass options to pg_regress with this variable
REGRESS_CONF ?=

# Set this to 1 to force serial test execution; otherwise it will be determined from Postgres max_connections
PARALLEL_CONN ?=

# This controls what version to upgrade FROM when running updatecheck.
UPDATE_FROM ?= 0.95.0

#
# Setup test variables
#
# We use the contents of test/sql to create a parallel test schedule. Note that
# there is additional test setup below this; some variables must be set before
# loading PGXS, some must be set afterwards.
#

# These are test files that need to end up in test/sql to make pg_regress
# happy, but these should NOT be treated as regular regression tests
SCHEDULE_TEST_FILES = $(wildcard test/schedule/*.sql)
SCHEDULE_DEST_FILES = $(subst test/schedule,test/sql,$(SCHEDULE_TEST_FILES))
EXTRA_CLEAN += $(SCHEDULE_DEST_FILES)

# The actual schedule files. Note that we'll build 2 additional files
SCHEDULE_FILES = $(wildcard test/schedule/*.sch)

# These are our actual regression tests
TEST_FILES 	= $(filter-out $(SCHEDULE_DEST_FILES),$(wildcard test/sql/*.sql))

# Plain test names
TESTS		= $(notdir $(TEST_FILES:.sql=))

# Some tests fail when run in parallel
SERIAL_TESTS = coltap hastap

# This is a bit of a hack, but if REGRESS isn't set we can't installcheck, and
# it must be set BEFORE including pgxs. Note this gets set again below
REGRESS = --schedule $(TB_DIR)/run.sch

# REMAINING TEST VARIABLES ARE DEFINED IN THE TEST SECTION
# sort is necessary to remove dupes so install won't complain
DATA         = $(sort $(wildcard sql/*--*.sql) $(_IN_PATCHED)) # NOTE! This gets reset below!

# Locate PGXS and pg_config
ifdef NO_PGXS
top_builddir = ../..
PG_CONFIG := $(top_builddir)/src/bin/pg_config/pg_config
else
# Run pg_config to get the PGXS Makefiles
PGXS := $(shell $(PG_CONFIG) --pgxs)
endif

# We need to do various things with the PostgreSQL version.
VERSION = $(shell $(PG_CONFIG) --version | awk '{print $$2}')
$(info )
$(info GNUmake running against Postgres version $(VERSION), with pg_config located at $(shell dirname `which "$(PG_CONFIG)"`))
$(info )

#
# Major version check
#
# TODO: update this
# TODO9.1: update the $(TB_DIR) target below when de-supporting 9.1
ifeq ($(shell echo $(VERSION) | grep -qE "^(7[.]|8[.]0)" && echo yes || echo no),yes)
$(error pgTAP requires PostgreSQL 8.1 or later. This is $(VERSION))
endif

# Compile the C code only if we're on 8.3 or older.
ifeq ($(shell echo $(VERSION) | grep -qE "^8[.][123]" && echo yes || echo no),yes)
MODULES = src/pgtap
endif

# Make sure we build these.
EXTRA_CLEAN += $(_IN_PATCHED)
all: $(_IN_PATCHED) sql/pgtap.sql sql/uninstall_pgtap.sql sql/pgtap-core.sql sql/pgtap-schema.sql

# Add extension build targets on 9.1 and up.
ifeq ($(shell echo $(VERSION) | grep -qE "^(8[.]|9[.]0)" && echo no || echo yes),yes)
all: sql/$(MAINEXT)--$(EXTVERSION).sql sql/$(MAINEXT)-core--$(EXTVERSION).sql sql/$(MAINEXT)-schema--$(EXTVERSION).sql

sql/$(MAINEXT)--$(EXTVERSION).sql: sql/$(MAINEXT).sql
	cp $< $@

sql/$(MAINEXT)-core--$(EXTVERSION).sql: sql/$(MAINEXT)-core.sql
	cp $< $@

sql/$(MAINEXT)-schema--$(EXTVERSION).sql: sql/$(MAINEXT)-schema.sql
	cp $< $@

# sort is necessary to remove dupes so install won't complain
DATA = $(sort $(wildcard sql/*--*.sql) $(BASE_FILES) $(VERSION_FILES) $(_IN_PATCHED))
else
# No extension support, just install the base files.
DATA = $(BASE_FILES)
endif

# Load PGXS now that we've set all the variables it might need.
ifdef NO_PGXS
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
else
include $(PGXS)
endif

#
# DISABLED TESTS
#

# Row security policy tests not supported by 9.4 and earlier.
ifeq ($(shell echo $(VERSION) | grep -qE "^9[.][01234]|8[.]" && echo yes || echo no),yes)
EXCLUDE_TEST_FILES += test/sql/policy.sql
endif

# Partition tests tests not supported by 9.x and earlier.
ifeq ($(shell echo $(VERSION) | grep -qE "[89][.]" && echo yes || echo no),yes)
EXCLUDE_TEST_FILES += test/sql/partitions.sql
endif

# Enum tests not supported by 8.2 and earlier.
ifeq ($(shell echo $(VERSION) | grep -qE "8[.][12]" && echo yes || echo no),yes)
EXCLUDE_TEST_FILES += test/sql/enumtap.sql
endif

# Values tests not supported by 8.1 and earlier.
ifeq ($(shell echo $(VERSION) | grep -qE "8[.][1]" && echo yes || echo no),yes)
EXCLUDE_TEST_FILES += test/sql/valueset.sql
endif

#
# Check for missing extensions
#
# NOTE! This currently MUST be after PGXS! The problem is that
# $(DESTDIR)$(datadir) aren't being expanded.
#
EXTENSION_DIR = $(DESTDIR)$(datadir)/extension
extension_control = $(shell file="$(EXTENSION_DIR)/$1.control"; [ -e "$$file" ] && echo "$$file")
ifeq (,$(call extension_control,citext))
MISSING_EXTENSIONS += citext
endif
ifeq (,$(call extension_control,isn))
MISSING_EXTENSIONS += isn
endif
ifeq (,$(call extension_control,ltree))
MISSING_EXTENSIONS += ltree
endif
EXTENSION_TEST_FILES += test/sql/extension.sql
ifneq (,$(MISSING_EXTENSIONS))
# NOTE: we emit a warning about this down below, but only when we're actually running a test.
EXCLUDE_TEST_FILES += $(EXTENSION_TEST_FILES)
endif

# We need Perl.
ifneq (,$(findstring missing,$(PERL)))
PERL := $(shell which perl)
else
ifndef PERL
PERL := $(shell which perl)
endif
endif

# Is TAP::Parser::SourceHandler::pgTAP installed?
ifdef PERL
HAVE_HARNESS := $(shell $(PERL) -le 'eval { require TAP::Parser::SourceHandler::pgTAP }; print 1 unless $$@' )
endif

ifndef HAVE_HARNESS
$(warning To use pg_prove, TAP::Parser::SourceHandler::pgTAP Perl module)
$(warning must be installed from CPAN. To do so, simply run:)
$(warning     cpan TAP::Parser::SourceHandler::pgTAP)
endif

# Use a build directory to avoid cluttering up the main repo. (Maybe should just switch to VPATH builds?)
# WARNING! Not everything uses this! TODO: move all targets into $(B_DIR)
B_DIR ?= .build

# Determine the OS. Borrowed from Perl's Configure.
OSNAME := $(shell $(SHELL) ./getos.sh)

.PHONY: test

# TARGET uninstall-all: remove ALL installed versions of pgTap (rm pgtap*).
# Unlike `make unintall`, this removes pgtap*, not just our defined targets.
# Useful when testing multiple versions of pgtap.
uninstall-all:
	rm -f $(EXTENSION_DIR)/pgtap*

# TODO: switch this whole thing to a perl or shell script that understands the file naming convention and how to compare that to $VERSION.
sql/pgtap.sql: sql/pgtap.sql.in
	cp $< $@
ifeq ($(shell echo $(VERSION) | grep -qE "^(9[.][0123456]|8[.][1234])" && echo yes || echo no),yes)
	patch -p0 < compat/install-9.6.patch
endif
ifeq ($(shell echo $(VERSION) | grep -qE "^(9[.][01234]|8[.][1234])" && echo yes || echo no),yes)
	patch -p0 < compat/install-9.4.patch
endif
ifeq ($(shell echo $(VERSION) | grep -qE "^(9[.][012]|8[.][1234])" && echo yes || echo no),yes)
	patch -p0 < compat/install-9.2.patch
endif
ifeq ($(shell echo $(VERSION) | grep -qE "^(9[.][01]|8[.][1234])" && echo yes || echo no),yes)
	patch -p0 < compat/install-9.1.patch
endif
ifeq ($(shell echo $(VERSION) | grep -qE "^(9[.]0|8[.][1234])" && echo yes || echo no),yes)
	patch -p0 < compat/install-9.0.patch
endif
ifeq ($(shell echo $(VERSION) | grep -qE "^8[.][1234]" && echo yes || echo no),yes)
	patch -p0 < compat/install-8.4.patch
endif
ifeq ($(shell echo $(VERSION) | grep -qE "^8[.][123]" && echo yes || echo no),yes)
	patch -p0 < compat/install-8.3.patch
endif
ifeq ($(shell echo $(VERSION) | grep -qE "^8[.][12]" && echo yes || echo no),yes)
	patch -p0 < compat/install-8.2.patch
endif
ifeq ($(shell echo $(VERSION) | grep -qE "^8[.][1]" && echo yes || echo no),yes)
	patch -p0 < compat/install-8.1.patch
endif
	sed -e 's,MODULE_PATHNAME,$$libdir/pgtap,g' -e 's,__OS__,$(OSNAME),g' -e 's,__VERSION__,$(NUMVERSION),g' sql/pgtap.sql > sql/pgtap.tmp
	mv sql/pgtap.tmp sql/pgtap.sql

# Ugly hacks for now... TODO: script that understands $VERSION and will apply all the patch files for that version
EXTRA_CLEAN += sql/pgtap--0.99.0--1.0.0.sql
sql/pgtap--0.99.0--1.0.0.sql: sql/pgtap--0.99.0--1.0.0.sql.in
	cp $< $@
ifeq ($(shell echo $(VERSION) | grep -qE "^(9[.][01234]|8[.][1234])" && echo yes || echo no),yes)
	patch -p0 < compat/9.4/pgtap--0.99.0--1.0.0.patch
endif

EXTRA_CLEAN += sql/pgtap--0.98.0--0.99.0.sql
sql/pgtap--0.98.0--0.99.0.sql: sql/pgtap--0.98.0--0.99.0.sql.in
	cp $< $@
ifeq ($(shell echo $(VERSION) | grep -qE "^([89]|10)[.]" && echo yes || echo no),yes)
	patch -p0 < compat/10/pgtap--0.98.0--0.99.0.patch
endif

EXTRA_CLEAN += sql/pgtap--0.97.0--0.98.0.sql
sql/pgtap--0.97.0--0.98.0.sql: sql/pgtap--0.97.0--0.98.0.sql.in
	cp $< $@
ifeq ($(shell echo $(VERSION) | grep -qE "^[89][.]" && echo yes || echo no),yes)
	patch -p0 < compat/9.6/pgtap--0.97.0--0.98.0.patch
endif

EXTRA_CLEAN += sql/pgtap--0.96.0--0.97.0.sql
sql/pgtap--0.96.0--0.97.0.sql: sql/pgtap--0.96.0--0.97.0.sql.in
	cp $< $@
ifeq ($(shell echo $(VERSION) | grep -qE "^(9[.][01234]|8[.][1234])" && echo yes || echo no),yes)
	patch -p0 < compat/9.4/pgtap--0.96.0--0.97.0.patch
endif
ifeq ($(shell echo $(VERSION) | grep -qE "^(9[.]0|8[.][1234])" && echo yes || echo no),yes)
	patch -p0 < compat/9.0/pgtap--0.96.0--0.97.0.patch
endif

EXTRA_CLEAN += sql/pgtap--0.95.0--0.96.0.sql
sql/pgtap--0.95.0--0.96.0.sql: sql/pgtap--0.95.0--0.96.0.sql.in
	cp $< $@
ifeq ($(shell echo $(VERSION) | grep -qE "^(9[.][012]|8[.][1234])" && echo yes || echo no),yes)
	patch -p0 < compat/9.2/pgtap--0.95.0--0.96.0.patch
endif

sql/uninstall_pgtap.sql: sql/pgtap.sql test/setup.sql
	grep '^CREATE ' sql/pgtap.sql | $(PERL) -e 'for (reverse <STDIN>) { chomp; s/CREATE (OR REPLACE )?/DROP /; print "$$_;\n" }' | sed 's/DROP \(FUNCTION\|VIEW\|TYPE\) /DROP \1 IF EXISTS /' > sql/uninstall_pgtap.sql

#
# Support for static install files
#

# The use of $@.tmp is to eliminate the possibility of leaving an invalid pgtap-static.sql in case the recipe fails part-way through.
# TODO: the sed command needs the equivalent of bash's PIPEFAIL; should just replace this with some perl magic
sql/pgtap-static.sql: sql/pgtap.sql.in
	cp $< $@.tmp
	for p in `ls compat/install-*.patch | sort -rn`; do \
		echo; echo '***' "Patching pgtap-static.sql with $$p"; \
		sed -e 's#sql/pgtap.sql#sql/pgtap-static.sql.tmp#g' "$$p" | patch -p0; \
	done
	sed -e 's#MODULE_PATHNAME#$$libdir/pgtap#g' -e 's#__OS__#$(OSNAME)#g' -e 's#__VERSION__#$(NUMVERSION)#g' $@.tmp > $@
EXTRA_CLEAN += sql/pgtap-static.sql sql/pgtap-static.sql.tmp

sql/pgtap-core.sql: sql/pgtap-static.sql
	$(PERL) compat/gencore 0 sql/pgtap-static.sql > sql/pgtap-core.sql

sql/pgtap-schema.sql: sql/pgtap-static.sql
	$(PERL) compat/gencore 1 sql/pgtap-static.sql > sql/pgtap-schema.sql

$(B_DIR)/static/: $(B_DIR)
	mkdir -p $@

# We don't lump this in with the $(B_DIR)/static target because that would run the risk of a failure of the cp command leaving an empty directory behind
$(B_DIR)/static/%/: %/ $(B_DIR)/static
	cp -R $< $@

# Make sure that we build the regression tests.
installcheck: test/setup.sql

html:
	multimarkdown doc/pgtap.mmd > doc/pgtap.html
	./tocgen doc/pgtap.html 2> doc/toc.html
	perl -MPod::Simple::XHTML -E "my \$$p = Pod::Simple::XHTML->new; \$$p->html_header_tags('<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">'); \$$p->strip_verbatim_indent(sub { my \$$l = shift; (my \$$i = \$$l->[0]) =~ s/\\S.*//; \$$i }); \$$p->parse_from_file('`perldoc -l pg_prove`')" > doc/pg_prove.html

#
# Actual test targets
#

# TARGET regress: run installcheck then print any diffs from expected output.
.PHONY: regress
regress: installcheck_deps
	$(MAKE) installcheck || ([ -e regression.diffs ] && $${PAGER:-cat} regression.diffs; exit 1)

# TARGET updatecheck: install an older version of pgTap from PGXN (controlled by $UPDATE_FROM; 0.95.0 by default), update to the current version via ALTER EXTENSION, then run installcheck.
.PHONY: updatecheck
updatecheck: updatecheck_deps install
	$(MAKE) updatecheck_run || ([ -e regression.diffs ] && $${PAGER:-cat} regression.diffs; exit 1)

# General dependencies for installcheck. Note that several other places add themselves as dependencies.
.PHONY: installcheck_deps
installcheck_deps: $(SCHEDULE_DEST_FILES) extension_check set_parallel_conn # More dependencies below

# In addition to installcheck, one can also run the tests through pg_prove.
test: extension_check
	pg_prove --pset tuples_only=1 $(TEST_FILES)

#
# General test support
#
# In order to support parallel testing, we need to have a test schedule file,
# which we build dynamically. Instead of cluttering the test directory, we use
# a test build directiory ($(TB_DIR)). We also use $(TB_DIR) to drop some
# additional artifacts, so that we can automatically determine if certain
# dependencies (such as excluded tests) have changed since the last time we
# ran.
TB_DIR = test/build
GENERATED_SCHEDULE_DEPS = $(TB_DIR)/tests $(TB_DIR)/exclude_tests
REGRESS = --schedule $(TB_DIR)/run.sch # Set this again just to be safe
REGRESS_OPTS = --inputdir=test --load-language=plpgsql --max-connections=$(PARALLEL_CONN) --schedule $(SETUP_SCH) $(REGRESS_CONF)
SETUP_SCH = test/schedule/main.sch # schedule to use for test setup; this can be forcibly changed by some targets!
IGNORE_TESTS = $(notdir $(EXCLUDE_TEST_FILES:.sql=))
PARALLEL_TESTS = $(filter-out $(IGNORE_TESTS),$(filter-out $(SERIAL_TESTS),$(TESTS)))
GENERATED_SCHEDULES = $(TB_DIR)/serial.sch $(TB_DIR)/parallel.sch
installcheck: $(TB_DIR)/run.sch installcheck_deps

# Parallel tests will use $(PARALLEL_TESTS) number of connections if we let it,
# but max_connections may not be set that high. You can set this manually to 1
# for no parallelism
#
# This can be a bit expensive if we're not testing, so set it up as a
# dependency of installcheck
.PHONY: set_parallel_conn
set_parallel_conn:
	$(eval PARALLEL_CONN = $(shell tools/parallel_conn.sh $(PARALLEL_CONN)))
	@[ -n "$(PARALLEL_CONN)" ]
	@echo "Using $(PARALLEL_CONN) parallel test connections"

# Have to do this as a separate task to ensure the @[ -n ... ] test in set_parallel_conn actually runs
$(TB_DIR)/which_schedule: $(TB_DIR)/ set_parallel_conn
	$(eval SCHEDULE = $(shell [ $(PARALLEL_CONN) -gt 1 ] && echo $(TB_DIR)/parallel.sch || echo $(TB_DIR)/serial.sch))
	@[ -n "$(SCHEDULE)" ]
	@[ "`cat $@ 2>/dev/null`" = "$(SCHEDULE)" ] || (echo "Schedule changed to $(SCHEDULE)"; echo "$(SCHEDULE)" > $@)

# Generated schedule files, one for serial one for parallel
.PHONY: $(TB_DIR)/tests # Need this target to force schedule rebuild if $(TEST) changes
$(TB_DIR)/tests: $(TB_DIR)/
	@[ "`cat $@ 2>/dev/null`" = "$(TEST)" ] || (echo "Rebuilding $@"; echo "$(TEST)" > $@)

.PHONY: $(TB_DIR)/exclude_tests # Need this target to force schedule rebuild if $(EXCLUDE_TEST) changes
$(TB_DIR)/exclude_tests: $(TB_DIR)/
	@[ "`cat $@ 2>/dev/null`" = "$(EXCLUDE_TEST)" ] || (echo "Rebuilding $@"; echo "$(EXCLUDE_TEST)" > $@)

$(TB_DIR)/serial.sch: $(GENERATED_SCHEDULE_DEPS)
	@(for f in $(IGNORE_TESTS); do echo "ignore: $$f"; done; for f in $(TESTS); do echo "test: $$f"; done) > $@

$(TB_DIR)/parallel.sch: $(GENERATED_SCHEDULE_DEPS)
	@( \
		for f in $(SERIAL_TESTS); do echo "test: $$f"; done; \
		([ -z "$(IGNORE_TESTS)" ] || echo "ignore: $(IGNORE_TESTS)"); \
		([ -z "$(PARALLEL_TESTS)" ] || echo "test: $(PARALLEL_TESTS)") \
	) > $@

$(TB_DIR)/run.sch: $(TB_DIR)/which_schedule $(GENERATED_SCHEDULES)
	cp `cat $<` $@

# Don't generate noise if we're not running tests...
.PHONY: extension_check
extension_check: 
	@[ -z "$(MISSING_EXTENSIONS)" ] || (echo; echo '***************************'; echo "WARNING: Some mandatory extensions ($(MISSING_EXTENSIONS)) are not installed; ignoring tests: $(EXTENSION_TEST_FILES)"; echo '***************************'; echo)


# These tests have specific dependencies
test/sql/build.sql: sql/pgtap.sql
test/sql/create.sql test/sql/update.sql: pgtap-version-$(EXTVERSION)

test/sql/%.sql: test/schedule/%.sql
	@(echo '\unset ECHO'; echo '-- GENERATED FILE! DO NOT EDIT!'; echo "-- Original file: $<"; cat $< ) > $@

# Prior to 9.2, EXTRA_CLEAN just does rm -f, which obviously won't work with a directory.
# TODO9.1: switch back to EXTRA_CLEAN when removing support for 9.1
#EXTRA_CLEAN += $(TB_DIR)/
clean: clean_tb_dir
.PHONY: clean_tb_dir
clean_tb_dir:
	@rm -rf $(TB_DIR)
$(TB_DIR)/:
	@mkdir -p $@

clean: clean_b_dir
.PHONY: clean_b_dir
clean_b_dir:
	@rm -rf $(B_DIR)
$(B_DIR)/:
	@mkdir -p $@


#
# Update test support
#

# If the specified version of pgtap doesn't exist, install it. Note that the
# real work is done by the $(EXTENSION_DIR)/pgtap--%.sql rule below.
pgtap-version-%: $(EXTENSION_DIR)/pgtap--%.sql
	@true # Necessary to have a fake action here


# Travis will complain if we reinstall too quickly, so don't run make install
# unless actually necessary.
$(EXTENSION_DIR)/pgtap--$(EXTVERSION).sql: sql/pgtap--$(EXTVERSION).sql
	$(MAKE) install

# Install an old version of pgTap via pgxn. NOTE! This rule works in
# conjunction with the rule above, which handles installing our version.
#
# Note that we need to capture the test failure so the rule doesn't abort;
# that's why the test is written with || and not &&.
$(EXTENSION_DIR)/pgtap--%.sql:
	@ver=$(@:$(EXTENSION_DIR)/pgtap--%.sql=%); [ "$$ver" = "$(EXTVERSION)" ] || (echo Installing pgtap version $$ver from pgxn; pgxn install --pg_config=$(PG_CONFIG) pgtap=$$ver)

# This is separated out so it can be called before calling updatecheck_run
.PHONY: updatecheck_deps
updatecheck_deps: pgtap-version-$(UPDATE_FROM) test/sql/update.sql

# We do this as a separate step to change SETUP_SCH before the main updatecheck
# recipe calls installcheck (which depends on SETUP_SCH being set correctly).
.PHONY: updatecheck_setup
# pg_regress --launcher not supported prior to 9.1
# There are some other failures in 9.1 and 9.2 (see https://travis-ci.org/decibel/pgtap/builds/358206497).
# TODO: find something that can generically compare majors (ie: GE91 from
# https://github.com/decibel/pgxntool/blob/master/base.mk).
updatecheck_setup: updatecheck_deps
	@if echo $(VERSION) | grep -qE "8[.]|9[.][012]"; then echo "updatecheck is not supported prior to 9.3"; exit 1; fi
	$(eval SETUP_SCH = test/schedule/update.sch)
	$(eval REGRESS_OPTS += --launcher "tools/psql_args.sh -v 'old_ver=$(UPDATE_FROM)' -v 'new_ver=$(EXTVERSION)'")
	@echo
	@echo "###################"
	@echo "Testing upgrade from $(UPDATE_FROM) to $(EXTVERSION)"
	@echo "###################"
	@echo

.PHONY: updatecheck_run
updatecheck_run: updatecheck_setup installcheck

#
# STOLEN FROM pgxntool
#

# TARGET results: runs `make test` and copies all result files to test/expected/. DO NOT RUN THIS UNLESS YOU'RE CERTAIN ALL YOUR TESTS ARE PASSING!
.PHONY: results
results: installcheck result-rsync

.PHONY:
result-rsync:
	rsync -rlpgovP results/ test/expected


# To use this, do make print-VARIABLE_NAME
print-%	: ; $(info $* is $(flavor $*) variable set to "$($*)") @true

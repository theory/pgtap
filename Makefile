DATA_built = pgtap.sql drop_pgtap.sql
DOCS = README.pgtap
SCRIPTS = pg_prove
TAPTEST = test.sql
EXTRA_CLEAN = $(TAPTEST)

top_builddir = ../..
in_contrib = $(wildcard $(top_builddir)/src/Makefile.global);

ifdef $(in_contrib)
	# Just include the local makefiles
	subdir = contrib/pgtap
	include $(top_builddir)/src/Makefile.global
	include $(top_srcdir)/contrib/contrib-global.mk
else
	# Use pg_config to find PGXS and include it.
	PGXS := $(shell pg_config --pgxs)
	include $(PGXS)
endif

# I would really prefer to just add TAPTEST to the default...
all: $(PROGRAM) $(DATA_built) $(TAPTEST) $(SCRIPTS_built) $(addsuffix $(DLSUFFIX), $(MODULES))

%.sql: %.sql.in
ifdef TAPSCHEMA
	sed -e 's,TAPSCHEMA,$(TAPSCHEMA),g' -e 's/^-- ## //g' $< >$@
else
	cp $< $@
endif

test:
	./pg_prove $(TAPTEST)
PRJNM = proj
LIBNM = lib$(PRJNM)

SO_VER = 0.1

RTDIR = $(shell git rev-parse --show-toplevel)

SRCDIR = src
TSTDIR = tst
INCDIR = inc
DOCDIR = doc
BLDDIR = bld
OBJDIR = $(BLDDIR)/obj
DEPDIR = dep

CONFIGURED_DEPS =

CPPFLAGS = -I$(INCDIR)
CFLAGS = -Og -ggdb3 -Wall -Wextra -Wpedantic -std=gnu18
LINKFLAGS = #

ifneq ($(CONFIGURED_DEPS),)
CPPFLAGS += $(shell pkg-config --cflags-only-I $(CONFIGURED_DEPS))
CFLAGS += $(shell pkg-config --cflags-only-other $(CONFIGURED_DEPS))
LINKFLAGS += $(shell pkg-config --libs $(CONFIGURED_DEPS))
endif

DATE = $(shell date +'%Y-%b-%d')

MKDIR = @mkdir -p --
RM = rm -rf --
LN = ln -sf --
DOCC = scdoc

SOURCES = $(patsubst $(SRCDIR)/main.c,,$(wildcard $(SRCDIR)/*))
OBJECTS = $(patsubst $(SRCDIR)%,$(OBJDIR)%,$(patsubst %.c,%.o,$(SOURCES)))
DEPENDS = $(patsubst $(SRCDIR)%,$(DEPDIR)%,$(patsubst %.c,%.d,$(SOURCES)))

TESTSRC = $(wildcard $(TSTDIR)/*.c)
TESTS   = $(patsubst $(TSTDIR)%,$(BLDDIR)/$(TSTDIR)%,$(patsubst %.c,%,$(TESTSRC)))

DOCSSRC = $(wildcard $(DOCDIR)/*.scd)
DOCS    = $(patsubst $(DOCDIR)%,$(BLDDIR)/$(DOCDIR)%,$(patsubst %.scd,%,$(DOCSSRC)))

.PHONY: all clean check docs $(LIBNM) $(PRJNM)

all: check

clean:
	$(RM) $(BLDDIR) $(DEPDIR) tags

-include $(DEPENDS)

docs: $(DOCS)

$(BLDDIR)/$(DOCDIR)/%: $(DOCDIR)/%.scd
	$(MKDIR) $(@D)
	$(DOCC) < $< > $@

$(PRJNM):
	zig build -p $(BLDDIR)

check: $(PRJNM)
	for i in $(SOURCES); do zig test "$$i"; done

tags:
	find . -type f -iregex '.*\.[ch]\(xx\|pp\)?$$' | xargs ctags -a -f $@

$(V).SILENT:

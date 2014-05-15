# The MIT License (MIT)
#
# Copyright (c) 2014 Koka El Kiwi <kokakiwi@kokakiwi.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Paths
RUSTC                   ?=  rustc
RUSTDOC                 ?=  rustdoc
INSTALL                 ?=  install

# Flags
RUSTCFLAGS              ?=
RUSTDOCFLAGS            ?=

# Variables
RUSTDEBUG               ?=  0
RUSTAUTORULES           ?=  1
RUSTBUILDDIR            ?=  .rust
RUSTSRCDIR              ?=  src
RUSTBINDIR              ?=  .
RUSTLIBDIR              ?=  lib
RUSTDOCDIR              ?=  doc
RUSTINSTALLDIR          ?=  ~/.rust

RUSTLIBFLAGS            =   -L $(RUSTLIBDIR) -L $(RUSTINSTALLDIR)/lib

RUSTCFLAGS              +=  $(RUSTLIBFLAGS)
RUSTDOCFLAGS            +=  $(RUSTLIBFLAGS)

## Set custom doc directory.
RUSTDOCFLAGS            +=  --output $(RUSTDOCDIR)

## Add additionnal debug/optimize flags
ifeq ($(RUSTDEBUG),0)
RUSTCFLAGS              +=  --opt-level=3 --cfg ndebug
else
RUSTCFLAGS              +=  -g
endif

## UTILS ##
# Recursive wildcard function
# http://blog.jgc.org/2011/07/gnu-make-recursive-wildcard-function.html
rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) \
  $(filter $(subst *,%,$2),$d))

# Gen rules
## Binary
define RUST_CRATE_BIN

$(1)_PREFIX             ?=  $$(RUSTBINDIR)/
$(1)_INSTALLDIR         =   bin

endef

## Libray
define RUST_CRATE_LIB

$(1)_PREFIX             ?=  $$(RUSTLIBDIR)/
$(1)_INSTALLDIR         =   lib

endef

## Common
define RUST_CRATE_RULES

### Crate common variables
$(1)_ROOTDIR            ?=  .
$(1)_DIRNAME            ?=  $$($(1)_ROOTDIR)/$$(RUSTSRCDIR)/$(1)
$(1)_DEPFILE            =   $$(RUSTBUILDDIR)/$(1).deps.mk
$(1)_DEPFILE_TEST       =   $$(RUSTBUILDDIR)/$(1).test.deps.mk
$(1)_TESTNAME           =   $$(RUSTBUILDDIR)/test_$(1)
$(1)_INSTALLABLE        ?=  1
$(1)_TEST_DOC           ?=  1
$(1)_DONT_TEST          ?=  0
$(1)_DONT_BENCH         ?=  $$($(1)_DONT_TEST)
$(1)_DONT_DOC           ?=  0
$(1)_DONT_ADD_RULES     ?=  0

### Determine crate root based on existing files, if not already defined.
ifeq ($$($(1)_ROOT),)
ifneq ($$(wildcard $$($(1)_DIRNAME)/main.rs),)
$(1)_ROOT               ?=  $$($(1)_DIRNAME)/main.rs
else ifneq ($$(wildcard $$($(1)_DIRNAME)/lib.rs),)
$(1)_ROOT               ?=  $$($(1)_DIRNAME)/lib.rs
endif
endif

### Determine crate type based on crate root
ifeq ($$($(1)_TYPE),)
ifeq ($$(notdir $$($(1)_ROOT)),main.rs)
$(1)_TYPE               =   bin
else ifeq ($$(notdir $$($(1)_ROOT)),lib.rs)
$(1)_TYPE               =   lib
endif
endif

### Set up crates type dependent variables
ifeq ($$($(1)_TYPE),bin)
$$(eval $$(call RUST_CRATE_BIN,$(1)))
else ifeq ($$($(1)_TYPE),lib)
$$(eval $$(call RUST_CRATE_LIB,$(1)))
else ifeq ($$($(1)_TYPE),)
$$(error No crate type for '$(1)')
else
$$(error Unknown crate type '$$($(1)_TYPE)' for '$(1)')
endif

### Crate common variables (after type resolving)
$(1)_ROOT_TEST          ?=  $$($(1)_ROOT)
$(1)_NAMES              =   $$(addprefix $$($(1)_PREFIX),$$(shell $$(RUSTC) $$(RUSTCFLAGS) $$($(1)_RUSTCFLAGS) --crate-file-name $$($(1)_ROOT)))
$(1)_NAME               =   $$(firstword $$($(1)_NAMES))
$(1)_RUSTCFLAGS_BUILD   +=  --out-dir $$($(1)_PREFIX)

### Crate build entry rule
build_$(1):             $$($(1)_NAME)

### Crate `clean` rule
clean_$(1):
	rm -f $$($(1)_NAMES) $$($(1)_DEPFILE)

### Crate `rebuild` rule
rebuild_$(1):           clean_$(1) build_$(1)

ifneq ($$($(1)_DONT_TEST),1)
### Crate `test` rule
test_$(1):              $$($(1)_TESTNAME)
	@$$($(1)_TESTNAME)
endif

ifneq ($$($(1)_DONT_BENCH),1)
### Crate `bench` rule
bench_$(1):             $$($(1)_TESTNAME)
	@$$($(1)_TESTNAME) --bench
endif

ifneq ($$($(1)_DONT_DOC),1)
### Crate `doc` rule
ifeq ($$($(1)_TEST_DOC),1)
#### Need to build crate before testing doc
doc_$(1):               $$($(1)_NAME)
endif
doc_$(1):
ifeq ($$($(1)_TEST_DOC),1) # Test doc before generating it if enabled.
	$$(RUSTDOC) $$(RUSTDOCFLAGS) $$($(1)_RUSTDOCFLAGS) --test $$($(1)_ROOT)
endif
	$$(RUSTDOC) $$(RUSTDOCFLAGS) $$($(1)_RUSTDOCFLAGS) $$($(1)_ROOT)
endif

### Add crate install/uninstall rules if crate is flagged as "installable"
ifeq ($$($(1)_INSTALLABLE),1)
### Crate `install` rule
install_$(1):           $$($(1)_NAME)
	@mkdir -p $$(RUSTINSTALLDIR)/$$($(1)_INSTALLDIR)
	$(INSTALL) $$($(1)_NAMES) $$(RUSTINSTALLDIR)/$$($(1)_INSTALLDIR)

### Crate `uninstall` rule
uninstall_$(1):
	rm -f $$(foreach name,$$($(1)_NAMES),$$(RUSTINSTALLDIR)/$$($(1)_INSTALLDIR)/$$(notdir $$(name)))
endif

### Crate build rule
$$($(1)_NAME):          $$($(1)_BUILD_DEPS)
	@mkdir -p $$(dir $$($(1)_NAME))
	@mkdir -p $$(dir $$($(1)_DEPFILE))
	$$(RUSTC) $$(RUSTCFLAGS) $$($(1)_RUSTCFLAGS_BUILD) $$($(1)_RUSTCFLAGS) --dep-info $$($(1)_DEPFILE) $$($(1)_ROOT)
-include $$($(1)_DEPFILE)

### Crate test build rule
$(1)_COMPILE_TEST       =   0
ifneq ($$($(1)_DONT_TEST),1)
$(1)_COMPILE_TEST       =   1
endif
ifneq ($$($(1)_DONT_BENCH),1)
$(1)_COMPILE_TEST       =   1
endif

ifeq ($$($(1)_COMPILE_TEST),1)
$$($(1)_TESTNAME):      $$($(1)_BUILD_DEPS)
	@mkdir -p $$(dir $$($(1)_TESTNAME))
	@mkdir -p $$(dir $$($(1)_DEPFILE_TEST))
	@$$(RUSTC) $$(RUSTCFLAGS) $$($(1)_RUSTCFLAGS) --dep-info $$($(1)_DEPFILE_TEST) --test -o $$($(1)_TESTNAME) $$($(1)_ROOT_TEST)
-include $$($(1)_DEPFILE_TEST)

clean_test_$(1):
	rm -f $$($(1)_TESTNAME)
.PHONY clean_$(1):      clean_test_$(1)
endif

### Add crate rules to global rules
.PHONY build:           build_$(1)
.PHONY clean:           clean_$(1)
.PHONY:                 rebuild_$(1)

### Add `install` and `uninstall` crate rules to global rules
ifeq ($$($(1)_INSTALLABLE),1)
.PHONY install:         install_$(1)
.PHONY uninstall:       uninstall_$(1)
endif

### Add `doc` crate rules
ifneq ($$($($(1)_DONT_DOC)),1)
.PHONY doc:             doc_$(1)
endif

### Add `test` crate rule to global rules
ifneq ($$($(1)_DONT_TEST),1)
.PHONY test:            test_$(1)
endif

### Add `bench` crate rule to global rules
ifneq ($$($(1)_DONT_BENCH),1)
.PHONY bench:           bench_$(1)
endif

### Additionnals crate rules
ifneq ($$($(1)_DONT_ADD_RULES),1)
ifdef RUST_CRATE_RULES_ADD
$$(eval $$(call RUST_CRATE_RULES_ADD,$(1)))
endif
endif

endef

## Utils
define RUST_CRATE_DEPEND
$$($(1)_NAMES):         $$(foreach dep,$(2),$$($$(dep)_NAME))
endef

define RUST_CLEAN_DIR
ifneq ($(2),.)
fclean_$(1):
	rm -rf $(2)
.PHONY fclean:          fclean_$(1)
endif
endef

## Rules
define RUST_CRATES_RULES

$$(foreach crate,$$(RUSTCRATES),$$(eval $$(call RUST_CRATE_RULES,$$(crate))))
$$(foreach crate,$$(RUSTCRATES),$$(eval $$(call RUST_CRATE_DEPEND,$$(crate),$$($$(crate)_CRATE_DEPS))))

endef

# Rules

## Basic rules
all:
build:
clean:
fclean:
rebuild:
test:
bench:
doc:
install:
uninstall:

## Auto rules
ifeq ($(RUSTAUTORULES),1)
$(eval $(call RUST_CRATES_RULES))
endif

## Basic rule dependencies
all:                    build
fclean:                 clean
rebuild:                clean build

## `fclean` rules
$(eval $(call RUST_CLEAN_DIR,build_dir,$(RUSTBUILDDIR)))
$(eval $(call RUST_CLEAN_DIR,bin_dir,$(RUSTBINDIR)))
$(eval $(call RUST_CLEAN_DIR,lib_dir,$(RUSTLIBDIR)))
$(eval $(call RUST_CLEAN_DIR,doc_dir,$(RUSTDOCDIR)))

## `crates` rule
crates:
	@echo "$(RUSTCRATES)"

## `help` rule
help:
	@echo " Common rules:"
	@echo "  make all                 - Build all crates (alias of 'build' target)."
	@echo "  make build               - Build all crates."
	@echo "  make clean               - Clean crates targets."
	@echo "  make fclean              - Clean crates targets and build directories."
	@echo "  make rebuild             - Rebuild all crates."
	@echo "  make test                - Build and run tests."
	@echo "  make bench               - Build and run benchs."
	@echo "  make doc                 - Generate crates documentation."
	@echo "  make install             - Install crates targets in $(RUSTINSTALLDIR)"
	@echo "  make uninstall           - Uninstall crates targets."
	@echo "  make crates              - Print available crates."
	@echo "  make help                - Print this help."
	@echo
	@echo " Crates rules:"
	@echo "  make build_<crate>       - Build <crate>."
	@echo "  make clean_<crate>       - Clean <crate> targets."
	@echo "  make rebuild_<crate>     - Rebuild <crate>."
	@echo "  make test_<crate>        - Build and run <crate> tests."
	@echo "  make bench_<crate>       - Build and run <crate> benchs."
	@echo "  make doc_<crate>         - Generate <crate> documentation."
	@echo "  make install_<crate>     - Install <crate> targets in $(RUSTINSTALLDIR)"
	@echo "  make uninstall_<crate>   - Uninstall <crate> targets."
	@echo
	@echo " Available crates:         $(RUSTCRATES)"

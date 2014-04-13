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
RUSTCFLAGS              +=  --opt-level=3
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

$(1)_ROOT               =   $$($(1)_DIRNAME)/main.rs
$(1)_PREFIX             =   $$(RUSTBINDIR)/
$(1)_RUSTCFLAGS_BUILD   +=  --out-dir $$(RUSTBINDIR)
$(1)_INSTALLDIR         =   bin

endef

## Libray
define RUST_CRATE_LIB

$(1)_ROOT               =   $$($(1)_DIRNAME)/lib.rs
$(1)_PREFIX             =   $$(RUSTLIBDIR)/
$(1)_RUSTCFLAGS_BUILD   +=  --out-dir $$(RUSTLIBDIR)
$(1)_INSTALLDIR         =   lib

endef

## Common
define RUST_CRATE_COMMON

### Crate common variables
$(1)_DIRNAME            =   $$(RUSTSRCDIR)/$(1)
$(1)_DEPFILE            =   $$(RUSTBUILDDIR)/$(1).deps.mk
$(1)_DEPFILE_TEST       =   $$(RUSTBUILDDIR)/$(1).deps.test.mk
$(1)_TESTNAME           =   $$(RUSTBUILDDIR)/test_$(1)
$(1)_INSTALLABLE        ?=  1

### Determine crate type based on existing files
ifeq ($$($(1)_TYPE),)
ifneq ($$(wildcard $$($(1)_DIRNAME)/main.rs),)
$(1)_TYPE               =   bin
else ifneq ($$(wildcard $$($(1)_DIRNAME)/lib.rs),)
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
$(1)_ROOT_TEST          =   $$($(1)_ROOT)
$(1)_NAMES              =   $$(addprefix $$($(1)_PREFIX),$$(shell $$(RUSTC) $$(RUSTCFLAGS) $$($(1)_RUSTCFLAGS) --crate-file-name $$($(1)_ROOT)))
$(1)_NAME               =   $$(firstword $$($(1)_NAMES))

### Crate build entry rule
build_$(1):             $$($(1)_NAME)

### Crate `clean` rule
clean_$(1):
	rm -f $$($(1)_NAMES) $$($(1)_DEPFILE) $$($(1)_TESTNAME)

### Crate `test` rule
test_$(1):              $$($(1)_TESTNAME)
	@$$($(1)_TESTNAME)

### Crate `bench` rule
bench_$(1):             $$($(1)_TESTNAME)
	@$$($(1)_TESTNAME) --bench

### Crate `doc` rule
doc_$(1):
	$$(RUSTDOC) $$(RUSTDOCFLAGS) $$($(1)_ROOT)

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
$$($(1)_TESTNAME):      $$($(1)_BUILD_DEPS)
	@mkdir -p $$(dir $$($(1)_TESTNAME))
	@mkdir -p $$(dir $$($(1)_DEPFILE_TEST))
	@$$(RUSTC) $$(RUSTCFLAGS) $$($(1)_RUSTCFLAGS) --dep-info $$($(1)_DEPFILE_TEST) --test -o $$($(1)_TESTNAME) $$($(1)_ROOT_TEST)
-include $$($(1)_DEPFILE_TEST)

### Add crate rules to global rules
.PHONY all:             build_$(1)
.PHONY clean:           clean_$(1)
.PHONY test:            test_$(1)
.PHONY bench:           bench_$(1)
.PHONY doc:             doc_$(1)

### Add `install` and `uninstall` crate rules to global rules
ifeq ($$($(1)_INSTALLABLE),1)
.PHONY install:         install_$(1)
.PHONY uninstall:       uninstall_$(1)
endif

endef

## Utils
define RUST_CRATE_DEPEND
$$($(1)_NAMES):         $$($(2)_NAME)
endef

define RUST_CLEAN_DIR
ifneq ($(2),.)
fclean_$(1):
	rm -rf $(2)
.PHONY fclean:          fclean_$(1)
endif
endef

## Rules
define RUST_CRATE_RULES

$$(foreach crate,$$(RUSTCRATES),$$(eval $$(call RUST_CRATE_COMMON,$$(crate))))
$$(foreach crate,$$(RUSTCRATES),$$(eval $$(call RUST_CRATE_DEPEND,$$(crate),$$($$(crate)_CRATE_DEPS))))

endef

# Rules

## Basic rules
all:
clean:
fclean:
test:
bench:
doc:
install:
uninstall:

## Auto rules
ifeq ($(RUSTAUTORULES),1)
$(eval $(call RUST_CRATE_RULES))
endif

## Basic rule dependencies
fclean:                 clean

## Build directories clean rules
$(eval $(call RUST_CLEAN_DIR,build_dir,$(RUSTBUILDDIR)))
$(eval $(call RUST_CLEAN_DIR,bin_dir,$(RUSTBINDIR)))
$(eval $(call RUST_CLEAN_DIR,lib_dir,$(RUSTLIBDIR)))
$(eval $(call RUST_CLEAN_DIR,doc_dir,$(RUSTDOCDIR)))

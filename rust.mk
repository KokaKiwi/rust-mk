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
RUSTLIBDIR              ?=  lib
RUSTINSTALLDIR          ?=  ~/.rust

RUSTLIBFLAGS            =   -L $(RUSTLIBDIR) -L $(RUSTINSTALLDIR)/lib

RUSTCFLAGS              +=  $(RUSTLIBFLAGS)
RUSTDOCFLAGS            +=  $(RUSTLIBFLAGS)

ifeq ($(RUSTDEBUG),0)
RUSTCFLAGS              +=  --opt-level=3
else
RUSTCFLAGS              +=  -g
endif

## UTILS
# Recursive wildcard function
# http://blog.jgc.org/2011/07/gnu-make-recursive-wildcard-function.html
rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) \
  $(filter $(subst *,%,$2),$d))

# Gen rules
## Binary
define RUST_CRATE_BIN

$(1)_ROOT               =   $$($(1)_DIRNAME)/main.rs
$(1)_INSTALLDIR         =   $$(RUSTINSTALLDIR)/bin

endef

## Libray
define RUST_CRATE_LIB

$(1)_ROOT               =   $$($(1)_DIRNAME)/lib.rs
$(1)_PREFIX             =   $$(RUSTLIBDIR)/
$(1)_RUSTCFLAGS_BUILD   +=  --out-dir $$(RUSTLIBDIR)
$(1)_INSTALLDIR         =   $$(RUSTINSTALLDIR)/lib
$(1)_INSTALLABLE        ?=  1

endef

## Common
define RUST_CRATE_COMMON

$(1)_DIRNAME            =   $$(RUSTSRCDIR)/$(1)
$(1)_DEPFILE            =   $$(RUSTBUILDDIR)/$(1).deps.mk
$(1)_DEPFILE_TEST       =   $$(RUSTBUILDDIR)/$(1).deps.test.mk
$(1)_TESTNAME           =   $$(RUSTBUILDDIR)/test_$(1)

ifeq ($$($(1)_TYPE),)
ifneq ($$(wildcard $$($(1)_DIRNAME)/main.rs),)
$(1)_TYPE               =   bin
else ifneq ($$(wildcard $$($(1)_DIRNAME)/lib.rs),)
$(1)_TYPE               =   lib
endif
endif

ifeq ($$($(1)_TYPE),bin)
$$(eval $$(call RUST_CRATE_BIN,$(1)))
else ifeq ($$($(1)_TYPE),lib)
$$(eval $$(call RUST_CRATE_LIB,$(1)))
else ifeq ($$($(1)_TYPE),)
$$(error No crate type for '$(1)')
else
$$(error Unknown crate type '$$($(1)_TYPE)' for '$(1)')
endif

$(1)_ROOT_TEST          =   $$($(1)_ROOT)
$(1)_NAMES              =   $$(addprefix $$($(1)_PREFIX),$$(shell $$(RUSTC) $$(RUSTCFLAGS) $$($(1)_RUSTCFLAGS) --crate-file-name $$($(1)_ROOT)))
$(1)_NAME               =   $$(firstword $$($(1)_NAMES))

build_$(1):             $$($(1)_NAME)

clean_$(1):
	rm -f $$($(1)_NAMES) $$($(1)_DEPFILE) $$($(1)_TESTNAME)

test_$(1):              $$($(1)_TESTNAME)
	@$$($(1)_TESTNAME)

bench_$(1):             $$($(1)_TESTNAME)
	@$$($(1)_TESTNAME) --bench

doc_$(1):
	$$(RUSTDOC) $$(RUSTDOCFLAGS) $$($(1)_ROOT)

ifeq ($$($(1)_INSTALLABLE),1)
install_$(1):           $$($(1)_NAME)
	@mkdir -p $$($(1)_INSTALLDIR)
	$(INSTALL) $$($(1)_NAMES) $$($(1)_INSTALLDIR)

uninstall_$(1):
	rm -f $$(foreach name,$$($(1)_NAMES),$$($(1)_INSTALLDIR)/$$(notdir $$(name)))
endif

$$($(1)_NAME):          $$($(1)_BUILD_DEPS)
	$$(RUSTC) $$(RUSTCFLAGS) $$($(1)_RUSTCFLAGS_BUILD) $$($(1)_RUSTCFLAGS) --dep-info $$($(1)_DEPFILE) $$($(1)_ROOT)
-include $$($(1)_DEPFILE)

$$($(1)_TESTNAME):      $$($(1)_BUILD_DEPS)
	@$$(RUSTC) $$(RUSTCFLAGS) $$($(1)_RUSTCFLAGS) --dep-info $$($(1)_DEPFILE_TEST) --test -o $$($(1)_TESTNAME) $$($(1)_ROOT_TEST)
-include $$($(1)_DEPFILE_TEST)

.PHONY all:             build_$(1)
.PHONY clean:           clean_$(1)
.PHONY test:            test_$(1)
.PHONY bench:           bench_$(1)
.PHONY doc:             doc_$(1)

ifeq ($$($(1)_INSTALLABLE),1)
.PHONY install:         install_$(1)
.PHONY uninstall:       uninstall_$(1)
endif

endef

## Utils
define RUST_CRATE_DEPEND
$$($(1)_NAMES):         $$($(2)_NAME)
endef

define CREATE_DIR
$(1):
	@mkdir -p $(1)

all test bench install: $(1)
endef

## Rules
define RUST_CRATE_RULES

$$(foreach crate,$$(RUSTCRATES),$$(eval $$(call RUST_CRATE_COMMON,$$(crate))))
$$(foreach crate,$$(RUSTCRATES),$$(eval $$(call RUST_CRATE_DEPEND,$$(crate),$$($$(crate)_CRATE_DEPS))))

endef

# Rules

all:
clean:
fclean:
test:
bench:
doc:
install:
uninstall:

$(eval $(call CREATE_DIR,$(RUSTBUILDDIR)))
$(eval $(call CREATE_DIR,$(RUSTLIBDIR)))

ifeq ($(RUSTAUTORULES),1)
$(eval $(call RUST_CRATE_RULES))
endif

fclean:                 clean

fclean_dirs:
	rm -rf $(RUSTLIBDIR) $(RUSTBUILDDIR) doc
.PHONY fclean:          fclean_dirs

rust-mk
=======

This make script intend to help Rusties to compile Rust programs with a Makefile.

Usage
-----

### Get source ###

```sh
git submodule add git://github.com/KokaKiwi/rust-mk.git
```

### Basic usage ###

This Makefile will compile a crate located in src/mycrate/{lib.rs,main.rs}

```make
RUSTCRATES          =   mycrate

include             rust-mk/rust.mk
```

### Advanced usage ###

```make
RUSTCRATES          =   mycrate mydep

mycrate_TYPE        =   bin         # Automatically detected if not specified.
mycrate_CRATE_DEPS  +=   mydep      # mydep will be build before mycrate.
mycrate_BUILD_DEPS  +=   libtest.a  # Raw dependency of libtest.a for mycrate.
mycrate_RUSTCFLAGS  +=  -g          # Add some custom flags as you want.

include             rust-mk/rust.mk
```

Rules
-----

`make all` - Make all crates.

`make clean` - Clean all targets.

`make fclean` - Clean all targets and delete build directories.

`make test` - Compile and run tests.

`make bench` - Compile and run bench.

`make doc` - Generate doc for crates.

`make install` - Install crates.

Special variables
-----------------

These special variables can be set, either by setting them in env or by passing them to make:

```sh
make <varname>=<varvalue>
```

### RUSTC ###

Default: `rustc`

Path to `rustc` executable.

### RUSTDOC ###

Default: `rustdoc`

Path to `rustdoc` executable.

### RUSTCFLAGS ###

Default: depending on others vars

Flags used to compile crates.

### RUSTDOCFLAGS ###

Default: nothing

Flags used to generate docs.

### RUSTDEBUG ###

Default: `0`

If set to `1`, activate debug flags (`-g`) else optimization flags will be activated (`--opt-level=3`)

### RUSTBUILDDIR ###

Default: `.rust`

This directory will be used to store build files (like test binaries).

### RUSTSRCDIR ###

Default: `src`

This directory is where crates must be find.

### RUSTLIBDIR ###

Default: `lib`

This directory is where library crates will be stored.

### RUSTINSTALLDIR ###

Default: `~/.rust`

This directory is where all crates will be installed.

License
-------

`rust-mk` is licensed under MIT license.

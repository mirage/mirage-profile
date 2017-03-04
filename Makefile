all: build

XEN=false

.PHONY: test doc build clean

build:
	ocaml pkg/pkg.ml build --with-xen ${XEN}

doc:
	topkg doc

test:
	ocaml pkg/pkg.ml build --with-xen ${XEN} --tests true
	ocaml pkg/pkg.ml test

clean:
	rm -rf _build

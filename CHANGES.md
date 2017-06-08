## 0.8.0 (2017-06-08)
- split into 3 ocamlfind and opam packages:
  - mirage-profile: generic code
  - mirage-profile-unix: Unix-specific library
  - mirage-profile-xen: Xen kernel specific library
- build with jbuilder
- release with topkg
- modernize travis configuration
- don't link client libraries against cstruct.ppx
- add "Async" thread type
- fix linking problem on Ubuntu 12.04

## 0.7.0 (2016-03-13)
- depend on cstruct.ppx (from >= 1.9.0) rather than cstruct.syntax
- improve usage instructions

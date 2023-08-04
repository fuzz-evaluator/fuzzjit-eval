cat << EOF > .mozconfig_cov
export CFLAGS="-fprofile-instr-generate -fcoverage-mapping"
export CXXFLAGS="-fprofile-instr-generate -fcoverage-mapping"
export LDFLAGS="-fprofile-instr-generate -fcoverage-mapping"

CC=clang-13
CXX=clang++-13
ac_add_options --disable-bootstrap
ac_add_options --disable-tests
ac_add_options --enable-application=js
ac_add_options --enable-optimize
ac_add_options --enable-debug
ac_add_options --disable-shared-js
ac_add_options --enable-fuzzing
ac_add_options --enable-gczeal
ac_add_options --enable-coverage

mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-covbuild
EOF

export MOZCONFIG=$PWD/.mozconfig_cov
./mach build

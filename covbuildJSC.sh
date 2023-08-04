export WEBKIT_OUTPUTDIR=CovBuild

./Tools/Scripts/build-jsc --jsc-only --debug --cmakeargs="-DENABLE_STATIC_JSC=ON -DCMAKE_C_COMPILER='/usr/bin/clang' -DCMAKE_CXX_COMPILER='/usr/bin/clang++' -DCMAKE_CXX_FLAGS='-fprofile-instr-generate -fcoverage-mapping -O3 -lrt'"

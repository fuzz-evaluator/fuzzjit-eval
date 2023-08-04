gn gen out/coveragebuild --args='use_clang_coverage=true is_component_build=false is_debug=false dcheck_always_on=true v8_static_library=true v8_enable_slow_dchecks=true v8_enable_v8_checks=true v8_enable_verify_heap=true v8_enable_verify_csa=true target_cpu="x64"'
ninja -C ./out/coveragebuild d8

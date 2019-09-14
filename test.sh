#!/bin/bash

set -e

if [[ "$1" == "--release" ]]; then
    export CHANNEL='release'
    cargo build --release
else
    export CHANNEL='debug'
    cargo build
fi

source config.sh

jit() {
    if [[ `uname` == 'Darwin' ]]; then
        # FIXME(#671) `dlsym` returns "symbol not found" for existing symbols on macOS.
        echo "[JIT] $1 (Ignored on macOS)"
    else
        echo "[JIT] $1"
        SHOULD_RUN=1 $RUSTC --crate-type bin -Cprefer-dynamic $2
    fi
}

rm -r target/out || true
mkdir -p target/out/clif

echo "[BUILD] mini_core"
$RUSTC example/mini_core.rs --crate-name mini_core --crate-type lib,dylib

echo "[BUILD] example"
$RUSTC example/example.rs --crate-type lib

JIT_ARGS="abc bcd" jit mini_core_hello_world example/mini_core_hello_world.rs

echo "[AOT] mini_core_hello_world"
$RUSTC example/mini_core_hello_world.rs --crate-name mini_core_hello_world --crate-type bin
./target/out/mini_core_hello_world abc bcd

echo "[AOT] arbitrary_self_types_pointers_and_wrappers"
$RUSTC example/arbitrary_self_types_pointers_and_wrappers.rs --crate-name arbitrary_self_types_pointers_and_wrappers --crate-type bin -Cpanic=abort
./target/out/arbitrary_self_types_pointers_and_wrappers

echo "[BUILD] sysroot"
time ./build_sysroot/build_sysroot.sh

$RUSTC example/std_example.rs --crate-name std_example --crate-type bin
./target/out/std_example

git clone https://github.com/rust-lang/rust.git --depth=1 || true
cd rust
#git checkout -- .
#git pull
export RUSTFLAGS=

cat > the_patch.patch <<EOF
From 681aa334c5c183538e77c660e5e2d4d0c79fe669 Mon Sep 17 00:00:00 2001
From: bjorn3 <bjorn3@users.noreply.github.com>
Date: Sat, 23 Feb 2019 14:55:44 +0100
Subject: [PATCH] Make suitable for cg_clif tests

---
 .gitmodules           | 10 ----------
 1 files changed, 0 insertions(+), 10 deletions(-)

diff --git a/.gitmodules b/.gitmodules
index b75e312d..aef8bc14 100644
--- a/.gitmodules
+++ b/.gitmodules
@@ -25,12 +25,6 @@
 [submodule "src/tools/miri"]
 	path = src/tools/miri
 	url = https://github.com/rust-lang/miri.git
-[submodule "src/doc/rust-by-example"]
-	path = src/doc/rust-by-example
-	url = https://github.com/rust-lang/rust-by-example.git
-[submodule "src/llvm-emscripten"]
-	path = src/llvm-emscripten
-	url = https://github.com/rust-lang/llvm.git
 [submodule "src/stdsimd"]
 	path = src/stdsimd
 	url = https://github.com/rust-lang-nursery/stdsimd.git
@@ -40,10 +34,6 @@
 [submodule "src/doc/edition-guide"]
 	path = src/doc/edition-guide
 	url = https://github.com/rust-lang-nursery/edition-guide.git
-[submodule "src/llvm-project"]
-	path = src/llvm-project
-	url = https://github.com/rust-lang/llvm-project.git
-	branch = rustc/8.0-2019-01-16
 [submodule "src/doc/embedded-book"]
 	path = src/doc/embedded-book
 	url = https://github.com/rust-embedded/book.git
--- a/src/tools/compiletest/src/main.rs
+++ b/src/tools/compiletest/src/main.rs
@@ -503,3 +503,4 @@
 pub fn test_opts(config: &Config) -> test::TestOpts {
     test::TestOpts {
+        exclude_should_panic: false,
         filter: config.filter.clone(),
--
2.11.0

EOF
#git apply the_patch.patch

rm config.toml || true

cat > config.toml <<EOF
[llvm]
enabled = false
[rust]
codegen-backends = []
[build]
local-rebuild = true
rustc = "$HOME/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/bin/rustc"
EOF

rm -r src/test/run-pass/{asm-*,abi-*,extern/,panic-runtime/,panics/,unsized-locals/,proc-macro/,threads-sendsync/,thinlto/,simd/} || true
for test in src/test/run-pass/**/*.rs; do
    if grep "ignore-emscripten" $test 2>&1 >/dev/null; then
        rm $test
    fi
done

#rm -r build/x86_64-unknown-linux-gnu/test || true
./x.py test --stage 0 src/test/run-pass/ \
    --rustc-args "-Zcodegen-backend=$(pwd)/../target/"$channel"/librustc_codegen_cranelift."$dylib_ext" --sysroot $(pwd)/../build_sysroot/sysroot -Cpanic=abort" \
    2>&1 | tee log.txt

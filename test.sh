#!/bin/bash
source config.sh

rm -r target/out || true
mkdir -p target/out/clif

echo "[BUILD] mini_core"
$RUSTC example/mini_core.rs --crate-name mini_core --crate-type dylib

echo "[BUILD] example"
$RUSTC example/example.rs --crate-type lib

echo "[JIT] mini_core_hello_world"
SHOULD_RUN=1 JIT_ARGS="abc bcd" $RUSTC --crate-type bin example/mini_core_hello_world.rs --cfg jit

echo "[AOT] mini_core_hello_world"
$RUSTC example/mini_core_hello_world.rs --crate-name mini_core_hello_world --crate-type bin
./target/out/mini_core_hello_world abc bcd

echo "[AOT] arbitrary_self_types_pointers_and_wrappers"
$RUSTC example/arbitrary_self_types_pointers_and_wrappers.rs --crate-name arbitrary_self_types_pointers_and_wrappers --crate-type bin
./target/out/arbitrary_self_types_pointers_and_wrappers

echo "[BUILD] sysroot"
time ./build_sysroot/build_sysroot.sh

echo "[BUILD+RUN] alloc_example"
$RUSTC example/alloc_example.rs --crate-type bin
./target/out/alloc_example

echo "[BUILD+RUN] std_example"
$RUSTC example/std_example.rs --crate-type bin
./target/out/std_example

echo "[BUILD] mod_bench"
$RUSTC example/mod_bench.rs --crate-type bin

# FIXME linker gives multiple definitions error on Linux
#echo "[BUILD] sysroot in release mode"
#./build_sysroot/build_sysroot.sh --release

COMPILE_MOD_BENCH_CLIF="$RUSTC example/mod_bench.rs --crate-type bin -O"
COMPILE_MOD_BENCH_CLIF_BASELINE="$COMPILE_MOD_BENCH_CLIF --crate-name mod_bench_clif_baseline"
COMPILE_MOD_BENCH_CLIF_PREOPT="PREOPT=1 $COMPILE_MOD_BENCH_CLIF --crate-name mod_bench_clif_preopt"
COMPILE_MOD_BENCH_CLIF_INLINE="$COMPILE_MOD_BENCH_CLIF -Zmir-opt-level=3 --crate-name mod_bench_clif_inline"
COMPILE_MOD_BENCH_CLIF_INLINE_PREOPT="PREOPT=1 $COMPILE_MOD_BENCH_CLIF -Zmir-opt-level=3 --crate-name mod_bench_clif_inline_preopt"
COMPILE_MOD_BENCH_LLVM_0="rustc example/mod_bench.rs --crate-type bin -Copt-level=0 -o target/out/mod_bench_llvm_0 -Cpanic=abort"
COMPILE_MOD_BENCH_LLVM_1="rustc example/mod_bench.rs --crate-type bin -Copt-level=1 -o target/out/mod_bench_llvm_1 -Cpanic=abort"
COMPILE_MOD_BENCH_LLVM_2="rustc example/mod_bench.rs --crate-type bin -Copt-level=2 -o target/out/mod_bench_llvm_2 -Cpanic=abort"
COMPILE_MOD_BENCH_LLVM_3="rustc example/mod_bench.rs --crate-type bin -Copt-level=3 -o target/out/mod_bench_llvm_3 -Cpanic=abort"

# Use 100 runs, because a single compilations doesn't take more than ~150ms, so it isn't very slow
hyperfine --runs 100 "$COMPILE_MOD_BENCH_CLIF_BASELINE" "$COMPILE_MOD_BENCH_CLIF_PREOPT" "$COMPILE_MOD_BENCH_CLIF_INLINE" "$COMPILE_MOD_BENCH_CLIF_INLINE_PREOPT" "$COMPILE_MOD_BENCH_LLVM_0" "$COMPILE_MOD_BENCH_LLVM_1" "$COMPILE_MOD_BENCH_LLVM_2" "$COMPILE_MOD_BENCH_LLVM_3"

echo
echo "[Bench] mod_bench"
hyperfine ./target/out/mod_bench_{clif_{baseline,preopt,inline,inline_preopt},llvm_{0,1,2,3}}

cat target/out/log.txt | sort | uniq -c

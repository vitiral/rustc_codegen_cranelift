// Adapted from https://github.com/sunfishcode/mir2cranelift/blob/master/rust-examples/nocore-hello-world.rs

#![feature(no_core, unboxed_closures, start, lang_items, box_syntax, slice_patterns, never_type, linkage, thread_local)]
#![no_core]
#![allow(dead_code, non_camel_case_types)]

extern crate mini_core;

use mini_core::*;
use mini_core::libc::*;

unsafe extern "C" fn my_puts(s: *const u8) {
    puts(s);
}

#[lang = "termination"]
trait Termination {
    fn report(self) -> i32;
}

impl Termination for () {
    fn report(self) -> i32 {
        unsafe {
            NUM = 6 * 7 + 1 + (1u8 == 1u8) as u8; // 44
            *NUM_REF as i32
        }
    }
}

trait SomeTrait {
    fn object_safe(&self);
}

impl SomeTrait for &'static str {
    fn object_safe(&self) {
        unsafe {
            puts(*self as *const str as *const u8);
        }
    }
}

struct NoisyDrop {
    text: &'static str,
    inner: NoisyDropInner,
}

struct NoisyDropInner;

impl Drop for NoisyDrop {
    fn drop(&mut self) {
        unsafe {
            puts(self.text as *const str as *const u8);
        }
    }
}

impl Drop for NoisyDropInner {
    fn drop(&mut self) {
        unsafe {
            puts("Inner got dropped!\0" as *const str as *const u8);
        }
    }
}

impl SomeTrait for NoisyDrop {
    fn object_safe(&self) {}
}

enum Ordering {
    Less = -1,
    Equal = 0,
    Greater = 1,
}

#[lang = "start"]
fn start<T: Termination + 'static>(
    main: fn() -> T,
    argc: isize,
    argv: *const *const u8,
) -> isize {
    main();//.report();
    0
}

static mut NUM: u8 = 6 * 7;
static NUM_REF: &'static u8 = unsafe { &NUM };

macro_rules! assert {
    ($e:expr) => {
        if !$e {
            panic(&(stringify!(! $e), file!(), line!(), 0));
        }
    };
}

macro_rules! assert_eq {
    ($l:expr, $r: expr) => {
        if $l != $r {
            panic(&(stringify!($l != $r), file!(), line!(), 0));
        }
    }
}

struct Unique<T: ?Sized> {
    pointer: *const T,
    _marker: PhantomData<T>,
}

impl<T: ?Sized, U: ?Sized> CoerceUnsized<Unique<U>> for Unique<T> where T: Unsize<U> {}

fn take_f32(_f: f32) {}
fn take_unique(_u: Unique<()>) {}

fn return_u128_pair() -> (u128, u128) {
    (0, 0)
}

fn call_return_u128_pair() {
    return_u128_pair();
}

#[repr(C)]
enum c_void {
    _1,
    _2,
}

type c_int = i32;
type c_ulong = u64;

type pthread_t = c_ulong;

#[repr(C)]
struct pthread_attr_t {
    __size: [u64; 7],
}

#[link(name = "pthread")]
extern "C" {
    fn pthread_attr_init(attr: *mut pthread_attr_t) -> c_int;

    fn pthread_create(
        native: *mut pthread_t,
        attr: *const pthread_attr_t,
        f: extern "C" fn(_: *mut c_void) -> *mut c_void,
        value: *mut c_void
    ) -> c_int;

    fn pthread_join(
        native: pthread_t,
        value: *mut *mut c_void
    ) -> c_int;
}

#[thread_local]
static mut TLS: u8 = 42;

extern "C" fn mutate_tls(_: *mut c_void) -> *mut c_void {
    unsafe { TLS = 0; }
    0 as *mut c_void
}

fn main() {
    unsafe {
        let mut attr: pthread_attr_t = intrinsics::init();
        let mut thread: pthread_t = 0;

        if pthread_attr_init(&mut attr) != 0 {
            pthread_err();
        }

        if pthread_create(&mut thread, &attr, mutate_tls, 0 as *mut c_void) != 0 {
            pthread_err();
        }

        let mut res = 0 as *mut c_void;
        pthread_join(thread, &mut res);

        // TLS of main thread must not have been changed by the other thread.
        assert_eq!(TLS, 42);
    }
}

fn pthread_err() {
    assert_eq!(0, 1);
}

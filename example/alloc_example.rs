#![feature(start, box_syntax, core_intrinsics, alloc, alloc_error_handler)]
//#![no_std]

/*
extern crate alloc;
extern crate alloc_system;

use alloc::prelude::*;

use alloc_system::System;

#[global_allocator]
static ALLOC: System = System;
*/

#[link(name = "c")]
extern "C" {
    fn puts(s: *const u8);
}

/*
#[panic_handler]
fn panic_handler(_: &core::panic::PanicInfo) -> ! {
    unsafe {
        core::intrinsics::abort();
    }
}

#[alloc_error_handler]
fn alloc_error_handler(_: alloc::alloc::Layout) -> ! {
    unsafe {
        core::intrinsics::abort();
    }
}
*/

//#[start]
//fn main(_argc: isize, _argv: *const *const u8) -> isize {
fn main() {
    let world: Box<&str> = box "Hello World!\0";
    unsafe {
        puts(*world as *const str as *const u8);
    }

    let rc = std::rc::Rc::new(||()) as std::rc::Rc<Fn()>;

    ABC.with(|abc| *abc);

    //0
}

thread_local!(static ABC: u8 = 0);

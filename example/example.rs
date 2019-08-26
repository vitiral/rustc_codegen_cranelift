#![feature(no_core, unboxed_closures)]
#![no_core]
#![allow(dead_code)]

extern crate mini_core;

use mini_core::*;

#[repr(C)]
pub struct Sel {
    ptr: *const (),
}

extern {
    pub fn sel_registerName(name: *const i8) -> Sel;
}

/*pub unsafe fn call_register_name(res: &mut Sel) {
    *res = sel_registerName(0 as *const _)
}*/

pub extern "rust-call" fn abc(s: (), args: (u8, bool)) -> impl FnOnce(i32, i8) {
    |_, _| loop {}
}

pub fn bcd() {
    abc((), (0, false))(0, 0);
}

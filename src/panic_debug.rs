use std::cell::Cell;

thread_local! {
    static EXPECTED_FATAL_ERROR: Cell<bool> = Cell::new(false);
}

pub fn expected_fatal_error(sess: &rustc::session::Session, span: Option<syntax::source_map::Span>, msg: impl AsRef<str>) -> ! {
    EXPECTED_FATAL_ERROR.with(|expected_fatal_error| {
        expected_fatal_error.set(true);
    });
    if let Some(span) = span {
        sess.span_fatal(span, msg.as_ref());
    } else {
        sess.fatal(msg.as_ref());
    }
}

pub struct PrintOnPanic<F: Fn() -> String>(pub F);
impl<F: Fn() -> String> Drop for PrintOnPanic<F> {
    fn drop(&mut self) {
        if std::thread::panicking() && !EXPECTED_FATAL_ERROR.with(Cell::get) {
            println!("{}", (self.0)());
        }
    }
}

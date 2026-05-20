//! Local shadow of `log` for the guix-import-crate truncation reproducer.
//! Not a real `log` implementation — exists only to occupy `name = "log",
//! version = "0.4.22"` in the workspace with divergent dependencies, so
//! cargo emits two `[[package]]` blocks in Cargo.lock for the same
//! name+version (one path, one registry).

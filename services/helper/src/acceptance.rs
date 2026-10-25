mod service;

#[cfg(windows)]
fn main() -> anyhow::Result<()> {
    service::hub::acceptance_stdio()
}

#[cfg(not(windows))]
fn main() {
    eprintln!("isolated Helper acceptance requires Windows");
    std::process::exit(2);
}

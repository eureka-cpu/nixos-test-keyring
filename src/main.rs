#[tokio::main]
async fn main() -> Result<(), keyring::Error> {
    let subscriber = tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .with_writer(std::io::stdout)
        .pretty()
        .finish();
    tracing::subscriber::set_global_default(subscriber).expect("Could not set up global logger");

    // Wait for keyring to be unlocked.
    std::thread::sleep(std::time::Duration::from_secs(4));

    // Looping to simulate a running daemon.
    loop {
        match keyring::Entry::new("service-name", "user-name") {
            Ok(entry) => match entry.set_password("password") {
                Ok(_) => {
                    tracing::info!("successfully set password");
                    match entry.get_password() {
                        Ok(password) => tracing::info!("successfully got password: {password}"),
                        Err(err) => tracing::error!("failed to get password: {err:?}"),
                    }
                }
                Err(err) => tracing::error!("failed while setting password: {err:?}"),
            },
            Err(err) => tracing::error!("failed while creating entry: {err:?}"),
        }
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}

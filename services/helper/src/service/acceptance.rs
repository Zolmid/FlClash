use super::*;
use std::io::Write;

struct Cleanup;

impl Drop for Cleanup {
    fn drop(&mut self) {
        release_managed_core_on_shutdown();
    }
}

#[derive(Deserialize)]
#[serde(tag = "operation", rename_all = "camelCase", deny_unknown_fields)]
enum Request {
    Start {
        address: String,
        #[serde(rename = "sessionId")]
        session_id: String,
    },
    Stop {
        #[serde(rename = "sessionId")]
        session_id: String,
    },
}

pub(super) fn run() -> anyhow::Result<()> {
    ensure_core_sha256_configured()?;
    let _cleanup = Cleanup;
    let runtime = tokio::runtime::Runtime::new()?;
    let mut input = io::stdin().lock();
    let mut output = io::stdout().lock();
    loop {
        let mut line = String::new();
        if input
            .by_ref()
            .take(MAX_REQUEST_BODY_BYTES + 2)
            .read_line(&mut line)?
            == 0
        {
            return Ok(());
        }
        anyhow::ensure!(
            line.len() <= MAX_REQUEST_BODY_BYTES as usize && line.ends_with('\n'),
            "invalid acceptance frame"
        );
        let response = match serde_json::from_str::<Request>(&line)? {
            Request::Start {
                address,
                session_id,
            } => start(StartParams {
                address,
                session_id,
            }),
            Request::Stop { session_id } => stop_core(StopParams { session_id }),
        };
        let status = response.status().as_u16();
        let body = runtime.block_on(warp::hyper::body::to_bytes(response.into_body()))?;
        let body: serde_json::Value = serde_json::from_slice(&body)?;
        serde_json::to_writer(
            &mut output,
            &serde_json::json!({"status": status, "body": body}),
        )?;
        writeln!(output)?;
        output.flush()?;
    }
}

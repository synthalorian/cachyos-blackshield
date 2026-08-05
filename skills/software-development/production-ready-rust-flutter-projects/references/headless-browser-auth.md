# Headless Browser Auth with chromiumoxide (0.8)

Complete reference for using headless Chrome to bypass Cloudflare Turnstile and scrape JS-heavy login pages from Rust.

## Project Structure

```
server/src/scraping/
├── mod.rs       # pub mod auth; pub mod pledges;
├── auth.rs      # RsiAuth struct + login flow
└── pledges.rs   # Post-login data scraping with reqwest
```

## Full Auth Module

### `scraping/auth.rs`

```rust
use std::time::Duration;
use chromiumoxide::browser::{Browser, BrowserConfig, HeadlessMode};
use chromiumoxide::Page;
use futures::StreamExt;
use serde::{Deserialize, Serialize};
use tokio::time::sleep;

pub struct RsiAuth {
    chrome_path: String,
    base_url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RsiSession {
    pub username: String,
    pub rsi_token: String,
    pub cookies_json: String,  // Serialized Vec<Cookie>
    pub expires_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RsiLoginResult {
    Success(RsiSession),
    Requires2fa,
    Failed(String),
}

impl RsiAuth {
    pub fn new(chrome_path: &str, base_url: &str) -> Self {
        Self {
            chrome_path: chrome_path.to_string(),
            base_url: base_url.to_string(),
        }
    }

    pub async fn login(&self, username: &str, password: &str) -> anyhow::Result<RsiLoginResult> {
        let config = BrowserConfig::builder()
            .headless_mode(HeadlessMode::New)
            .no_sandbox()
            .chrome_executable(&self.chrome_path)
            .window_size(1920, 1080)
            .build()
            .map_err(|e| anyhow::anyhow!("Browser config failed: {}", e))?;

        let (mut browser, mut handler) = Browser::launch(config)
            .await
            .map_err(|e| anyhow::anyhow!("Launch failed: {}", e))?;

        let handle = tokio::spawn(async move {
            while let Some(event) = handler.next().await {
                if let Err(e) = event {
                    tracing::debug!("Browser event: {:?}", e);
                }
            }
        });

        let result = self.perform_login(&browser, username, password).await;

        if let Err(e) = browser.close().await {
            tracing::warn!("Close error: {}", e);
        }
        handle.abort();
        result
    }

    async fn perform_login(&self, browser: &Browser, username: &str, password: &str)
        -> anyhow::Result<RsiLoginResult>
    {
        let login_url = format!("{}/login", self.base_url);
        let page = browser.new_page(&login_url).await?;
        sleep(Duration::from_secs(3)).await;  // Let JS/CSS load

        // Check if already logged in
        if let Ok(Some(url)) = page.url().await {
            if !url.contains("login") && !url.contains("signin") {
                return self.extract_session(&page, username).await;
            }
        }

        let _ = page.enable_stealth_mode().await;

        // Fill username — fallback chain
        let username_filled =
            if let Ok(el) = page.find_element("input[name='username']").await {
                el.focus().await?; el.type_str(username).await.is_ok()
            } else if let Ok(el) = page.find_element("#login-username").await {
                el.focus().await?; el.type_str(username).await.is_ok()
            } else if let Ok(inputs) = page.find_elements("input[type='text']").await {
                inputs.first().map(|i| i.focus().await).is_some()
                    && inputs.first().map(|i| i.type_str(username).await.is_ok()).unwrap_or(false)
            } else { false };

        sleep(Duration::from_millis(300)).await;

        // Fill password — fallback chain
        let password_filled =
            if let Ok(el) = page.find_element("input[name='password']").await {
                el.focus().await?; el.type_str(password).await.is_ok()
            } else if let Ok(el) = page.find_element("#login-password").await {
                el.focus().await?; el.type_str(password).await.is_ok()
            } else if let Ok(inputs) = page.find_elements("input[type='password']").await {
                inputs.first().map(|i| i.focus().await).is_some()
                    && inputs.first().map(|i| i.type_str(password).await.is_ok()).unwrap_or(false)
            } else { false };

        sleep(Duration::from_millis(500)).await;

        // Click submit — fallback chain
        let mut clicked = false;
        if let Ok(btn) = page.find_element("button[type='submit']").await {
            btn.click().await?; clicked = true;
        } else if let Ok(btn) = page.find_element("input[type='submit']").await {
            btn.click().await?; clicked = true;
        } else if let Ok(btns) = page.find_elements("button").await {
            if let Some(btn) = btns.last() {
                btn.click().await?; clicked = true;
            }
        }
        if !clicked {
            let _ = page.evaluate(
                r#"document.querySelector('form')?.requestSubmit()"#
            ).await;
        }

        // Wait for login result + Turnstile
        sleep(Duration::from_secs(5)).await;

        // Check result
        if let Ok(Some(url)) = page.url().await {
            if !url.contains("login") && !url.contains("challenge") {
                return self.extract_session(&page, username).await;
            }
            if url.contains("2fa") || url.contains("two-factor") {
                return Ok(RsiLoginResult::Requires2fa);
            }
            if url.contains("turnstile") || url.contains("captcha") || url.contains("challenge") {
                return Ok(RsiLoginResult::Failed(
                    "CAPTCHA challenge detected; try manual login first.".into()
                ));
            }
        }

        // Additional wait for async redirect
        sleep(Duration::from_secs(3)).await;
        if let Ok(Some(url)) = page.url().await {
            if !url.contains("login") {
                return self.extract_session(&page, username).await;
            }
        }

        Ok(RsiLoginResult::Failed("Login failed — check credentials.".into()))
    }

    async fn extract_session(&self, page: &Page, username: &str)
        -> anyhow::Result<RsiLoginResult>
    {
        sleep(Duration::from_secs(1)).await;
        let cookies = page.get_cookies().await?;

        if cookies.is_empty() {
            return Ok(RsiLoginResult::Failed("No cookies received.".into()));
        }

        let mut rsi_token = String::new();
        for cookie in &cookies {
            if cookie.name == "Rsi-Token" || cookie.name == "rsi_token" {
                rsi_token = cookie.value.clone();
            }
        }

        let cookies_json = serde_json::to_string(&cookies)
            .unwrap_or_else(|_| {
                cookies.iter().map(|c| format!("{}={}", c.name, c.value)).collect::<Vec<_>>().join("; ")
            });

        let expires = chrono::Utc::now()
            .checked_add_signed(chrono::Duration::hours(24))
            .unwrap()
            .to_rfc3339();

        Ok(RsiLoginResult::Success(RsiSession {
            username: username.to_string(),
            rsi_token,
            cookies_json,
            expires_at: expires,
        }))
    }
}
```

## API Handler Pattern

### `api/auth.rs`

```rust
use axum::{Json, extract::State, http::StatusCode};
use uuid::Uuid;
use crate::scraping::auth::{RsiAuth, RsiLoginResult};

pub async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (StatusCode, Json<serde_json::Value>)> {
    let chrome_path = std::env::var("CHROME_PATH")
        .unwrap_or_else(|_| "/usr/bin/chromium".to_string());

    let auth = RsiAuth::new(&chrome_path, &state.config.rsi.base_url);

    match auth.login(&req.username, &req.password).await {
        Ok(RsiLoginResult::Success(session)) => {
            let session_id = Uuid::new_v4().to_string();
            sqlx::query("INSERT INTO sessions (id, username, rsi_token, expires_at) VALUES (?, ?, ?, ?)")
                .bind(&session_id).bind(&session.username)
                .bind(&session.cookies_json).bind(&session.expires_at)
                .execute(&state.db).await?;

            Ok(Json(LoginResponse {
                success: true,
                session_id: Some(session_id),
                message: "Logged in successfully".into(),
                requires_2fa: false,
            }))
        }
        Ok(RsiLoginResult::Requires2fa) => {
            Ok(Json(LoginResponse {
                success: true, requires_2fa: true,
                session_id: None,
                message: "2FA required".into(),
            }))
        }
        Ok(RsiLoginResult::Failed(msg)) => {
            Err((StatusCode::UNAUTHORIZED, Json(serde_json::json!({
                "success": false, "message": msg
            }))))
        }
        Err(e) => {
            Err((StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({
                "success": false, "message": format!("Login error: {}", e)
            }))))
        }
    }
}
```

## Database Schema

```sql
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    rsi_token TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL
);
```

## Session Renewal Strategy

- Sessions expire after 24h (configurable)
- On `401 Unauthorized` from Flutter, prompt re-login
- Don't store credentials — only session cookies

## Reference

- **Source**: sc-synthesis-server session (2026-05-15) — SC:Synthesis Star Citizen companion app
- **chromiumoxide crate**: https://crates.io/crates/chromiumoxide (0.8.x)
- **Chrome DevTools Protocol**: https://chromedevtools.github.io/devtools-protocol/

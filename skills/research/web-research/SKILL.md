---
name: web-research
description: Browser-based research for extracting info from dynamic, JS-heavy, international web platforms. Covers pricing research, docs mining, content buried behind accordions/tabs/lazy-loading.
triggers:
  - Researching product pricing, especially on Chinese/international platforms
  - Pages where browser_snapshot returns empty, truncated, or no interactive elements
  - JS-heavy single-page apps hiding content behind accordions, tabs, or click-to-expand
  - Comparing AI model capabilities, pricing, and performance across providers
workflow:
  - Phase 1 Recon: browser_navigate(url) then browser_snapshot(). If empty, use browser_vision().
  - Phase 2 Search fallback: When browser search engines (Google, Reddit, Bing, Zhihu) return CAPTCHAs or empty pages, use DuckDuckGo via terminal+curl as a lightweight alternative.
  - Phase 3 Direct navigation: For known data sources (Artificial Analysis, official docs, platform sites), navigate directly rather than searching first. On Chinese platforms, check both the consumer app URL and the API platform URL — they're often separate entities.
  - Phase 4 Extract hidden content: Use browser_console with JS querySelectorAll on accordion/tab panels to grab their textContent.
  - Phase 5 Navigate sub-pages: Try /pricing, /rate-limits, /docs, /faq. Check actual URL after redirects.
  - Phase 6 Verify: Cross-reference across pages. Check FAQs for concurrency, peak-hour throttling, quota gotchas. For model comparisons, use Artificial Analysis for independent benchmarks on intelligence index, speed, and pricing.
  - Phase 7 Cross-session recall: Before diving into research, use session_search() to check if this topic was already researched in a previous session — saves redundant work.
pitfalls:
  - DDG is a dead end everywhere (2026-08) — html/lite endpoints CAPTCHA curl AND browser; duckduckgo.com main site LOADS in-browser but serves a shell with ZERO organic results (results API soft-blocked). Do not retry DDG without new evidence.
  - PRIMARY SEARCH ORDER — (1) Bing via browser_navigate + browser_console extract '#b_results li.b_algo h2 a' (works, but weak on niche/gaming queries, rephrase often); (2) game-specific topics → Steam Community discussion search at steamcommunity.com/app/APPID/discussions/search/?q=... (renders fine in browser, high signal); (3) GitHub api.github.com search + raw.githubusercontent for files/data (zero bot walls).
  - Cloudflare-walled to both curl and browser — wiki.albiononline.com, pcgamingwiki.com. Google search CAPTCHAs. Reddit CAPTCHAs. Use site:reddit.com / site:pcgamingwiki.com queries on Bing to read snippets instead.
  - For structured game/software data, skip search and use raw.githubusercontent.com / api.github.com — no bot walls. Albion Online live data for example lives at github.com/ao-data/ao-bin-dumps (items.xml maps weapons to spells, spells.json has mechanics, localization.xml has display names/descriptions). Download with curl, parse locally.
  - wiki.albiononline.com is Cloudflare-walled to both curl AND the browser (challenge page). albiondatabase.com loads in browser but has sparse weapon coverage.
  - Chinese platforms (bigmodel.cn, platform.kimi.ai) use JS-heavy SPAs that render blank. Try browser_vision first.
  - browser_snapshot truncates accordion/tab content. Always use browser_console JS to extract full text.
  - stealth_warning in nav result means bot detection active, content may be unreliable.
  - Check all billing toggles (monthly vs quarterly vs yearly). Different pricing per cycle.
  - Empty document.title means JS failed to execute, not that the page is empty.
  - DuckDuckGo and other search engines may serve CAPTCHAs from terminal+curl too. Try different User-Agent headers or switch to direct URL navigation. Progressive blocking is common — first query works, second fails.
  - Reddit consistently blocks automated browsers (both old.reddit.com and www.reddit.com) with CAPTCHAs. Do not rely on Reddit search working. Try `site:reddit.com` queries on search engines instead.
  - Zhihu also blocks non-logged-in browsers. These platforms require a logged-in session or CAPTCHA solving — no workaround via browser tools.
  - Chinese AI platform URLs redirect unexpectedly. bigmodel.cn's consumer chat product is at chatglm.cn, not at bigmodel.cn. Kimi's consumer app is at kimi.com, API at platform.kimi.ai. Both are different products from different subdomains.
  - Kimi Code kimi.com/code page is JS-heavy but CAN render in browser_navigate. If it fails on first attempt, retry — the page sometimes loads on second attempt after cold cache.
examples:
  - GLM Coding Plan bigmodel.cn: pricing in CNY, concurrency in FAQ accordion, needed JS eval for full answer
  - Kimi API platform.kimi.ai: pay-per-token with rate limits scaling by cumulative spend in clear table
  - Kimi Code kimi.com/code: JS-heavy SPA that loaded on retry with subscription tiers visible
  - Artificial Analysis artificialanalysis.ai: reliable benchmark data for model-to-model comparisons
---

## Instructions

When researching product or service pricing on dynamic web platforms:

1. **Try direct navigation first** — for known platforms, navigate straight to their pricing/docs page before searching. For Chinese AI platforms, check both consumer and API subdomains.

2. **Use DuckDuckGo as search fallback** — when Google, Bing, or Reddit hit CAPTCHAs, use `curl -sL https://html.duckduckgo.com/html/?q=<query> -H "User-Agent: Mozilla/5.0"` from terminal. Parse the response HTML for `uddg=` URL parameters to find result links.

3. **Start with browser_navigate** and check the snapshot. If the page renders blank or has minimal content, use browser_vision to visually inspect what's there before giving up. Some JS-heavy pages load on retry.

4. **Click through navigation** to find pricing pages. Common paths: /pricing, /plans, /subscription. For API platforms, look for platform.* subdomains.

5. **Extract hidden content** by clicking accordion/tab elements, then reading the browser_console output. Many Chinese platforms (bigmodel.cn, platform.kimi.ai) hide critical details like concurrency limits and rate quotas behind collapsible FAQ sections.

6. **Check browser_console for JS errors** that indicate rendering failures or bot detection. Sites that fail completely (blank page, empty title) may need curl or alternative access methods.

7. **Cross-reference with independent sources** — for AI model comparisons especially, Artificial Analysis (artificialanalysis.ai) provides reliable benchmark data across intelligence, speed, pricing, and context windows. Use it to validate claims on official pricing pages.

8. **Check previous sessions** — use session_search() to see if similar research was done before. Avoid re-doing work.

9. **Save key findings** and offer to store them in memory or as a skill reference file. Knowledge of which platform offers what structure (subscription vs pay-per-token, concurrency limits, peak-hour policies) is valuable across sessions.

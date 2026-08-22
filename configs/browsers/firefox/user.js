// Synthwave '84 — Firefox prefs required for the chrome theme
// Deployed by cachyos-blackshield install.sh into every Firefox profile.

// REQUIRED: makes Firefox read chrome/userChrome.css + chrome/userContent.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Match KDE dark scheme so native widgets/dialogs don't flash white
user_pref("layout.css.prefers-color-scheme.content-override", 0);

// Dark devtools to match
user_pref("devtools.theme", "dark");

// Keep new tab page on the themed about:newtab (userContent.css styles it)
user_pref("browser.newtabpage.enabled", true);

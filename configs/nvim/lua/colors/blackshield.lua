-- ═══════════════════════════════════════════════════════════
--  Blackshield Mercenary — blood & steel for nvim 🛡️
--  Black steel, blood-red cross potent. Caerleon after dark.
-- ═══════════════════════════════════════════════════════════

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") then vim.cmd("syntax reset") end
vim.g.colors_name = "blackshield"

local c = {
  void     = "#070709",
  iron     = "#101014",
  gunmetal = "#16161C",
  element  = "#1E1E25",
  steel    = "#26262E",
  steel_hi = "#52525E",
  edge     = "#6E6E7C",
  blood    = "#C1121F",
  ember    = "#E5383B",
  dried    = "#700000",
  parch    = "#D8D3C8",
  bone     = "#F5F1E8",
  ash      = "#8A8F98",
  olive    = "#6A994E",
  olive_hi = "#8FBF6F",
  brass    = "#C9A227",
  brass_hi = "#E3C558",
  blue     = "#5B7FA6",
  blue_hi  = "#7FA3CC",
  teal     = "#4E8F8B",
  teal_hi  = "#74B8B4",
}

local hl = function(group, opts) vim.api.nvim_set_hl(0, group, opts) end

-- ── UI chrome ──────────────────────────────────────────────
hl("Normal",          { fg = c.parch, bg = c.iron })
hl("NormalFloat",     { fg = c.parch, bg = c.gunmetal })
hl("FloatBorder",     { fg = c.blood, bg = c.gunmetal })
hl("FloatTitle",      { fg = c.ember, bg = c.gunmetal, bold = true })
hl("Cursor",          { fg = c.iron, bg = c.ember })
hl("CurSearch",       { fg = c.iron, bg = c.ember, bold = true })
hl("CursorLine",      { bg = c.gunmetal })
hl("CursorColumn",    { bg = c.gunmetal })
hl("LineNr",          { fg = c.steel_hi })
hl("CursorLineNr",    { fg = c.ember, bold = true })
hl("SignColumn",      { bg = c.iron })
hl("WinSeparator",    { fg = c.steel, bg = c.iron })
hl("VertSplit",       { fg = c.steel, bg = c.iron })
hl("Visual",          { bg = c.dried })
hl("VisualNOS",       { bg = c.dried })
hl("Search",          { fg = c.iron, bg = c.brass })
hl("IncSearch",       { fg = c.iron, bg = c.ember })
hl("Substitute",      { fg = c.iron, bg = c.blood })
hl("StatusLine",      { fg = c.parch, bg = c.gunmetal })
hl("StatusLineNC",    { fg = c.ash, bg = c.gunmetal })
hl("TabLine",         { fg = c.ash, bg = c.gunmetal })
hl("TabLineFill",     { bg = c.iron })
hl("TabLineSel",      { fg = c.iron, bg = c.blood, bold = true })
hl("Pmenu",           { fg = c.parch, bg = c.gunmetal })
hl("PmenuSel",        { fg = c.bone, bg = c.blood })
hl("PmenuKind",       { fg = c.ash, bg = c.gunmetal })
hl("PmenuExtra",      { fg = c.edge, bg = c.gunmetal })
hl("PmenuSbar",       { bg = c.steel })
hl("PmenuThumb",      { bg = c.steel_hi })
hl("MatchParen",      { fg = c.ember, bg = c.gunmetal, bold = true })
hl("ColorColumn",     { bg = c.gunmetal })
hl("Conceal",         { fg = c.ash })
hl("Directory",       { fg = c.blue_hi })
hl("Title",           { fg = c.ember, bold = true })
hl("ErrorMsg",        { fg = c.ember, bold = true })
hl("WarningMsg",      { fg = c.brass })
hl("MoreMsg",         { fg = c.olive_hi })
hl("ModeMsg",         { fg = c.brass })
hl("Question",        { fg = c.teal_hi })
hl("SpecialKey",      { fg = c.steel_hi })
hl("NonText",         { fg = c.steel })
hl("Whitespace",      { fg = c.steel })
hl("EndOfBuffer",     { fg = c.iron })
hl("QuickFixLine",    { bg = c.element })
hl("Folded",          { fg = c.ash, bg = c.gunmetal })
hl("FoldColumn",      { fg = c.steel_hi, bg = c.iron })

-- ── Syntax ─────────────────────────────────────────────────
hl("Comment",    { fg = c.edge, italic = true })
hl("Constant",   { fg = c.brass_hi })
hl("String",     { fg = c.olive_hi })
hl("Character",  { fg = c.olive_hi })
hl("Number",     { fg = c.brass_hi })
hl("Boolean",    { fg = c.ember })
hl("Float",      { fg = c.brass_hi })
hl("Identifier", { fg = c.parch })
hl("Function",   { fg = c.blue_hi })
hl("Statement",  { fg = c.ember })
hl("Keyword",    { fg = c.ember })
hl("Conditional",{ fg = c.ember })
hl("Repeat",     { fg = c.ember })
hl("Label",      { fg = c.brass })
hl("Operator",   { fg = c.blood })
hl("Exception",  { fg = c.ember, bold = true })
hl("PreProc",    { fg = c.blood })
hl("Include",    { fg = c.blood })
hl("Define",     { fg = c.blood })
hl("Macro",      { fg = c.ember })
hl("Type",       { fg = c.brass })
hl("StorageClass",{ fg = c.brass })
hl("Structure",  { fg = c.brass })
hl("Typedef",    { fg = c.brass })
hl("Special",    { fg = c.teal_hi })
hl("SpecialChar",{ fg = c.teal_hi })
hl("Tag",        { fg = c.ember })
hl("Delimiter",  { fg = c.ash })
hl("Underlined", { fg = c.blue_hi, underline = true })
hl("Bold",       { bold = true })
hl("Italic",     { italic = true })
hl("Error",      { fg = c.bone, bg = c.dried })
hl("Todo",       { fg = c.brass, bg = c.gunmetal, bold = true })

-- ── Diagnostics ────────────────────────────────────────────
hl("DiagnosticError",            { fg = c.ember })
hl("DiagnosticWarn",             { fg = c.brass })
hl("DiagnosticInfo",             { fg = c.blue_hi })
hl("DiagnosticHint",             { fg = c.teal_hi })
hl("DiagnosticUnnecessary",      { fg = c.steel_hi })
hl("DiagnosticVirtualTextError", { fg = c.ember })
hl("DiagnosticVirtualTextWarn",  { fg = c.brass })
hl("DiagnosticVirtualTextInfo",  { fg = c.blue_hi })
hl("DiagnosticVirtualTextHint",  { fg = c.teal_hi })
hl("DiagnosticUnderlineError",   { sp = c.ember, underline = true })
hl("DiagnosticUnderlineWarn",    { sp = c.brass, underline = true })
hl("DiagnosticUnderlineInfo",    { sp = c.blue_hi, underline = true })
hl("DiagnosticUnderlineHint",    { sp = c.teal_hi, underline = true })

-- ── Diffs & git ────────────────────────────────────────────
hl("DiffAdd",      { fg = c.olive_hi, bg = "#14251A" })
hl("DiffDelete",   { fg = c.ember, bg = "#2E0A0D" })
hl("DiffChange",   { fg = c.brass_hi, bg = "#241F0E" })
hl("DiffText",     { fg = c.iron, bg = c.brass })
hl("Added",        { fg = c.olive_hi })
hl("Removed",      { fg = c.ember })
hl("Changed",      { fg = c.brass_hi })
hl("GitSignsAdd",    { fg = c.olive })
hl("GitSignsChange", { fg = c.brass })
hl("GitSignsDelete", { fg = c.ember })

-- ── LSP / navigation ───────────────────────────────────────
hl("LspReferenceText",  { bg = c.element })
hl("LspReferenceRead",  { bg = c.element })
hl("LspReferenceWrite", { bg = c.element })
hl("LspInlayHint",      { fg = c.steel_hi, italic = true })
hl("SnippetTabstop",    { bg = c.element })

-- ── Built-in terminal ANSI (matches kitty/alacritty/ghostty) ──
local term = {
  c.iron, c.blood, c.olive, c.brass, c.blue, c.dried, c.teal, c.parch,
  c.steel, c.ember, c.olive_hi, c.brass_hi, c.blue_hi, c.ember, c.teal_hi, c.bone,
}
for i, col in ipairs(term) do
  vim.g["terminal_color_" .. (i - 1)] = col
end

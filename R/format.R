#' navreport HTML output format
#'
#' An R Markdown output format that renders a multi-level navigable HTML
#' document with lazy chart loading. Similar to flexdashboard but supports
#' unlimited nesting levels and defers chart rendering until the page is
#' visited, enabling fast open times even with hundreds of charts.
#'
#' @param theme Character. One of "navy_teal" (default), "dark", "light",
#'   "academic", or "corporate".
#' @param primary_color Optional hex color to override theme primary color.
#' @param accent_color Optional hex color to override theme accent color.
#' @param font_heading Font family for headings (Google Fonts name).
#' @param font_body Font family for body text (Google Fonts name).
#' @param logo Optional path to a logo image file.
#' @param sidebar_width Sidebar width in pixels (default 260).
#' @param mathjax Character. "cdn" (default), "local", or NULL to disable.
#' @param self_contained Logical. Whether to produce a self-contained HTML
#'   file. Default TRUE. Set FALSE for large files to reduce size.
#' @param code_folding Whether to fold code chunks. One of "none", "show",
#'   "hide".
#' @param toc Logical. Whether to show a table of contents (default FALSE;
#'   navigation sidebar replaces the TOC).
#' @param ... Additional arguments passed to \code{rmarkdown::html_document}.
#'
#' @return An R Markdown output format.
#' @export
#'
#' @examples
#' \dontrun{
#' ---
#' title: "Mi Reporte"
#' output:
#'   navreport::navreport_html:
#'     theme: navy_teal
#'     self_contained: true
#' ---
#' }
navreport_html <- function(
    theme         = c("navy_teal","dark","light","academic","corporate"),
    primary_color = NULL,
    accent_color  = NULL,
    font_heading  = NULL,
    font_body     = NULL,
    logo          = NULL,
    sidebar_width = 260,
    mathjax       = "cdn",
    self_contained = TRUE,
    code_folding  = "none",
    toc           = FALSE,
    ...
) {
  theme <- match.arg(theme)

  # ── CSS resource paths ────────────────────────────────────────────────────
  pkg_res  <- system.file("resources", package = "navreport")
  css_main <- file.path(pkg_res, "navreport.css")
  js_main  <- file.path(pkg_res, "navreport.js")

  # ── Build CSS custom-properties override ─────────────────────────────────
  theme_vars <- .theme_vars(theme)
  if (!is.null(primary_color)) theme_vars[["--nr-primary"]] <- primary_color
  if (!is.null(accent_color))  theme_vars[["--nr-accent"]]  <- accent_color
  if (!is.null(font_heading))  theme_vars[["--nr-font-h"]]  <- paste0("'", font_heading, "'")
  if (!is.null(font_body))     theme_vars[["--nr-font-b"]]  <- paste0("'", font_body, "'")
  theme_vars[["--nr-sidebar-w"]] <- paste0(sidebar_width, "px")

  css_vars_str <- paste0(
    ":root {\n",
    paste(sprintf("  %s: %s;", names(theme_vars), unlist(theme_vars)), collapse = "\n"),
    "\n}\n"
  )
  tmp_vars_css <- tempfile(fileext = ".css")
  writeLines(css_vars_str, tmp_vars_css)

  # ── Google Fonts ──────────────────────────────────────────────────────────
  default_fonts <- .theme_fonts(theme)
  hfont <- if (!is.null(font_heading)) font_heading else default_fonts$heading
  bfont <- if (!is.null(font_body))    font_body     else default_fonts$body
  gfonts_url <- sprintf(
    "https://fonts.googleapis.com/css2?family=%s:wght@400;700&family=%s:wght@300;400;500;600;700&display=swap",
    gsub(" ", "+", hfont), gsub(" ", "+", bfont)
  )
  fonts_link <- sprintf('<link rel="preconnect" href="https://fonts.googleapis.com">\n<link href="%s" rel="stylesheet">\n', gfonts_url)

  # ── Logo meta ─────────────────────────────────────────────────────────────
  logo_meta <- if (!is.null(logo)) {
    sprintf('<meta name="navreport-logo" content="%s">\n', logo)
  } else ""

  in_header_str <- paste0(fonts_link, logo_meta)
  tmp_header <- tempfile(fileext = ".html")
  writeLines(in_header_str, tmp_header)

  # ── Build output format ───────────────────────────────────────────────────
  fmt <- rmarkdown::html_document(
    theme          = NULL,
    highlight      = NULL,
    css            = c(tmp_vars_css, css_main),
    includes       = rmarkdown::includes(
      in_header  = tmp_header,
      after_body = js_main
    ),
    mathjax        = if (!is.null(mathjax) && mathjax == "cdn")
      "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js" else mathjax,
    self_contained = self_contained,
    code_folding   = code_folding,
    toc            = toc,
    number_sections = FALSE,
    ...
  )
  fmt
}

# ── Internal: theme CSS variables ─────────────────────────────────────────
.theme_vars <- function(theme) {
  switch(theme,
    navy_teal = list(
      "--nr-primary"   = "#0F1C35",
      "--nr-primary2"  = "#1B2A4A",
      "--nr-accent"    = "#0D9488",
      "--nr-accent2"   = "#14B8A6",
      "--nr-accent-lt" = "#CCFBF1",
      "--nr-gold"      = "#C9A227",
      "--nr-bg"        = "#F8FAFC",
      "--nr-white"     = "#FFFFFF",
      "--nr-border"    = "#E2E8F0",
      "--nr-text"      = "#334155",
      "--nr-muted"     = "#64748B",
      "--nr-font-h"    = "'Libre Baskerville'",
      "--nr-font-b"    = "'Source Sans 3'"
    ),
    dark = list(
      "--nr-primary"   = "#111827",
      "--nr-primary2"  = "#1F2937",
      "--nr-accent"    = "#6366F1",
      "--nr-accent2"   = "#818CF8",
      "--nr-accent-lt" = "#EEF2FF",
      "--nr-gold"      = "#F59E0B",
      "--nr-bg"        = "#0F172A",
      "--nr-white"     = "#1E293B",
      "--nr-border"    = "#334155",
      "--nr-text"      = "#E2E8F0",
      "--nr-muted"     = "#94A3B8",
      "--nr-font-h"    = "'DM Serif Display'",
      "--nr-font-b"    = "'DM Sans'"
    ),
    light = list(
      "--nr-primary"   = "#1E40AF",
      "--nr-primary2"  = "#1D4ED8",
      "--nr-accent"    = "#2563EB",
      "--nr-accent2"   = "#3B82F6",
      "--nr-accent-lt" = "#EFF6FF",
      "--nr-gold"      = "#F59E0B",
      "--nr-bg"        = "#F1F5F9",
      "--nr-white"     = "#FFFFFF",
      "--nr-border"    = "#CBD5E1",
      "--nr-text"      = "#1E293B",
      "--nr-muted"     = "#64748B",
      "--nr-font-h"    = "'Playfair Display'",
      "--nr-font-b"    = "'Lato'"
    ),
    academic = list(
      "--nr-primary"   = "#1a1a2e",
      "--nr-primary2"  = "#16213e",
      "--nr-accent"    = "#9B2335",
      "--nr-accent2"   = "#BE2D3F",
      "--nr-accent-lt" = "#FEE2E2",
      "--nr-gold"      = "#B8860B",
      "--nr-bg"        = "#FAFAFA",
      "--nr-white"     = "#FFFFFF",
      "--nr-border"    = "#D1D5DB",
      "--nr-text"      = "#111827",
      "--nr-muted"     = "#6B7280",
      "--nr-font-h"    = "'EB Garamond'",
      "--nr-font-b"    = "'Source Serif 4'"
    ),
    corporate = list(
      "--nr-primary"   = "#0369A1",
      "--nr-primary2"  = "#0284C7",
      "--nr-accent"    = "#059669",
      "--nr-accent2"   = "#10B981",
      "--nr-accent-lt" = "#D1FAE5",
      "--nr-gold"      = "#D97706",
      "--nr-bg"        = "#F9FAFB",
      "--nr-white"     = "#FFFFFF",
      "--nr-border"    = "#E5E7EB",
      "--nr-text"      = "#111827",
      "--nr-muted"     = "#6B7280",
      "--nr-font-h"    = "'Nunito Sans'",
      "--nr-font-b"    = "'Nunito Sans'"
    )
  )
}

.theme_fonts <- function(theme) {
  switch(theme,
    navy_teal  = list(heading = "Libre Baskerville", body = "Source Sans 3"),
    dark       = list(heading = "DM Serif Display",  body = "DM Sans"),
    light      = list(heading = "Playfair Display",  body = "Lato"),
    academic   = list(heading = "EB Garamond",       body = "Source Serif 4"),
    corporate  = list(heading = "Nunito Sans",       body = "Nunito Sans")
  )
}

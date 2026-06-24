# ══════════════════════════════════════════════════════════════════════════════
#  navreport · Page and chart helpers
# ══════════════════════════════════════════════════════════════════════════════

# ── Counter for unique IDs ─────────────────────────────────────────────────
.nr_counter <- local({ n <- 0L; function() { n <<- n + 1L; n } })
.nr_uid <- function(prefix = "nr") paste0(prefix, "_", .nr_counter(), "_",
                                           paste(sample(c(letters, 0:9), 6, TRUE), collapse = ""))

# ══════════════════════════════════════════════════════════════════════════════
#  PAGE WRAPPER
# ══════════════════════════════════════════════════════════════════════════════

#' Define a content page
#'
#' Wraps content in a \code{<div>} that the navigation engine shows/hides.
#' Call once per page, with \code{results = 'asis'} if you use \code{cat()}
#' internally, or use the return value directly inside a chunk.
#'
#' @param id Character. Unique page identifier matching an \code{fn_item(id)}.
#' @param ... Content elements: \code{fn_text()}, \code{fn_hc()},
#'   \code{fn_chart_picker()}, \code{fn_kpi_row()}, htmltools tags, etc.
#' @param title Optional page header (H2). If NULL, no header is added.
#' @param padding CSS padding string (default "2rem 2.5rem").
#'
#' @return An \code{htmltools::tagList} that knitr renders automatically.
#' @export
fn_page <- function(id, ..., title = NULL, padding = "2rem 2.5rem") {
  content <- list(...)
  header  <- if (!is.null(title)) htmltools::h2(class = "nr-page-title", title) else NULL
  htmltools::div(
    class              = "nr-page",
    `data-page-id`     = id,
    style              = paste0("display:none; padding:", padding, ";"),
    header,
    content
  )
}

# ══════════════════════════════════════════════════════════════════════════════
#  TEXT / CALLOUT / KPI BLOCKS
# ══════════════════════════════════════════════════════════════════════════════

#' Render styled text block
#'
#' @param ... Character strings or htmltools tags. Character strings may
#'   contain basic markdown (## heading, **bold**, *italic*, newlines).
#' @param class Extra CSS classes.
#' @export
fn_text <- function(..., class = NULL) {
  args  <- list(...)
  inner <- lapply(args, function(x) {
    if (is.character(x)) htmltools::HTML(.md_lite(x)) else x
  })
  htmltools::div(class = paste("nr-text-block", class), inner)
}

#' Callout box (info, success, warning, error)
#'
#' @param text Character. Body text.
#' @param title Character. Optional bold title.
#' @param type One of "info", "success", "warning", "error".
#' @param icon Optional icon string (HTML entity or emoji).
#' @export
fn_callout <- function(text, title = NULL, type = "info", icon = NULL) {
  icons <- list(info = "ℹ️", success = "✅", warning = "⚠️", error = "❌")
  used_icon <- if (!is.null(icon)) icon else icons[[type]]
  htmltools::div(
    class = paste0("nr-callout nr-callout-", type),
    htmltools::span(class = "nr-callout-icon", htmltools::HTML(used_icon)),
    htmltools::div(
      class = "nr-callout-body",
      if (!is.null(title)) htmltools::div(class = "nr-callout-title", title) else NULL,
      htmltools::p(text)
    )
  )
}

#' Row of KPI cards
#'
#' @param ... \code{fn_kpi()} objects.
#' @export
fn_kpi_row <- function(...) {
  htmltools::div(class = "nr-kpi-row", list(...))
}

#' Single KPI card
#'
#' @param label Character. Small label above the value.
#' @param value Character or numeric. Main displayed value.
#' @param sub Character. Optional sub-label below the value.
#' @param color One of "accent", "gold", "green", "red", "purple", "default".
#' @export
fn_kpi <- function(label, value, sub = NULL, color = "default") {
  htmltools::div(
    class = paste0("nr-kpi nr-kpi-", color),
    htmltools::div(class = "nr-kpi-label", label),
    htmltools::div(class = "nr-kpi-value", as.character(value)),
    if (!is.null(sub)) htmltools::div(class = "nr-kpi-sub", sub) else NULL
  )
}

# ══════════════════════════════════════════════════════════════════════════════
#  LAZY CHART WRAPPERS
#  These serialize the widget to JSON and wrap it so it is NOT rendered
#  by HTMLWidgets on page load. The navreport JS initialises it when the
#  user navigates to the containing page.
# ══════════════════════════════════════════════════════════════════════════════

#' Wrap a highcharter widget for lazy loading
#'
#' @param hc A \code{highchart} object from the highcharter package.
#' @param height CSS height string (default "400px").
#' @param width CSS width string (default "100%").
#' @export
fn_hc <- function(hc, height = "420px", width = "100%") {
  if (!requireNamespace("highcharter", quietly = TRUE))
    stop("Package 'highcharter' is required for fn_hc().")
  .lazy_widget(hc, type = "highcharts", height = height, width = width)
}

#' Wrap a ggplot2 object for lazy loading (converts via ggplotly)
#'
#' @param gg A \code{ggplot} object.
#' @param height CSS height string (default "420px").
#' @param width CSS width string (default "100%").
#' @param tooltip_extra Additional aesthetics to include in plotly tooltip.
#' @export
fn_gg <- function(gg, height = "420px", width = "100%", ...) {
  if (!requireNamespace("plotly", quietly = TRUE))
    stop("Package 'plotly' is required for fn_gg().")
  p <- plotly::ggplotly(gg, ...)
  .lazy_widget(p, type = "plotly", height = height, width = width)
}

#' Wrap a plotly widget for lazy loading
#'
#' @param p A \code{plotly} object.
#' @param height CSS height string (default "420px").
#' @param width CSS width string (default "100%").
#' @export
fn_plotly <- function(p, height = "420px", width = "100%") {
  if (!requireNamespace("plotly", quietly = TRUE))
    stop("Package 'plotly' is required for fn_plotly().")
  .lazy_widget(p, type = "plotly", height = height, width = width)
}

#' Wrap an echarts4r widget for lazy loading
#'
#' @param ec An \code{echarts4r} object.
#' @param height CSS height string (default "420px").
#' @param width CSS width string (default "100%").
#' @export
fn_ec <- function(ec, height = "420px", width = "100%") {
  .lazy_widget(ec, type = "echarts", height = height, width = width)
}

# ── Internal: generic lazy widget wrapper ────────────────────────────────
.lazy_widget <- function(widget, type, height, width) {
  uid <- .nr_uid(type)

  # Serialise the widget's data/config to JSON
  widget_json <- tryCatch(
    jsonlite::toJSON(
      htmlwidgets:::toJSON2(widget$x),
      auto_unbox = TRUE, null = "null", na = "null"
    ),
    error = function(e) {
      # Fallback: capture the rendered widget HTML and embed as iframe-style
      tmp <- tempfile(fileext = ".json")
      cat(jsonlite::toJSON(list(fallback = TRUE, error = conditionMessage(e)),
                           auto_unbox = TRUE), file = tmp)
      readLines(tmp)
    }
  )

  # ── Dependencias JS del widget (CRÍTICO) ────────────────────────────────
  # Al serializar el widget a JSON manualmente, se PIERDEN sus dependencias
  # (la librería Highcharts, plotly, etc.). Sin ellas, window.Highcharts no
  # existe en el navegador y el gráfico nunca se dibuja (spinner infinito).
  # Aquí se recolectan esas dependencias y se adjuntan al tagList que se
  # devuelve: knitr/rmarkdown las detecta y las embebe UNA vez en el
  # documento (htmltools deduplica si el mismo widget aparece muchas veces),
  # de modo que la librería esté disponible globalmente cuando el JS de
  # navreport llame a Highcharts.chart() al navegar a la página.
  deps <- tryCatch(
    htmlwidgets::getDependency(
      name    = switch(type,
                       highcharts = "highchart",
                       plotly     = "plotly",
                       echarts    = "echarts4r",
                       type),
      package = switch(type,
                       highcharts = "highcharter",
                       plotly     = "plotly",
                       echarts    = "echarts4r",
                       NULL)
    ),
    error = function(e) NULL
  )
  # Respaldo: si getDependency no funcionó, tomar las dependencias que el
  # propio objeto widget trae adjuntas (widget$dependencies).
  if (is.null(deps) || length(deps) == 0) {
    deps <- widget$dependencies
  }

  # Produce a placeholder div + the data script
  bloque <- htmltools::tagList(
    htmltools::div(
      id    = uid,
      class = paste0("nr-lazy-chart nr-lazy-", type),
      `data-chart-type`   = type,
      `data-chart-id`     = uid,
      `data-initialized`  = "false",
      style = sprintf("width:%s; height:%s; min-height:200px;", width, height),
      # Spinner shown until chart renders
      htmltools::div(
        class = "nr-chart-spinner",
        htmltools::HTML(
          '<svg viewBox="0 0 50 50" class="nr-spinner-svg"><circle cx="25" cy="25" r="20" fill="none" stroke-width="4"></circle></svg>'
        )
      )
    ),
    htmltools::tags$script(
      type            = "text/nr-deferred",    # NOT application/json → skipped by HTMLWidgets
      `data-chart-id` = uid,
      `data-type`     = type,
      htmltools::HTML(widget_json)
    )
  )

  # Adjuntar las dependencias al bloque para que se embeban en el documento.
  if (!is.null(deps) && length(deps) > 0) {
    bloque <- htmltools::attachDependencies(bloque, deps, append = TRUE)
  }
  bloque
}

# ══════════════════════════════════════════════════════════════════════════════
#  CHART PICKER  (dropdown to switch between charts)
# ══════════════════════════════════════════════════════════════════════════════

#' Dropdown chart selector
#'
#' Renders a dropdown \code{<select>} that switches between multiple charts
#' or htmltools elements on the same page.
#'
#' @param ... Named arguments where each name becomes a dropdown option and
#'   each value is a chart (from \code{fn_hc}, \code{fn_gg}, etc.) or any
#'   htmltools tag. Use \code{choices = list("Label" = fn_hc(...))} syntax.
#' @param label Character. Dropdown label text (default "Seleccionar:").
#' @param choices Named list of charts (alternative to \code{...}).
#' @param default Integer. Which option to show initially (default 1).
#' @param width Dropdown width (default "260px").
#'
#' @export
fn_chart_picker <- function(..., label = "Seleccionar:", choices = NULL,
                             default = 1L, width = "260px") {

  items <- if (!is.null(choices)) choices else list(...)
  if (length(items) == 0) stop("fn_chart_picker requires at least one chart.")

  nms <- names(items)
  if (is.null(nms) || any(nms == ""))
    nms <- paste("Opción", seq_along(items))

  pid  <- .nr_uid("picker")
  cids <- vapply(seq_along(items), function(i) paste0(pid, "_c", i), character(1))

  # Dropdown control
  select_el <- htmltools::tags$select(
    id      = paste0(pid, "_sel"),
    class   = "nr-picker-select",
    style   = paste0("width:", width),
    onchange = sprintf("NR.switchPicker('%s', this.value)", pid),
    lapply(seq_along(items), function(i) {
      htmltools::tags$option(
        value    = cids[i],
        selected = if (i == default) "" else NULL,
        nms[i]
      )
    })
  )

  # Chart panels
  chart_panels <- lapply(seq_along(items), function(i) {
    htmltools::div(
      id    = cids[i],
      class = "nr-picker-panel",
      `data-picker-id` = pid,
      style = if (i != default) "display:none" else NULL,
      items[[i]]
    )
  })

  htmltools::div(
    class = "nr-chart-picker",
    `data-picker-id` = pid,
    htmltools::div(
      class = "nr-picker-control",
      htmltools::tags$label(`for` = paste0(pid, "_sel"), class = "nr-picker-label", label),
      select_el
    ),
    htmltools::div(class = "nr-picker-panels", chart_panels)
  )
}

# ══════════════════════════════════════════════════════════════════════════════
#  TEXT + CHART  (side-by-side or stacked layout)
# ══════════════════════════════════════════════════════════════════════════════

#' Combined text and chart block
#'
#' Puts a text block next to or above a chart.
#'
#' @param text Character or htmltools tag. Text content (left / top).
#' @param chart A chart object from \code{fn_hc}, \code{fn_gg}, etc.
#' @param layout One of "side" (text left, chart right) or "stack" (text
#'   above chart).
#' @param text_width CSS width of the text column in "side" layout (default
#'   "35%").
#'
#' @export
fn_text_chart <- function(text, chart, layout = "side", text_width = "35%") {
  text_el <- if (is.character(text)) fn_text(text) else text

  if (layout == "side") {
    htmltools::div(
      class = "nr-text-chart-side",
      htmltools::div(class = "nr-tc-text",
                     style = paste0("flex: 0 0 ", text_width, "; max-width:", text_width),
                     text_el),
      htmltools::div(class = "nr-tc-chart",
                     style = paste0("flex: 1 1 calc(100% - ", text_width, ")"),
                     chart)
    )
  } else {
    htmltools::div(
      class = "nr-text-chart-stack",
      htmltools::div(class = "nr-tc-text", text_el),
      htmltools::div(class = "nr-tc-chart", chart)
    )
  }
}

# ══════════════════════════════════════════════════════════════════════════════
#  INTERNAL: minimal Markdown → HTML converter
#  (avoids pulling in commonmark/pandoc for simple formatting)
# ══════════════════════════════════════════════════════════════════════════════
.md_lite <- function(txt) {
  # Inline (negrita, cursiva, código) — se aplican sobre todo el texto.
  txt <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", txt, perl = TRUE)
  txt <- gsub("\\*(.+?)\\*",       "<em>\\1</em>",          txt, perl = TRUE)
  txt <- gsub("`(.+?)`",            "<code>\\1</code>",      txt, perl = TRUE)

  # Encabezados y párrafos — se procesan LÍNEA POR LÍNEA. El bug anterior
  # era usar "^## ...$" sobre el texto completo sin modo multilínea: ^ y $
  # solo coincidían con el inicio/fin de TODO el texto, así que un "## " que
  # no estuviera en la primerísima posición (o con más texto después) nunca
  # se convertía y se mostraba literal. Procesar línea por línea lo evita.
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  out <- vapply(lines, function(l) {
    lt <- trimws(l)
    if (lt == "") return("")
    if (grepl("^### ", lt)) return(paste0("<h4>", sub("^### ", "", lt), "</h4>"))
    if (grepl("^## ",  lt)) return(paste0("<h3>", sub("^## ",  "", lt), "</h3>"))
    if (grepl("^# ",   lt)) return(paste0("<h2>", sub("^# ",   "", lt), "</h2>"))
    # Si la línea ya es una etiqueta de bloque HTML, dejarla tal cual.
    if (grepl("^<(h[1-6]|ul|ol|li|p|div|table|blockquote)", lt)) return(l)
    paste0("<p>", l, "</p>")
  }, character(1), USE.NAMES = FALSE)
  paste(out, collapse = "\n")
}

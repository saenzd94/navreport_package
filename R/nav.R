# ══════════════════════════════════════════════════════════════════════════════
#  navreport · Navigation functions
#  These are called in the document setup chunk to define the nav structure
#  and emit the configuration + shell HTML that the JS engine reads.
# ══════════════════════════════════════════════════════════════════════════════

#' Emit the navigation configuration and sidebar shell
#'
#' Call this function **once** in the document's setup chunk (with
#' \code{results = 'asis'}). Pass \code{fn_menu()} objects as \code{...}.
#'
#' @param ... \code{fn_menu()} objects describing the navigation tree.
#' @param title Character. Dashboard/report title shown in the sidebar header.
#' @param subtitle Character. Optional subtitle shown below the title.
#' @param logo Character. Optional path to a logo image (overrides YAML logo).
#' @param first_page Character. ID of the page to show on initial load.
#'   Defaults to the first leaf page in the navigation tree.
#'
#' @return Invisible NULL; emits HTML as a side-effect via \code{cat()}.
#' @export
fn_nav <- function(..., title = "Dashboard", subtitle = NULL,
                   logo = NULL, first_page = NULL) {

  items <- list(...)

  # Auto-detect first page from tree if not supplied
  if (is.null(first_page)) {
    first_page <- .first_leaf(items)
  }

  # Serialise navigation tree to JSON
  nav_json <- jsonlite::toJSON(.nav_to_list(items), auto_unbox = TRUE)

  # Build the full sidebar + main layout shell
  shell_html <- sprintf('
<!-- navreport layout root -->
<div id="nr-root">

  <!-- Sidebar -->
  <nav id="nr-sidebar" aria-label="Navegación principal">
    <div id="nr-sidebar-header">
      %s
      <div id="nr-sidebar-titles">
        <div id="nr-sidebar-title">%s</div>
        %s
      </div>
      <button id="nr-sidebar-toggle" onclick="NR.toggleSidebar()" title="Contraer/expandir menú" aria-label="Toggle sidebar">&#9776;</button>
    </div>
    <div id="nr-sidebar-search-wrap" style="display:none">
      <input id="nr-sidebar-search" type="text" placeholder="Buscar página..." oninput="NR.filterNav(this.value)" />
    </div>
    <div id="nr-nav-tree"></div>
  </nav>

  <!-- Main content area -->
  <div id="nr-main">
    <div id="nr-topbar">
      <button id="nr-mobile-toggle" onclick="NR.toggleSidebar()" aria-label="Menu">&#9776;</button>
      <span id="nr-breadcrumb"></span>
      <span id="nr-progress-badge" style="display:none"></span>
    </div>
    <div id="nr-content">
      <!-- Pages rendered by user chunks go here (injected by navreport JS) -->
    </div>
  </div>
</div>

<!-- navreport configuration JSON -->
<script type="application/json" id="nr-config">
{
  "title": %s,
  "subtitle": %s,
  "logo": %s,
  "firstPage": %s,
  "nav": %s
}
</script>
',
    # logo img tag
    if (!is.null(logo)) sprintf('<img id="nr-logo" src="%s" alt="Logo">', logo) else "",
    htmltools::htmlEscape(title),
    if (!is.null(subtitle)) sprintf('<div id="nr-sidebar-subtitle">%s</div>', htmltools::htmlEscape(subtitle)) else "",
    jsonlite::toJSON(title, auto_unbox = TRUE),
    jsonlite::toJSON(subtitle, auto_unbox = TRUE, null = "null"),
    jsonlite::toJSON(logo,     auto_unbox = TRUE, null = "null"),
    jsonlite::toJSON(first_page, auto_unbox = TRUE),
    nav_json
  )

  cat(shell_html)
  invisible(NULL)
}

# ── Navigation tree builders ──────────────────────────────────────────────

#' Create a top-level menu entry
#'
#' @param label Character. Menu label shown in the sidebar.
#' @param ... Child elements: \code{fn_submenu()} or \code{fn_item()} objects.
#' @param icon Optional icon HTML string (e.g. "&#128200;").
#' @export
fn_menu <- function(label, ..., icon = NULL) {
  structure(
    list(type = "menu", label = label, icon = icon, children = list(...)),
    class = "nr_node"
  )
}

#' Create a submenu entry (can be nested inside fn_menu or other fn_submenu)
#'
#' @param label Character. Submenu label.
#' @param ... Child elements: further \code{fn_submenu()} or \code{fn_item()} objects.
#' @param icon Optional icon HTML string.
#' @export
fn_submenu <- function(label, ..., icon = NULL) {
  structure(
    list(type = "submenu", label = label, icon = icon, children = list(...)),
    class = "nr_node"
  )
}

#' Create a leaf navigation item (links to a page)
#'
#' @param label Character. Item label shown in the sidebar.
#' @param id Character. The page ID this item links to. Must match the
#'   \code{id} argument in the corresponding \code{fn_page()} call.
#' @param icon Optional icon HTML string.
#' @export
fn_item <- function(label, id, icon = NULL) {
  structure(
    list(type = "item", label = label, id = id, icon = icon),
    class = "nr_node"
  )
}

# ── Internal helpers ──────────────────────────────────────────────────────

# Convert R tree to plain list suitable for JSON serialisation
.nav_to_list <- function(nodes) {
  lapply(nodes, function(n) {
    out <- list(type = n$type, label = n$label)
    if (!is.null(n$icon)) out$icon <- n$icon
    if (!is.null(n$id))   out$id   <- n$id
    if (!is.null(n$children) && length(n$children) > 0) {
      out$children <- .nav_to_list(n$children)
    }
    out
  })
}

# Find first leaf id in the tree
.first_leaf <- function(nodes) {
  for (n in nodes) {
    if (n$type == "item") return(n$id)
    if (!is.null(n$children)) {
      res <- .first_leaf(n$children)
      if (!is.null(res)) return(res)
    }
  }
  return("page_1")
}

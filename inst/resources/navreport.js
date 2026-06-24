/* navreport.js  ·  Navigation engine + lazy widget loader
 *
 * LAZY LOADING STRATEGY
 * ─────────────────────
 * 1. At DOMContentLoaded (fires BEFORE window.onload where HTMLWidgets
 *    calls staticRender), we find every <script type="text/nr-deferred">
 *    tag inside non-active pages.
 * 2. Those scripts contain the serialised widget JSON but are invisible to
 *    HTMLWidgets because their type is NOT "application/json".
 * 3. When the user navigates to a page, we change the type back to
 *    "application/json" and call HTMLWidgets.staticRender() — which is
 *    idempotent and initialises only the newly activated widgets.
 * 4. For highcharts (serialised via fn_hc), we also support a direct
 *    Highcharts.chart() path as a fallback.
 *
 * Result: a document with 200 charts opens in <5 s because only the
 * charts on the first visible page are initialised on load.
 */
(function () {
  'use strict';

  /* ── State ──────────────────────────────────────────────────────── */
  var NR = {
    config:      null,
    initialized: {},    // pageId → boolean
    breadcrumbs: {},    // pageId → [labels]
    current:     null,

    /* ── Bootstrap ─────────────────────────────────────────────── */
    init: function () {
      var cfgEl = document.getElementById('nr-config');
      if (!cfgEl) { console.warn('navreport: #nr-config not found'); return; }
      try { NR.config = JSON.parse(cfgEl.textContent || cfgEl.innerText); }
      catch (e) { console.error('navreport: bad config JSON', e); return; }

      // Move all .nr-page elements into #nr-content
      var content = document.getElementById('nr-content');
      if (content) {
        document.querySelectorAll('.nr-page').forEach(function (p) {
          content.appendChild(p);
        });
      }

      NR.buildNav();
      NR.buildBreadcrumbMap(NR.config.nav, []);

      // Defer all widget scripts on non-first pages BEFORE window.onload
      NR.deferAll();

      var first = NR.config.firstPage || NR.firstLeaf(NR.config.nav);
      NR.navigate(first, false);

      // Handle back/forward
      window.addEventListener('hashchange', function () {
        var hash = window.location.hash.replace('#', '');
        if (hash) NR.navigate(hash, false);
      });

      // Overlay click closes mobile menu
      document.addEventListener('click', function (e) {
        if (e.target === document.querySelector('#nr-sidebar + *') ||
            (NR.isMobile() && !document.getElementById('nr-sidebar').contains(e.target) &&
             !document.getElementById('nr-mobile-toggle').contains(e.target))) {
          NR.closeMobile();
        }
      });
    },

    /* ── Build navigation tree ──────────────────────────────────── */
    buildNav: function () {
      var tree = document.getElementById('nr-nav-tree');
      if (!tree || !NR.config.nav) return;
      tree.innerHTML = '<ul class="nr-nav-list">' + NR.buildNodeList(NR.config.nav, 0) + '</ul>';
    },

    buildNodeList: function (nodes, depth) {
      return nodes.map(function (n) {
        return NR.buildNode(n, depth);
      }).join('');
    },

    buildNode: function (n, depth) {
      var icon = n.icon ? '<span class="nr-icon">' + n.icon + '</span>' : '';

      if (n.type === 'item') {
        return '<li>' +
          '<button class="nr-nav-item-btn" data-page-id="' + NR.esc(n.id) + '" ' +
          'onclick="NR.navigate(\'' + NR.esc(n.id) + '\')">' +
          icon + NR.esc(n.label) + '</button></li>';
      }

      // menu or submenu – both have children
      var btnClass = depth === 0 ? 'nr-nav-menu-btn' : 'nr-nav-sub-btn';
      var children = n.children ? NR.buildNodeList(n.children, depth + 1) : '';
      return '<li>' +
        '<button class="' + btnClass + '" onclick="NR.toggleNode(this)">' +
        icon + NR.esc(n.label) + '<span class="nr-chevron">&#9656;</span></button>' +
        '<ul class="nr-nav-children">' + children + '</ul>' +
        '</li>';
    },

    /* ── Toggle menu/submenu ────────────────────────────────────── */
    toggleNode: function (btn) {
      var ul = btn.nextElementSibling;
      var isOpen = ul.classList.contains('open');

      // Close sibling nodes at same level
      var parentUl = btn.parentElement.parentElement;
      if (parentUl) {
        parentUl.querySelectorAll(':scope > li > button').forEach(function (b) {
          if (b !== btn) {
            b.classList.remove('open');
            var sib = b.nextElementSibling;
            if (sib && sib.classList.contains('nr-nav-children')) {
              sib.classList.remove('open');
            }
          }
        });
      }

      btn.classList.toggle('open', !isOpen);
      ul.classList.toggle('open', !isOpen);

      // Expand parent containers
      if (!isOpen) NR.expandParents(ul);
    },

    expandParents: function (el) {
      var p = el.parentElement;
      while (p) {
        if (p.classList.contains('nr-nav-children')) {
          p.classList.add('open');
          var prevBtn = p.previousElementSibling;
          if (prevBtn) prevBtn.classList.add('open');
        }
        if (p.id === 'nr-nav-tree') break;
        p = p.parentElement;
      }
    },

    /* ── Navigate to page ───────────────────────────────────────── */
    navigate: function (pageId, pushHash) {
      if (pushHash !== false) window.location.hash = pageId;

      // Hide current
      document.querySelectorAll('.nr-page').forEach(function (el) {
        el.style.display = 'none';
        el.classList.remove('nr-page-enter');
      });

      // Show target — IMPORTANTE: hay que acotar a '.nr-page', porque los
      // botones del menú TAMBIÉN llevan data-page-id; sin el prefijo
      // '.nr-page' el selector tomaría el botón (que aparece antes en el
      // DOM) en vez de la página, y la página nunca se mostraría.
      var target = document.querySelector('.nr-page[data-page-id="' + pageId + '"]');
      if (target) {
        target.style.display = 'block';
        // Trigger reflow for animation
        void target.offsetHeight;
        target.classList.add('nr-page-enter');
      }

      // Activate nav button & expand parents
      document.querySelectorAll('.nr-nav-item-btn').forEach(function (b) {
        var active = b.getAttribute('data-page-id') === pageId;
        b.classList.toggle('active', active);
        if (active) NR.expandParents(b.parentElement);
      });

      // Breadcrumb
      NR.updateBreadcrumb(pageId);

      // Lazy-init widgets on this page
      NR.initPage(pageId);

      NR.current = pageId;

      // Close mobile menu after navigation
      if (NR.isMobile()) NR.closeMobile();
    },

    /* ── Defer all widgets ──────────────────────────────────────── */
    deferAll: function () {
      document.querySelectorAll('.nr-page').forEach(function (page) {
        var pid = page.getAttribute('data-page-id');
        // We'll activate the first page after deferral, so defer everything
        var scripts = page.querySelectorAll('script[type="text/nr-deferred"]');
        // Already in deferred state (our R package writes them as text/nr-deferred)
        // No action needed — htmlwidgets ignores non-application/json scripts
        // We just record them for later activation
        if (scripts.length > 0) {
          NR.initialized[pid] = false;
        } else {
          // No lazy charts — mark as done
          NR.initialized[pid] = true;
        }
      });
    },

    /* ── Initialise widgets on a page ───────────────────────────── */
    initPage: function (pageId) {
      if (NR.initialized[pageId]) return;

      var page = document.querySelector('.nr-page[data-page-id="' + pageId + '"]');
      if (!page) return;

      NR.initWidgetsIn(page);
      NR.initialized[pageId] = true;
    },

    /* ── Initialise every lazy widget inside a container ─────────────
       Reutilizable tanto para una página completa como para un panel
       del chart-picker. Maneja dos tipos de widget:
         • highcharts (vía fn_hc): el <script type="text/nr-deferred">
           es HERMANO del div .nr-lazy-chart y lleva el mismo
           data-chart-id; su contenido es un string JSON doblemente
           codificado cuya config real está en la clave "hc_opts".
         • otros htmlwidgets (plotly, etc.): se activan cambiando el
           type del script a "application/json" y llamando a
           HTMLWidgets.staticRender().                                  */
    initWidgetsIn: function (container) {
      if (!container) return;

      // ── 1. Gráficos highcharter (fn_hc) ──────────────────────────
      container.querySelectorAll('.nr-lazy-highcharts[data-initialized="false"]').forEach(function (div) {
        NR.initHighchart(div);
      });

      // ── 2. Otros htmlwidgets: activar y dejar que HTMLWidgets los
      //       renderice. Se excluyen los scripts de highcharts, que ya
      //       se inicializaron arriba por su cuenta. ─────────────────
      var activados = false;
      container.querySelectorAll('script[type="text/nr-deferred"]').forEach(function (s) {
        if (s.getAttribute('data-type') === 'highcharts') return;  // ya manejado
        s.setAttribute('type', 'application/json');
        activados = true;
      });
      if (activados && window.HTMLWidgets && typeof HTMLWidgets.staticRender === 'function') {
        try { HTMLWidgets.staticRender(); } catch (e) { console.warn('HTMLWidgets.staticRender error', e); }
      }

      // ── 3. Ocultar spinners de los gráficos ya inicializados ─────
      container.querySelectorAll('.nr-chart-spinner').forEach(function (sp) {
        setTimeout(function () { sp.classList.add('hidden'); }, 300);
      });
    },

    initHighchart: function (div) {
      if (!window.Highcharts) { console.warn('navreport: Highcharts no disponible'); return; }
      // El <script> con la config es HERMANO del div y comparte data-chart-id.
      var cid = div.getAttribute('data-chart-id');
      var scriptEl = document.querySelector(
        'script[data-chart-id="' + cid + '"][data-type="highcharts"]'
      );
      // Respaldo: algunos navegadores ya cambiaron el type a application/json
      if (!scriptEl) {
        scriptEl = document.querySelector('script[data-chart-id="' + cid + '"]');
      }
      if (!scriptEl) { console.warn('navreport: no se encontró config para', cid); return; }

      try {
        var raw = scriptEl.textContent || scriptEl.innerText;
        // highcharter serializa como STRING JSON (doblemente codificado):
        // primero se parsea el string exterior, y el resultado es a su vez
        // un objeto con la clave hc_opts que contiene la config real.
        var parsed = JSON.parse(raw);
        if (typeof parsed === 'string') parsed = JSON.parse(parsed);
        var cfg = parsed.hc_opts ? parsed.hc_opts : parsed;

        // Aplicar tema si highcharter lo incluyó por separado
        if (parsed.theme && typeof Highcharts.merge === 'function') {
          cfg = Highcharts.merge(parsed.theme, cfg);
        }

        Highcharts.chart(div.id, cfg);
        div.setAttribute('data-initialized', 'true');

        // Ocultar el spinner de ESTE gráfico
        var sp = div.querySelector('.nr-chart-spinner');
        if (sp) sp.classList.add('hidden');
      } catch (e) {
        console.warn('navreport: error al inicializar Highchart', cid, e);
      }
    },

    /* ── Chart picker ───────────────────────────────────────────── */
    switchPicker: function (pickerId, panelId) {
      document.querySelectorAll('[data-picker-id="' + pickerId + '"]').forEach(function (p) {
        p.style.display = p.id === panelId ? 'block' : 'none';
      });
      // Inicializar los widgets del panel recién mostrado (mismo mecanismo
      // que initPage, reutilizado para no duplicar lógica).
      NR.initWidgetsIn(document.getElementById(panelId));
    },

    /* ── Sidebar toggle ─────────────────────────────────────────── */
    toggleSidebar: function () {
      if (NR.isMobile()) {
        var sidebar = document.getElementById('nr-sidebar');
        sidebar.classList.toggle('mobile-open');
        document.body.classList.toggle('nr-mobile-open');
      } else {
        var root = document.getElementById('nr-root');
        root.classList.toggle('nr-sidebar-collapsed');
        document.getElementById('nr-sidebar').classList.toggle('collapsed');
      }
    },

    closeMobile: function () {
      document.getElementById('nr-sidebar').classList.remove('mobile-open');
      document.body.classList.remove('nr-mobile-open');
    },

    isMobile: function () { return window.innerWidth <= 860; },

    /* ── Breadcrumb ─────────────────────────────────────────────── */
    buildBreadcrumbMap: function (nodes, path) {
      nodes.forEach(function (n) {
        if (n.type === 'item') {
          NR.breadcrumbs[n.id] = path.concat(n.label);
        } else if (n.children) {
          NR.buildBreadcrumbMap(n.children, path.concat(n.label));
        }
      });
    },

    updateBreadcrumb: function (pageId) {
      var el = document.getElementById('nr-breadcrumb');
      if (!el) return;
      var parts = NR.breadcrumbs[pageId] || [pageId];
      el.innerHTML = parts.map(function (p, i) {
        if (i === parts.length - 1) return '<span class="nr-bc-current">' + NR.esc(p) + '</span>';
        return NR.esc(p) + '<span class="nr-bc-sep">›</span>';
      }).join('');
    },

    /* ── Nav search/filter ──────────────────────────────────────── */
    filterNav: function (query) {
      var q = query.toLowerCase().trim();
      document.querySelectorAll('.nr-nav-item-btn').forEach(function (btn) {
        var label = btn.textContent.toLowerCase();
        var li = btn.parentElement;
        li.style.display = (!q || label.includes(q)) ? '' : 'none';
      });
      // Expand all menus when searching
      if (q) {
        document.querySelectorAll('.nr-nav-children').forEach(function (ul) { ul.classList.add('open'); });
        document.querySelectorAll('.nr-nav-menu-btn, .nr-nav-sub-btn').forEach(function (b) { b.classList.add('open'); });
      }
    },

    /* ── First leaf helper ──────────────────────────────────────── */
    firstLeaf: function (nodes) {
      for (var i = 0; i < nodes.length; i++) {
        var n = nodes[i];
        if (n.type === 'item') return n.id;
        if (n.children) {
          var res = NR.firstLeaf(n.children);
          if (res) return res;
        }
      }
      return null;
    },

    /* ── HTML-escape helper ─────────────────────────────────────── */
    esc: function (s) {
      return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    }
  };

  /* ── Expose globally so onclick="" handlers work ─────────────── */
  window.NR = NR;

  /* ── Init after DOM ready ────────────────────────────────────── */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { NR.init(); });
  } else {
    NR.init();
  }

})();

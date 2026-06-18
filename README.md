# navreport <img src="https://img.shields.io/badge/R-4.0%2B-blue" align="right">

Template de R Markdown con **navegación lateral multinivel** y **carga diferida de gráficos** (lazy loading). Inspirado en el estilo visual del HTML pedagógico de Teoría de Juegos.

---

## ✨ Características

| Función | Detalle |
|---|---|
| **Menús ilimitados** | `fn_menu()` → `fn_submenu()` → `fn_submenu()` → ... sin límite de niveles |
| **Lazy loading** | Los gráficos se renderizan **solo cuando el usuario navega** a esa página. Un reporte con 200 gráficos abre en < 5 segundos |
| **highcharter** | `fn_hc(highchart() %>% ...)` |
| **ggplot2** | `fn_gg(ggplot(...))` — convierte a plotly internamente |
| **plotly** | `fn_plotly(plot_ly(...))` |
| **echarts4r** | `fn_ec(ec_val(...))` |
| **Chart picker** | `fn_chart_picker(...)` — menú desplegable para cambiar gráfico |
| **KPI cards** | `fn_kpi_row(fn_kpi(...))` |
| **Callouts** | `fn_callout(...)` — cajas info / success / warning / error |
| **MathJax** | LaTeX en línea `$formula$` y en bloque `$$formula$$` |
| **5 temas** | `navy_teal`, `dark`, `light`, `academic`, `corporate` |
| **Barra lateral colapsable** | Botón de colapso, versión mobile con overlay |

---

## 🚀 Instalación

### Opción A — Desde GitHub (recomendado)

```r
# Instalar devtools si no lo tiene
install.packages("devtools")

# Instalar navreport
devtools::install_github("saenzd94/navreport_package")
```

### Opción B — Instalación local (sin GitHub)

1. Descargue o clone este repositorio.
2. En RStudio, abra el proyecto o establezca el directorio de trabajo
   en la carpeta raíz del paquete.
3. Ejecute:

```r
# Instalar dependencias
install.packages(c("rmarkdown","htmltools","jsonlite","knitr"))

# Instalar paquetes de gráficos (instale los que use)
install.packages(c("highcharter","plotly","ggplot2","dplyr","tidyr"))

# Instalar navreport
devtools::install_local(".")   # ejecutar desde la raíz del paquete
```

---

## 📁 Usar el template en RStudio

Después de instalar:

1. En RStudio: **File → New File → R Markdown…**
2. Seleccionar **"From Template"** en el panel izquierdo
3. Buscar **"navreport — Multi-Level Navigation Dashboard"**
4. Clic en **OK**
5. Presionar **Knit** ▶

---

## 🔧 Estructura básica de un documento

```yaml
---
title: "Mi Reporte"
output:
  navreport::navreport_html:
    theme: navy_teal       # navy_teal | dark | light | academic | corporate
    self_contained: true
---
```

```r
# chunk de setup
library(navreport)
library(highcharter)
library(ggplot2)
```

```r
# chunk de navegación (results='asis')
fn_nav(
  fn_menu("Sección 1",
    fn_submenu("Análisis A",
      fn_item("Página 1", "p1"),
      fn_item("Página 2", "p2")
    )
  ),
  fn_menu("Sección 2",
    fn_item("Resumen", "p_res")
  ),
  title = "Mi Dashboard"
)
```

```r
# chunk de página (results='asis')
fn_page("p1", title = "Mi primera página",
  fn_text("## Título\nTexto con **negrita** y _cursiva_."),
  fn_hc(highchart() %>% hc_add_series(data = c(1,3,2,5,4))),
  fn_chart_picker(
    label = "Cambiar gráfico:",
    "Línea" = fn_hc(highchart() %>% hc_chart(type="line") %>% hc_add_series(data=c(1,3,2))),
    "Barra" = fn_hc(highchart() %>% hc_chart(type="column") %>% hc_add_series(data=c(1,3,2)))
  )
)
```

---

## 📖 Referencia de funciones

### Navegación

```r
fn_nav(..., title, subtitle, first_page)   # Emite el HTML de la barra lateral
fn_menu(label, ..., icon)                  # Menú de nivel superior
fn_submenu(label, ..., icon)               # Submenú (anidable sin límite)
fn_item(label, id, icon)                   # Ítem hoja que apunta a una página
```

### Páginas y contenido

```r
fn_page(id, ..., title)                    # Contenedor de una página
fn_text(...)                               # Texto con markdown básico
fn_callout(text, title, type)              # Caja destacada
fn_kpi_row(...)                            # Fila de tarjetas KPI
fn_kpi(label, value, sub, color)           # Tarjeta KPI individual
```

### Gráficos (lazy loaded)

```r
fn_hc(hc_obj, height, width)              # highcharter
fn_gg(gg_obj, height, width)              # ggplot2 → plotly
fn_plotly(p_obj, height, width)           # plotly nativo
fn_ec(ec_obj, height, width)              # echarts4r
```

### Layouts

```r
fn_chart_picker(..., label, default)      # Selector desplegable de gráficos
fn_text_chart(text, chart, layout)        # Texto + gráfico (side | stack)
```

---

## ⚡ Por qué abre rápido (lazy loading)

**Problema:** Un reporte con 100 gráficos de highcharter puede
demorar 20 minutos en abrirse en el navegador porque
`HTMLWidgets.staticRender()` intenta inicializarlos todos al cargar.

**Solución de navreport:**

1. Los gráficos se serializan como `<script type="text/nr-deferred">` —
   un tipo desconocido para HTMLWidgets → se ignoran al cargarse.
2. Solo los gráficos de la **primera página visible** se activan
   durante `window.onload`.
3. Cuando el usuario navega a una nueva página, los scripts se
   cambian a `type="application/json"` y se llama
   `HTMLWidgets.staticRender()` de nuevo (idempotente).
4. **Resultado:** un documento con 200 gráficos abre en < 5 segundos
   porque solo 2–3 gráficos se renderizan inicialmente.

---

## 🗂 Subir el paquete a GitHub

Si desea publicar navreport para que otros usuarios puedan instalarlo:

```bash
# 1. Inicializar repositorio git en la carpeta del paquete
cd navreport_pkg
git init
git add .
git commit -m "feat: initial navreport package"

# 2. Crear repositorio en GitHub (en github.com) y conectar
git remote add origin https://github.com/TU_USUARIO/navreport.git
git branch -M main
git push -u origin main
```

Luego cualquier usuario puede instalar con:

```r
devtools::install_github("TU_USUARIO/navreport")
```

---

## 📦 Dependencias requeridas

| Paquete | Rol | Obligatorio |
|---|---|---|
| `rmarkdown` | Output format | ✅ |
| `htmltools` | HTML helpers | ✅ |
| `jsonlite`  | Serialización de widgets | ✅ |
| `knitr`     | Renderizado | ✅ |
| `highcharter` | Gráficos interactivos | opcional |
| `plotly`    | ggplot2 → interactivo | opcional |
| `ggplot2`   | Gráficos estáticos | opcional |
| `echarts4r` | ECharts | opcional |
| `dplyr`     | Transformación de datos | opcional |
| `tidyr`     | Pivots | opcional |
| `DT`        | Tablas interactivas | opcional |

---

## 📄 Licencia

MIT © 2025

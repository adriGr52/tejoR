# Especificacion del artefacto crosswalk (tejo-crosswalk/0.2) -- lado R.
# Contrato identico al paquete Python 'tejo': integridad por sha256, columnas
# minimas (source_id, target_id, weight) e invariantes re-verificados al cargar.

.SPEC_PREFIJO <- "tejo-crosswalk/"
.SPEC_VERSION <- "tejo-crosswalk/0.2"

`%||%` <- function(a, b) if (is.null(a)) b else a

.convertir_columnas <- function(tab, sid, tid) {
  for (nm in names(tab)) {
    if (nm %in% c(sid, tid)) { tab[[nm]] <- as.character(tab[[nm]]); next }
    x <- tab[[nm]]
    if (is.character(x)) {
      solo_bool <- all(x %in% c("True", "False", "TRUE", "FALSE", "true", "false"))
      if (solo_bool) { tab[[nm]] <- x %in% c("True", "TRUE", "true"); next }
      num <- suppressWarnings(as.numeric(x))
      if (!anyNA(num[!is.na(x) & x != ""])) tab[[nm]] <- num
    }
  }
  tab
}

#' Valida los invariantes de un crosswalk
#'
#' Re-verifica el contrato de la especificacion 'tejo-crosswalk/0.2':
#' pesos no negativos y filas que suman 1 por unidad fuente (pycnofilaxis),
#' salvo que los metadatos declaren \code{renormalize = FALSE}.
#'
#' @param cw Objeto de clase \code{tejo_crosswalk} (lista con \code{tabla} y
#'   \code{meta}), creado por \code{\link{construir_crosswalk}} o
#'   \code{\link{cargar_crosswalk}}.
#' @param atol Tolerancia absoluta para la suma de pesos por fuente.
#' @return Lista con el reporte de invariantes: \code{n_fuentes},
#'   \code{n_pares}, \code{no_negatividad}, \code{filas_suman_1} y
#'   \code{desviacion_max_suma_filas}. Detiene con error si se violan.
#' @examples
#' rect <- function(x0, y0, x1, y1)
#'   sf::st_polygon(list(rbind(c(x0, y0), c(x1, y0), c(x1, y1),
#'                             c(x0, y1), c(x0, y0))))
#' src <- sf::st_sf(sid = "S1", geometry = sf::st_sfc(rect(0, 0, 2, 2)),
#'                  crs = 3116)
#' tgt <- sf::st_sf(tid = c("T1", "T2"),
#'                  geometry = sf::st_sfc(rect(0, 0, 1, 2), rect(1, 0, 2, 2)),
#'                  crs = 3116)
#' cw <- construir_crosswalk(src, tgt, "sid", "tid", method = "area")
#' validar_crosswalk(cw)
#' @export
validar_crosswalk <- function(cw, atol = 1e-6) {
  tab <- cw$tabla
  sid <- cw$meta$source_id
  sums <- tapply(tab$weight, tab[[sid]], sum)
  rep <- list(
    n_fuentes = length(sums),
    n_pares = nrow(tab),
    no_negatividad = all(tab$weight >= -1e-12),
    filas_suman_1 = all(abs(sums - 1) <= atol),
    desviacion_max_suma_filas = max(abs(sums - 1))
  )
  renorm <- cw$meta$renormalize %||% TRUE
  if (!rep$no_negatividad || (isTRUE(renorm) && !rep$filas_suman_1)) {
    stop("Invariantes del crosswalk violados: desviacion_max=",
         format(rep$desviacion_max_suma_filas), call. = FALSE)
  }
  rep
}

#' @rdname crosswalk_io
#' @export
cargar_crosswalk <- function(base, validate = TRUE) {
  meta <- jsonlite::fromJSON(paste0(base, ".meta.json"),
                             simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
  if (!startsWith(meta$spec_version %||% "", .SPEC_PREFIJO)) {
    stop("integridad: spec_version ausente o desconocida.", call. = FALSE)
  }
  csv <- paste0(base, ".csv")
  if (validate) {
    h <- digest::digest(file = csv, algo = "sha256")
    if (!identical(h, meta$sha256_tabla)) {
      stop("integridad: el sha256 de la tabla no coincide con el sello; ",
           "el artefacto fue alterado despues de guardarse.", call. = FALSE)
    }
  }
  sid <- meta$source_id; tid <- meta$target_id
  tab <- utils::read.csv(csv, check.names = FALSE, colClasses = "character")
  tab <- .convertir_columnas(tab, sid, tid)
  faltan <- setdiff(c(sid, tid, "weight"), names(tab))
  if (length(faltan)) stop("integridad: columnas minimas ausentes: ",
                           paste(faltan, collapse = ", "), call. = FALSE)
  cw <- structure(list(tabla = tab, meta = meta), class = "tejo_crosswalk")
  if (validate) validar_crosswalk(cw)
  cw
}

#' Guardar y cargar crosswalks sellados
#'
#' \code{guardar_crosswalk} escribe \code{<base>.csv} mas
#' \code{<base>.meta.json} con sello 'SHA-256' de la tabla y numericos a 17
#' digitos significativos (fidelidad de doble precision).
#' \code{cargar_crosswalk} lee el par de archivos y, con
#' \code{validate = TRUE}, verifica version de la especificacion, integridad
#' del sello, columnas minimas e invariantes. Un artefacto alterado en un solo
#' byte produce error de integridad.
#'
#' @param cw Objeto \code{tejo_crosswalk} a sellar.
#' @param base Ruta base de los archivos, sin extension (se agregan
#'   \code{.csv} y \code{.meta.json}).
#' @param extra_meta Lista opcional de metadatos adicionales a incorporar.
#' @param validate Logico; si \code{TRUE} (defecto) verifica sello e
#'   invariantes al cargar.
#' @return \code{guardar_crosswalk} devuelve, de forma invisible, la lista de
#'   metadatos sellados (incluye \code{sha256_tabla} y
#'   \code{spec_version}). \code{cargar_crosswalk} devuelve el objeto
#'   \code{tejo_crosswalk} reconstruido (lista con \code{tabla} y
#'   \code{meta}).
#' @examples
#' rect <- function(x0, y0, x1, y1)
#'   sf::st_polygon(list(rbind(c(x0, y0), c(x1, y0), c(x1, y1),
#'                             c(x0, y1), c(x0, y0))))
#' src <- sf::st_sf(sid = "S1", geometry = sf::st_sfc(rect(0, 0, 2, 2)),
#'                  crs = 3116)
#' tgt <- sf::st_sf(tid = c("T1", "T2"),
#'                  geometry = sf::st_sfc(rect(0, 0, 1, 2), rect(1, 0, 2, 2)),
#'                  crs = 3116)
#' cw <- construir_crosswalk(src, tgt, "sid", "tid", method = "area")
#' base <- tempfile("cw_")
#' guardar_crosswalk(cw, base, extra_meta = list(nota = "ejemplo"))
#' cw2 <- cargar_crosswalk(base, validate = TRUE)
#' all.equal(cw2$tabla$weight, cw$tabla$weight)
#' @rdname crosswalk_io
#' @export
guardar_crosswalk <- function(cw, base, extra_meta = list()) {
  validar_crosswalk(cw)
  csv <- paste0(base, ".csv")
  dir.create(dirname(csv), recursive = TRUE, showWarnings = FALSE)
  df <- cw$tabla
  es_num <- vapply(df, is.numeric, logical(1))
  df[es_num] <- lapply(df[es_num], function(x)
    trimws(format(x, digits = 17, scientific = FALSE)))
  utils::write.csv(df, csv, row.names = FALSE, quote = FALSE)
  meta <- utils::modifyList(cw$meta, extra_meta)
  meta$spec_version <- .SPEC_VERSION
  meta$columnas <- names(cw$tabla)
  meta$sha256_tabla <- digest::digest(file = csv, algo = "sha256")
  meta$software <- list(tejoR = as.character(utils::packageVersion("tejoR")))
  meta$sellado_utc <- format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ")
  jsonlite::write_json(meta, paste0(base, ".meta.json"),
                       auto_unbox = TRUE, pretty = TRUE, digits = NA)
  invisible(meta)
}

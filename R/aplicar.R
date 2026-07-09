# Aplicacion del crosswalk. Reglas duras compartidas con el lado Python:
# extensivas se suman con W; intensivas son media ponderada por masa declarada;
# las TASAS jamas se interpolan directamente (numerador y denominador por
# separado; denominador 0 -> NA, nunca Inf); NA contamina (sin imputacion
# silenciosa: sum() de R ya propaga NA por defecto, y eso es una feature).

#' Aplica un crosswalk a datos tabulares segun el tipo de variable
#'
#' Reglas duras compartidas con el gemelo 'Python': las variables EXTENSIVAS
#' se suman con W; las INTENSIVAS son media ponderada por la masa declarada
#' (o por el area de interseccion si no se declara, supuesto documentado);
#' las TASAS jamas se interpolan directamente: se declaran como
#' \code{c(nombre, numerador, denominador)}, se trasladan ambos componentes y
#' el cociente devuelve \code{NA} (nunca \code{Inf}) ante denominador cero.
#' Los \code{NA} contaminan a sus destinos: sin imputacion silenciosa.
#'
#' @param cw Objeto \code{tejo_crosswalk}.
#' @param datos data.frame con una fila por unidad fuente (debe traer la
#'   columna identificadora de la fuente).
#' @param extensivas,intensivas Vectores con nombres de columnas.
#' @param tasas Lista de vectores \code{c(nombre_salida, col_numerador,
#'   col_denominador)}.
#' @param masa Nombre de la columna de masa para las intensivas (recomendado,
#'   p. ej. poblacion).
#' @return data.frame con una fila por unidad destino y las variables
#'   trasladadas; para cada tasa agrega \code{<nombre>_num} y
#'   \code{<nombre>_den}. Incluye los atributos \code{fuentes_sin_datos} y
#'   \code{fuentes_fuera_del_crosswalk}.
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
#' datos <- data.frame(sid = "S1", casos = 20, pob = 400)
#' aplicar_crosswalk(cw, datos, extensivas = "casos",
#'                   tasas = list(c("tasa", "casos", "pob")))
#' @export
aplicar_crosswalk <- function(cw, datos,
                              extensivas = character(),
                              intensivas = character(),
                              tasas = list(),
                              masa = NULL) {
  sid <- cw$meta$source_id; tid <- cw$meta$target_id
  dup <- intersect(extensivas, intensivas)
  if (length(dup)) {
    stop("Columnas declaradas extensivas e intensivas a la vez: ",
         paste(dup, collapse = ", "),
         ". Una variable no puede ser ambas; decide su naturaleza.", call. = FALSE)
  }
  for (t in tasas) {
    if (length(t) != 3) stop("Cada tasa es c(nombre, numerador, denominador).", call. = FALSE)
    for (col in t[2:3]) if (!col %in% names(datos)) {
      stop("Tasa '", t[1], "': falta la columna '", col, "'.", call. = FALSE)
    }
  }
  for (col in c(extensivas, intensivas)) if (!col %in% names(datos)) {
    stop("Falta la columna '", col, "' en los datos.", call. = FALSE)
  }
  if (!sid %in% names(datos)) stop("Los datos no traen la columna fuente '", sid, "'.", call. = FALSE)
  if (anyDuplicated(datos[[sid]])) {
    stop("'", sid, "' esta duplicado en los datos; agrega antes de aplicar.", call. = FALSE)
  }

  tab <- merge(cw$tabla[, c(sid, tid, "weight", "area_interseccion")],
               datos, by = sid, all.x = TRUE, sort = FALSE)
  sin_datos <- unique(tab[[sid]][!tab[[sid]] %in% datos[[sid]]])
  grp <- factor(tab[[tid]])
  niveles <- levels(grp)

  res <- data.frame(row.names = niveles)
  res[[tid]] <- niveles

  ext_need <- union(extensivas, unlist(lapply(tasas, function(t) t[2:3])))
  ext <- list()
  for (col in ext_need) {
    v <- tapply(tab$weight * tab[[col]], grp, sum)   # NA venenoso por diseno
    ext[[col]] <- as.numeric(v[niveles])
    if (col %in% extensivas) res[[col]] <- ext[[col]]
  }
  if (length(intensivas)) {
    m <- if (!is.null(masa)) {
      if (!masa %in% names(tab)) stop("masa '", masa, "' no esta en los datos.", call. = FALSE)
      tab$weight * tab[[masa]]
    } else tab$area_interseccion
    den_m <- as.numeric(tapply(m, grp, sum)[niveles])
    for (col in intensivas) {
      num_m <- as.numeric(tapply(m * tab[[col]], grp, sum)[niveles])
      res[[col]] <- num_m / den_m
    }
  }
  for (t in tasas) {
    nom <- t[1]; n <- ext[[t[2]]]; d <- ext[[t[3]]]
    r <- n / d
    r[!is.na(d) & d == 0] <- NA_real_   # denominador 0 -> NA, no Inf
    res[[nom]] <- r
    res[[paste0(nom, "_num")]] <- n
    res[[paste0(nom, "_den")]] <- d
  }
  attr(res, "fuentes_sin_datos") <- as.character(sin_datos)
  attr(res, "fuentes_fuera_del_crosswalk") <- setdiff(datos[[sid]], cw$tabla[[sid]])
  res
}

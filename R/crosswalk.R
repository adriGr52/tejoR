# Construccion de crosswalks con sf. Mismas garantias que el lado Python:
# sin reproyeccion silenciosa, CRS proyectado obligatorio, fallback marcado,
# pesos no negativos que suman 1 por fuente (pycnofilaxis).

.limpiar_capa <- function(g, id, nombre) {
  if (!inherits(g, "sf")) stop("'", nombre, "' debe ser un objeto sf.", call. = FALSE)
  if (is.na(sf::st_crs(g))) stop("La capa '", nombre, "' no tiene CRS definido.", call. = FALSE)
  if (isTRUE(sf::st_is_longlat(g))) {
    stop("La capa '", nombre, "' esta en CRS geografico; reproyecta a uno proyectado ",
         "(p. ej. EPSG:9377) antes de calcular areas.", call. = FALSE)
  }
  if (!id %in% names(g)) stop("La columna id '", id, "' no existe en '", nombre, "'.", call. = FALSE)
  if (anyNA(g[[id]])) stop("Identificadores nulos en '", nombre, "'.", call. = FALSE)
  g <- sf::st_make_valid(g[, id])
  g[[id]] <- as.character(g[[id]])
  if (anyDuplicated(g[[id]])) {  # multipartes registradas por filas: disolver
    ids <- unique(g[[id]])
    geoms <- lapply(ids, function(i) sf::st_union(sf::st_geometry(g)[g[[id]] == i]))
    g <- sf::st_sf(stats::setNames(data.frame(ids, stringsAsFactors = FALSE), id),
                   geometry = do.call(c, geoms), crs = sf::st_crs(g))
  }
  g[!sf::st_is_empty(g), ]
}

.solo_poligonos <- function(x) {
  x <- suppressWarnings(sf::st_collection_extract(x, "POLYGON"))
  x[as.numeric(sf::st_area(x)) > 0, ]
}

#' Construye la matriz de ponderadores W entre dos mallas
#'
#' Estima w_ij, la fraccion de cada unidad fuente asignada a cada unidad
#' destino, por ponderacion de area o dasimetrica (masa continua de una capa
#' ancilar, con reparto 'areal' o por punto interior 'centroid'). Garantias:
#' sin reproyeccion silenciosa (CRS proyectado identico obligatorio), fuentes
#' con masa ancilar nula caen a pesos de area de forma marcada (columna
#' \code{fallback_area}) y los invariantes se verifican al construir.
#'
#' @param source,target Objetos \code{sf} poligonales en el mismo CRS
#'   proyectado.
#' @param source_id,target_id Nombres de las columnas identificadoras.
#' @param method \code{"area"} o \code{"dasymetric"}.
#' @param ancillary Capa \code{sf} con la masa ancilar (p. ej., manzanas
#'   censales con poblacion). Obligatoria para el metodo dasimetrico.
#' @param ancillary_mass Nombre de la columna de masa en \code{ancillary}.
#' @param ancillary_assignment \code{"areal"} (masa repartida proporcional al
#'   area del poligono ancilar en cada pieza) o \code{"centroid"} (toda la
#'   masa al punto interior).
#' @param renormalize Logico; renormaliza por cobertura para tolerar slivers
#'   de borde, dejando registro de la cobertura bruta por fuente.
#' @param coverage_warn Umbral de cobertura bajo el cual se agrega una
#'   advertencia a los metadatos.
#' @return Objeto \code{tejo_crosswalk}: lista con \code{tabla} (data.frame
#'   con \code{weight}, \code{w_area}, \code{area_interseccion},
#'   \code{cobertura_area}, \code{fallback_area} y, si aplica,
#'   \code{masa_int}) y \code{meta} (metodo, CRS, conteos, cobertura,
#'   advertencias).
#' @examples
#' rect <- function(x0, y0, x1, y1)
#'   sf::st_polygon(list(rbind(c(x0, y0), c(x1, y0), c(x1, y1),
#'                             c(x0, y1), c(x0, y0))))
#' src <- sf::st_sf(sid = "S1", geometry = sf::st_sfc(rect(0, 0, 2, 2)),
#'                  crs = 3116)
#' tgt <- sf::st_sf(tid = c("T1", "T2"),
#'                  geometry = sf::st_sfc(rect(0, 0, 1, 2), rect(1, 0, 2, 2)),
#'                  crs = 3116)
#' mz <- sf::st_sf(pob = c(1, 1, 9, 9),
#'                 geometry = sf::st_sfc(rect(0, 0, 1, 1), rect(0, 1, 1, 2),
#'                                       rect(1, 0, 2, 1), rect(1, 1, 2, 2)),
#'                 crs = 3116)
#' cw <- construir_crosswalk(src, tgt, "sid", "tid", method = "dasymetric",
#'                           ancillary = mz, ancillary_mass = "pob")
#' cw$tabla[, c("sid", "tid", "weight")]  # 0.1 y 0.9: manda la masa, no el area
#' @export
construir_crosswalk <- function(source, target, source_id, target_id,
                                method = c("area", "dasymetric"),
                                ancillary = NULL, ancillary_mass = NULL,
                                ancillary_assignment = c("areal", "centroid"),
                                renormalize = TRUE, coverage_warn = 0.99) {
  method <- match.arg(method)
  ancillary_assignment <- match.arg(ancillary_assignment)
  src <- .limpiar_capa(source, source_id, "source")
  tgt <- .limpiar_capa(target, target_id, "target")
  if (sf::st_crs(src) != sf::st_crs(tgt)) {
    stop("source y target deben compartir CRS; reproyecta explicitamente ",
         "(este paquete no reproyecta en silencio).", call. = FALSE)
  }

  piezas <- .solo_poligonos(suppressWarnings(sf::st_intersection(src, tgt)))
  piezas$area_interseccion <- as.numeric(sf::st_area(piezas))
  a_src <- stats::setNames(as.numeric(sf::st_area(src)), src[[source_id]])
  piezas$w_bruto <- piezas$area_interseccion / a_src[piezas[[source_id]]]

  cob <- tapply(piezas$w_bruto, piezas[[source_id]], sum)
  sin_cobertura <- setdiff(src[[source_id]], names(cob))
  tab <- sf::st_drop_geometry(piezas)[, c(source_id, target_id, "area_interseccion", "w_bruto")]
  tab$cobertura_area <- as.numeric(cob[tab[[source_id]]])
  tab$w_area <- if (renormalize) tab$w_bruto / tab$cobertura_area else tab$w_bruto

  if (method == "area") {
    tab$weight <- tab$w_area
    tab$fallback_area <- FALSE
  } else {
    if (is.null(ancillary) || is.null(ancillary_mass)) {
      stop("El metodo dasimetrico requiere 'ancillary' y 'ancillary_mass'.", call. = FALSE)
    }
    if (sf::st_crs(ancillary) != sf::st_crs(src)) {
      stop("'ancillary' debe compartir CRS con source/target.", call. = FALSE)
    }
    if (!ancillary_mass %in% names(ancillary)) {
      stop("'", ancillary_mass, "' no esta en la capa ancilar.", call. = FALSE)
    }
    if (any(ancillary[[ancillary_mass]] < 0, na.rm = TRUE)) {
      stop("Masas ancilares negativas: revisa la variable ancilar.", call. = FALSE)
    }
    anc <- ancillary[, ancillary_mass]
    if (ancillary_assignment == "areal") {
      anc$.a0 <- as.numeric(sf::st_area(anc))
      anc <- anc[anc$.a0 > 0, ]
      frag <- .solo_poligonos(suppressWarnings(
        sf::st_intersection(anc, piezas[, c(source_id, target_id)])))
      frag$.m <- frag[[ancillary_mass]] * as.numeric(sf::st_area(frag)) / frag$.a0
    } else {
      pts <- anc
      sf::st_geometry(pts) <- sf::st_point_on_surface(sf::st_geometry(anc))
      frag <- sf::st_join(pts, piezas[, c(source_id, target_id)],
                          join = sf::st_within, left = FALSE)
      frag$.m <- frag[[ancillary_mass]]
    }
    fd <- sf::st_drop_geometry(frag)
    magg <- stats::aggregate(fd$.m, by = list(fd[[source_id]], fd[[target_id]]), FUN = sum)
    names(magg) <- c(source_id, target_id, "masa_int")
    tab <- merge(tab, magg, by = c(source_id, target_id), all.x = TRUE, sort = FALSE)
    tab$masa_int[is.na(tab$masa_int)] <- 0
    smass <- stats::ave(tab$masa_int, tab[[source_id]], FUN = sum)
    tab$fallback_area <- smass <= 1e-12
    tab$weight <- ifelse(tab$fallback_area, tab$w_area, tab$masa_int / smass)
  }

  epsg <- sf::st_crs(src)$epsg
  meta <- list(
    metodo = method,
    crs = if (!is.na(epsg)) paste0("EPSG:", epsg) else sf::st_crs(src)$input,
    source_id = source_id, target_id = target_id,
    n_fuentes = nrow(src), n_destinos = nrow(tgt),
    fuentes_sin_cobertura = as.list(sin_cobertura),
    cobertura_area_min = min(cob), cobertura_area_media = mean(cob),
    renormalize = renormalize,
    asignacion_ancilar = if (method == "dasymetric") ancillary_assignment else NULL,
    creado_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    advertencias = list()
  )
  if (any(cob < coverage_warn)) {
    meta$advertencias <- c(meta$advertencias, paste0(
      sum(cob < coverage_warn), " fuente(s) con cobertura de area < ", coverage_warn,
      ": posibles desajustes de borde entre capas."))
  }
  cols <- c(source_id, target_id, "weight", "w_area", "area_interseccion",
            "cobertura_area", "fallback_area",
            if (method == "dasymetric") "masa_int")
  tab <- tab[order(tab[[source_id]], -tab$weight), cols]
  rownames(tab) <- NULL
  cw <- structure(list(tabla = tab, meta = meta), class = "tejo_crosswalk")
  validar_crosswalk(cw)
  cw
}

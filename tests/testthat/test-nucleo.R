# Oraculos analiticos espejo de la suite Python: mismos mundos sinteticos,
# mismas exactitudes exigidas. Si ambos gemelos pasan los mismos oraculos y
# ademas validan el mismo artefacto sellado, el contrato es uno solo.
library(tejoR)
suppressMessages(library(sf))

CRS <- 3116; NX <- 12; NY <- 12; CELL <- 100

malla <- function() {
  df <- expand.grid(ix = 0:(NX - 1), iy = 0:(NY - 1))
  geoms <- lapply(seq_len(nrow(df)), function(k) {
    x0 <- df$ix[k] * CELL; y0 <- df$iy[k] * CELL
    sf::st_polygon(list(matrix(c(x0, y0, x0 + CELL, y0, x0 + CELL, y0 + CELL,
                                 x0, y0 + CELL, x0, y0), ncol = 2, byrow = TRUE)))
  })
  g <- sf::st_sf(df, geometry = sf::st_sfc(geoms, crs = CRS))
  g$pob <- 1 + 3 * g$iy
  g$hog <- 0.4 * g$pob
  g$eventos <- g$pob * (0.05 + 0.02 * g$iy)
  g
}

zonas <- function(g, key, id, pref) {
  ids <- sort(unique(key))
  geoms <- lapply(ids, function(k) sf::st_union(sf::st_geometry(g)[key == k]))
  out <- sf::st_sf(stats::setNames(data.frame(paste0(pref, ids), stringsAsFactors = FALSE), id),
                   geometry = do.call(c, geoms))
  sf::st_crs(out) <- sf::st_crs(g)
  out
}

# verdad micro->zona (las celdas anidan en las zonas de prueba: asignacion por
# punto interior es EXACTA aqui; el caso no anidado lo cubre el lado Python)
verdad <- function(g, z, zid, cols) {
  pts <- g; sf::st_geometry(pts) <- sf::st_point_on_surface(sf::st_geometry(g))
  j <- sf::st_drop_geometry(sf::st_join(pts, z, join = sf::st_within, left = FALSE))
  out <- stats::aggregate(j[cols], by = list(zid = j[[zid]]), FUN = sum)
  stats::setNames(out, c(zid, cols))
}

g <- malla()
src <- zonas(g, g$ix %/% 3, "sid", "S")     # 4 franjas verticales
tgt_x <- zonas(g, g$iy %/% 4, "tid", "T")   # 3 bandas horizontales (CRUZADO)
tgt_n <- zonas(g, g$ix %/% 6, "tid", "N")   # uniones de fuentes (ANIDADO)
src_datos <- verdad(g, src, "sid", c("pob", "hog", "eventos"))

test_that("invariantes: no negatividad y filas que suman 1, ambos metodos", {
  for (cw in list(
    construir_crosswalk(src, tgt_x, "sid", "tid", "area"),
    construir_crosswalk(src, tgt_x, "sid", "tid", "dasymetric",
                        ancillary = g, ancillary_mass = "pob"))) {
    rep <- validar_crosswalk(cw)
    expect_true(rep$no_negatividad)
    expect_true(rep$filas_suman_1)
    expect_lt(rep$desviacion_max_suma_filas, 1e-9)
  }
})

test_that("anidamiento => interpolacion extensiva EXACTA", {
  cw <- construir_crosswalk(src, tgt_n, "sid", "tid", "area")
  est <- aplicar_crosswalk(cw, src_datos, extensivas = c("pob", "hog", "eventos"))
  tru <- verdad(g, tgt_n, "tid", c("pob", "hog", "eventos"))
  j <- merge(est, tru, by = "tid", suffixes = c("_e", "_v"))
  for (col in c("pob", "hog", "eventos")) {
    expect_equal(j[[paste0(col, "_e")]], j[[paste0(col, "_v")]], tolerance = 1e-10)
  }
})

test_that("dasimetrico exacto para variable proporcional al ancilar; area falla", {
  cw_d <- construir_crosswalk(src, tgt_x, "sid", "tid", "dasymetric",
                              ancillary = g, ancillary_mass = "pob")
  cw_a <- construir_crosswalk(src, tgt_x, "sid", "tid", "area")
  tru <- verdad(g, tgt_x, "tid", c("pob", "hog"))
  e_d <- aplicar_crosswalk(cw_d, src_datos, extensivas = c("pob", "hog"))
  e_a <- aplicar_crosswalk(cw_a, src_datos, extensivas = c("pob", "hog"))
  jd <- merge(e_d, tru, by = "tid", suffixes = c("_e", "_v"))
  ja <- merge(e_a, tru, by = "tid", suffixes = c("_e", "_v"))
  expect_lt(max(abs(jd$pob_e - jd$pob_v)), 1e-8)
  expect_lt(max(abs(jd$hog_e - jd$hog_v)), 1e-8)
  expect_gt(mean(abs(ja$pob_e - ja$pob_v)), 10)
})

test_that("tasas: identidad num/den, exactitud anidada y den 0 -> NA", {
  cw_x <- construir_crosswalk(src, tgt_x, "sid", "tid", "dasymetric",
                              ancillary = g, ancillary_mass = "pob")
  out <- aplicar_crosswalk(cw_x, src_datos, tasas = list(c("tasa", "eventos", "pob")))
  ok <- !is.na(out$tasa_den) & out$tasa_den > 0
  expect_equal(out$tasa[ok], out$tasa_num[ok] / out$tasa_den[ok], tolerance = 1e-12)

  cw_n <- construir_crosswalk(src, tgt_n, "sid", "tid", "area")
  out_n <- aplicar_crosswalk(cw_n, src_datos, tasas = list(c("tasa", "eventos", "pob")))
  tru <- verdad(g, tgt_n, "tid", c("eventos", "pob"))
  j <- merge(out_n, tru, by = "tid")
  expect_equal(j$tasa, j$eventos / j$pob, tolerance = 1e-10)

  d0 <- src_datos; d0$pob <- 0
  out0 <- aplicar_crosswalk(cw_n, d0, tasas = list(c("tasa", "eventos", "pob")))
  expect_true(all(is.na(out0$tasa)))
  expect_false(any(is.infinite(out0$tasa)))
})

test_that("NA venenoso: la fuente con NA contamina sus destinos, no los ajenos", {
  cw <- construir_crosswalk(src, tgt_n, "sid", "tid", "area")  # S0,S1->N0; S2,S3->N1
  d <- src_datos; d$pob[d$sid == "S0"] <- NA
  out <- aplicar_crosswalk(cw, d, extensivas = "pob")
  expect_true(is.na(out["N0", "pob"]))
  expect_false(is.na(out["N1", "pob"]))
})

test_that("fallback por masa ancilar cero: marcado y con pesos de area", {
  g2 <- g; g2$pob[g2$ix < 3] <- 0
  cw <- construir_crosswalk(src, tgt_x, "sid", "tid", "dasymetric",
                            ancillary = g2, ancillary_mass = "pob")
  t0 <- cw$tabla[cw$tabla$sid == "S0", ]
  expect_true(all(t0$fallback_area))
  expect_false(any(cw$tabla$fallback_area[cw$tabla$sid != "S0"]))
  expect_equal(t0$weight, t0$w_area, tolerance = 1e-12)
  expect_true(validar_crosswalk(cw)$filas_suman_1)
})

test_that("guardias explicitas: CRS geografico, CRS distintos, doble declaracion", {
  expect_error(construir_crosswalk(sf::st_transform(src, 4326),
                                   sf::st_transform(tgt_x, 4326), "sid", "tid"),
               "geografico")
  expect_error(construir_crosswalk(src, sf::st_transform(tgt_x, 9377), "sid", "tid"),
               "compartir CRS")
  cw <- construir_crosswalk(src, tgt_x, "sid", "tid", "area")
  expect_error(aplicar_crosswalk(cw, src_datos, extensivas = "pob", intensivas = "pob"),
               "extensivas e intensivas")
})

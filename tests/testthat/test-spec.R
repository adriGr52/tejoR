# Interoperabilidad de la especificacion: un artefacto sellado por el gemelo
# Python debe cargar, validar y coincidir en valores en R; alterarlo un byte
# debe romper el sello; y el ciclo guardar->cargar en R debe ser fiel.
library(tejoR)

test_that("artefacto sellado por Python: carga, valida y coincide en valores", {
  base <- testthat::test_path("fixtures", "cw_py")
  cw <- cargar_crosswalk(base, validate = TRUE)
  expect_s3_class(cw, "tejo_crosswalk")
  expect_true(startsWith(cw$meta$spec_version, "tejo-crosswalk/"))
  rep <- validar_crosswalk(cw)
  expect_true(rep$filas_suman_1 && rep$no_negatividad)
  w <- cw$tabla$weight[cw$tabla$sid == "S0" & cw$tabla$tid == "T0"]
  expect_equal(w, cw$meta$chequeo_interop$S0_T0, tolerance = 1e-15)
})

test_that("un byte alterado rompe el sello de integridad", {
  base <- testthat::test_path("fixtures", "cw_py")
  tmp <- file.path(tempdir(), "cw_tamper")
  file.copy(paste0(base, ".csv"), paste0(tmp, ".csv"), overwrite = TRUE)
  file.copy(paste0(base, ".meta.json"), paste0(tmp, ".meta.json"), overwrite = TRUE)
  cat(" ", file = paste0(tmp, ".csv"), append = TRUE)
  expect_error(cargar_crosswalk(tmp, validate = TRUE), "integridad")
})

test_that("ciclo guardar->cargar en R es fiel e integro", {
  base <- testthat::test_path("fixtures", "cw_py")
  cw <- cargar_crosswalk(base, validate = TRUE)
  tmp <- file.path(tempdir(), "cw_r")
  meta <- guardar_crosswalk(cw, tmp, extra_meta = list(nota = "resellado en R"))
  expect_true(startsWith(meta$spec_version, "tejo-crosswalk/"))
  cw2 <- cargar_crosswalk(tmp, validate = TRUE)
  j <- merge(cw$tabla[, c("sid", "tid", "weight")],
             cw2$tabla[, c("sid", "tid", "weight")],
             by = c("sid", "tid"), suffixes = c("", "_2"))
  expect_equal(nrow(j), nrow(cw$tabla))
  expect_equal(j$weight, j$weight_2, tolerance = 1e-15)
  expect_identical(cw2$meta$nota, "resellado en R")
})

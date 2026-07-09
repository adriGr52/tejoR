# Verificacion de equivalencia Python <-> R sobre Bogota real.
.libPaths("~/Rlibs"); suppressMessages({library(tejoR); library(sf)})
t0 <- Sys.time()

cw_py <- cargar_crosswalk("salidas/crosswalk_v090b/crosswalk_upz_upl_dasimetrico_v0.9.0b",
                          validate = TRUE)
cat("Sello Python validado en R | sha …",
    substr(cw_py$meta$sha256_tabla, 57, 64), "| pares:", nrow(cw_py$tabla), "\n")

upz <- st_read("data/upz_foncep_042023.gpkg", quiet = TRUE)
names(upz)[names(upz) == "UPLCODIGO"] <- "COD_UPZ"
upl <- st_transform(st_read("data/upl/UnidadPlaneamientoLocal.shp", quiet = TRUE), 9377)
mz  <- st_read("data/manzanas_bogota_cnpv.gpkg", quiet = TRUE)

cw_r <- construir_crosswalk(upz, upl, "COD_UPZ", "CODIGO_UPL", "dasymetric",
                            ancillary = mz, ancillary_mass = "TP27_PERSO")
cat("R reconstruyo", nrow(cw_r$tabla), "pares en",
    round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min\n")

j <- merge(cw_py$tabla[, c("COD_UPZ", "CODIGO_UPL", "weight")],
           cw_r$tabla[, c("COD_UPZ", "CODIGO_UPL", "weight")],
           by = c("COD_UPZ", "CODIGO_UPL"), suffixes = c("_py", "_r"), all = TRUE)
comunes <- !is.na(j$weight_py) & !is.na(j$weight_r)
dmax <- max(abs(j$weight_py[comunes] - j$weight_r[comunes]))
w_huerf <- c(j$weight_py[!comunes & !is.na(j$weight_py)],
             j$weight_r[!comunes & !is.na(j$weight_r)])
cat(sprintf("Pares comunes: %d | solo Python: %d | solo R: %d\n",
            sum(comunes), sum(is.na(j$weight_r)), sum(is.na(j$weight_py))))
cat(sprintf("|Dw| maximo en pares comunes = %.3e\n", dmax))
if (length(w_huerf)) cat(sprintf("peso maximo en pares exclusivos = %.3e (esperado ~0: slivers)\n",
                                 max(w_huerf)))
# w_max por UPZ debe coincidir (el funcional de gobernanza)
wm_py <- tapply(cw_py$tabla$weight, cw_py$tabla$COD_UPZ, max)
wm_r  <- tapply(cw_r$tabla$weight,  cw_r$tabla$COD_UPZ,  max)
cat(sprintf("|D w_max| maximo entre 116 UPZ = %.3e\n",
            max(abs(wm_py[names(wm_r)] - wm_r))))
stopifnot(dmax < 1e-6, length(w_huerf) == 0 || max(w_huerf) < 1e-6)
cat("VEREDICTO: equivalencia Python <-> R verificada (tolerancia 1e-6)\n")

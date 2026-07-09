# tejoR

[![R-CMD-check](https://github.com/adriGr52/tejoR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/adriGr52/tejoR/actions/workflows/R-CMD-check.yaml)

Armonizacion estadistica de series territoriales entre mallas geograficas que
cambian — caso beta: la transicion UPZ → UPL de Bogota (Decreto 555 de 2021).
Gemelo en R del paquete de Python ['tejo'](https://github.com/adriGr52), con el
mismo contrato verificado a 1e-12: crosswalks **sellados** (sha256 +
invariantes), metodo dasimetrico con ancilar vectorial via 'sf', tasas que
jamas se interpolan directamente y NA que se propaga en lugar de imputarse.

## Instalacion

```r
# desde GitHub (hoy)
remotes::install_github("adriGr52/tejoR")
# desde CRAN (tras aceptacion)
install.packages("tejoR")
```

## Uso minimo

```r
library(tejoR)
cw <- construir_crosswalk(upz, upl, "COD_UPZ", "CODIGO_UPL",
                          method = "dasymetric",
                          ancillary = manzanas, ancillary_mass = "PERSONAS")
guardar_crosswalk(cw, "crosswalk_upz_upl_v1")      # sella con sha256
serie_upl <- aplicar_crosswalk(cargar_crosswalk("crosswalk_upz_upl_v1"),
                               serie_upz,
                               extensivas = "nacimientos",
                               tasas = list(c("tasa", "nacimientos", "pob")))
```

## Garantias (verificadas en la suite: 34 expectativas)

Pesos no negativos que suman 1 por fuente; exactitud bajo anidamiento;
integridad: un byte alterado en un crosswalk sellado rompe la carga;
interoperabilidad byte-compatible con el gemelo Python.

## Cita

`citation("tejoR")`. Licencia MIT.

## Test environments
* local: Ubuntu 24.04, R 4.3.3 (sf 1.0-15, GEOS 3.12.1, GDAL 3.8.4, PROJ 9.4.0)
* R CMD check --as-cran ejecutado localmente

## R CMD check results
0 errors | 0 warnings | 1 note

* NOTE "unable to verify current time": entorno de compilacion sin acceso a
  servidores de hora; no aparece en win-builder ni en las maquinas de CRAN.
* Primera sumision ("New submission").

## Comentarios
* Los tests (34 expectativas) corren en ~10 s; los ejemplos en ~1 s.
* El paquete implementa la especificacion 'tejo-crosswalk/0.2', interoperable
  con el paquete de Python 'tejo' (equivalencia verificada a 1e-12 sobre el
  caso de uso completo de Bogota).

# ESTADO DE SUMISION — tejoR 0.2.1

> Documento generado por la mision de publicacion/pre-CRAN.
> **NO commiteado** (queda en la raiz del working tree como evidencia).
> Fecha de ejecucion: 2026-07-08/09 (UTC).

---

## ✅ ESTADO GLOBAL: repo publicado, CI 4/4 verde, listo para el acto humano

El unico bloqueador (CI de Windows en rojo por fin-de-linea del checkout) fue
**resuelto** con la Opcion A (`.gitattributes`), sin tocar el paquete ni el
tarball. Falta solo lo que es acto del maintainer humano: win-builder + el
formulario de CRAN + el clic de confirmacion (§4, §5, §6).

---

## 1. Integridad de insumos (regla 1) — ✅ OK

| Archivo | sha256 esperado | sha256 obtenido | Resultado |
|---|---|---|---|
| `tejoR_v0.2.1_fuente.zip` | `deaaa8…980bcc` | `deaaa8835928e224e908a2d32ae0ae6a17a437e3bedf859eaa911bb0fb980bcc` | ✅ COINCIDE |
| `tejoR_0.2.1.tar.gz` | `259e2a…a0ec07` | `259e2a83c34d6a96dfad3baa5e56dd3d87de4b4d523da4e47ab4d4446ba0ec07` | ✅ COINCIDE |

Verificacion adicional: todos los archivos reales del ZIP coinciden
**byte-a-byte** con los del tarball verificado (unica diferencia: `DESCRIPTION`,
que en el tarball trae los campos autogenerados por `R CMD build`
—`NeedsCompilation`, `Packaged`, `Author`, `Maintainer`— mas un reflujo de
indentacion; no es alteracion del fuente).

### Anomalia detectada en el ZIP (no bloqueante) — documentada
El ZIP contenia un directorio basura llamado literalmente `{R,tests`
(con `{R,tests/testthat/fixtures}` dentro). Son **directorios vacios**, sin
un solo byte de contenido, residuo de un `mkdir {R,tests}/testthat/fixtures`
donde la expansion de llaves nunca ocurrio. **No** esta en el manifiesto de la
mision, **no** esta en el tarball verificado, y git no versiona directorios
vacios. Se **excluyo** de la copia al repo. No se toco ningun archivo del
paquete.

---

## 2. Poblado del repo — ✅ OK

- Repo destino: https://github.com/adriGr52/tejoR (estaba **vacio**; sin
  contenido de plantilla → se procedio).
- Rama por defecto del repo era `analisis` (repo vacio). Por decision del
  maintainer se hizo push a **`main`** y se fijo `main` como rama por defecto
  (coherencia del badge). La rama `analisis` no tenia commits (unborn).
- Commits:
  - `1a81a18` — "tejoR 0.2.1 - paquete CRAN-ready (spec tejo-crosswalk/0.2)"
    (el fuente integro: 22 archivos).
  - `2369ea5` — "CI: sellar EOL de fixtures con sha256 (autocrlf rompia
    integridad en Windows)" (**solo** anade `.gitattributes`; NO toca el
    paquete — ver §3).
- Identidad de los commits (config **local** del repo, no global):
  `Luz Adriana Gutierrez Rodriguez <adrig63@gmail.com>` (coincide con Authors@R).
- Los blobs del paquete coinciden **byte-a-byte** con el fuente (LF preservado
  en el repositorio; `core.autocrlf` solo afecta la copia de trabajo, no el blob).
- El `.tar.gz` **NO** se subio al repo (regla 4). Sin tags, sin force-push,
  sin secretos (regla 3).

Sanity previo al commit: `DESCRIPTION` con `Version: 0.2.1`, `URL`/`BugReports`
del repo; existe `tests/testthat.R`; existe
`.github/workflows/R-CMD-check.yaml`. Todo ✅.

---

## 3. CI (R-CMD-check) — ✅ 4/4 VERDE (tras la correccion)

**Run final (verde):** https://github.com/adriGr52/tejoR/actions/runs/28987795111

| Plataforma | R | Resultado |
|---|---|---|
| ubuntu-latest | release | ✅ success |
| ubuntu-latest | devel | ✅ success |
| macos-latest | release | ✅ success |
| windows-latest | release | ✅ success |

Badge del README: **verde**. (Anotacion informativa de GitHub: `actions/checkout@v4`
usa Node 20 deprecado; es aviso del runner, no del paquete.)

### Que fallaba antes y como se resolvio (regla 2: diagnostico, no parche al fuente)

**Run inicial (rojo en Windows):**
https://github.com/adriGr52/tejoR/actions/runs/28985548193 — 3/4 verdes;
`windows-latest (release)` fallaba en `tests/testthat/test-spec.R` (lineas 8 y 28):
```
Error: integridad: el sha256 de la tabla no coincide con el sello; el
       artefacto fue alterado despues de guardarse.
  1. └─tejoR::cargar_crosswalk(base, validate = TRUE)
```

**Causa raiz (confirmada con hashes):** `cargar_crosswalk()` (`R/spec.R:78`)
recalcula `digest::digest(file=csv, sha256)` sobre los bytes en disco y los
compara con `sha256_tabla` del `.meta.json`. El runner de Windows de GitHub
tiene `git core.autocrlf=true`, asi que `actions/checkout` reescribia el CSV
sellado de LF a **CRLF**, cambiando sus bytes.

| Bytes evaluados | sha256 | ¿coincide con el sello? |
|---|---|---|
| Sello en `cw_py.meta.json` | `86e0e3a8…85128` | — |
| CSV del **tarball** (LF, lo que ve CRAN/win-builder) | `86e0e3a8…85128` | ✅ SI |
| CSV convertido a **CRLF** (lo que produjo el runner) | `546867…0edbb` | ❌ NO |

Era un artefacto del **checkout de git en Windows**, NO un defecto del paquete
(el tarball, LF, coincide con el sello → CRAN/win-builder pasan).

**Correccion aplicada (Opcion A, aprobada por el maintainer):** se anadio
`.gitattributes` en la raiz del repo marcando los artefactos sellados como
binarios para que git no traduzca su EOL:
```
tests/testthat/fixtures/*.csv  -text
tests/testthat/fixtures/*.json -text
```
Efecto: el checkout de Windows conserva LF → el sello coincide → 4/4 verde.
**`.gitattributes` NO forma parte del paquete** (no entra al tarball), **no**
altera ningun archivo del paquete, y **no** invalida el `tejoR_0.2.1.tar.gz`
verificado. El fuente del paquete quedo intacto (regla 2 respetada).

---

## 4. win-builder — ⏸ PENDIENTE (sin R local → carga manual, paso 4-bis)

No hay R instalado en esta maquina (`Rscript` no disponible), asi que no se
pudo disparar `devtools::check_win_devel()/check_win_release()`.

**Accion manual del maintainer** (usar el tarball YA verificado, sin
reempaquetar):
1. Ir a https://win-builder.r-project.org/upload.aspx
2. Subir `tejoR_0.2.1.tar.gz` a la carpeta **R-devel**.
3. Repetir la subida a la carpeta **R-release**.
4. Los resultados llegan por CORREO a **adrig63@gmail.com** en ~30–60 min
   (revisar spam). Criterio de exito: **0 errores / 0 warnings**; NOTEs
   admisibles solo del tipo "New submission".

> El tarball es LF-limpio, asi que el problema de Windows del CI **no** deberia
> reproducirse en win-builder. Si aun asi apareciera un error de integridad en
> win-builder, DETENERSE y reportar (seria entonces un defecto real del paquete).

---

## 5. Plantilla `cran-comments.md` — actualizable con el veredicto de win-builder

> Pega esto en `cran-comments.md` (reemplazando su contenido) una vez que
> lleguen los dos correos de win-builder. Rellena los `[[...]]`.

```markdown
## Test environments
* local: Ubuntu 24.04, R 4.3.3 (sf 1.0-15, GEOS 3.12.1, GDAL 3.8.4, PROJ 9.4.0)
  — R CMD check --as-cran: 0 errors | 0 warnings | 1 note
* GitHub Actions: ubuntu-latest (R release y R devel), macOS-latest (R release),
  windows-latest (R release) — R CMD check: OK en las 4
* win-builder R-devel:   [[pegar veredicto: p.ej. 0 errors | 0 warnings | 1 note]]
* win-builder R-release: [[pegar veredicto: p.ej. 0 errors | 0 warnings | 1 note]]

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
```

---

## 6. Checklist HUMANO final (actos del maintainer — la mision NO los ejecuta)

1. **win-builder** (§4): subir `tejoR_0.2.1.tar.gz` a R-devel y R-release.
2. **Leer los 2 correos** de win-builder en adrig63@gmail.com. Criterio:
   **0 errores / 0 warnings**; NOTEs admisibles solo "New submission".
3. **Actualizar `cran-comments.md`** con esos veredictos (plantilla en §5).
4. **Verificar** que el nombre siga libre:
   https://CRAN.R-project.org/package=tejoR (debe dar 404).
5. **Formulario CRAN:** https://cran.r-project.org/submit.html
   - Nombre y correo EXACTOS de Authors@R:
     **Luz Adriana Gutierrez Rodriguez / adrig63@gmail.com**
   - Subir **`tejoR_0.2.1.tar.gz`** (el verificado; NO reempaquetar).
   - Pegar el contenido de `cran-comments.md`.
6. **Clic en el enlace del correo de confirmacion** — sin ese clic NO hay
   sumision.

---

## Caveat para un eventual REBUILD (no aplica a esta sumision)

Esta sumision usa el `tejoR_0.2.1.tar.gz` **ya verificado** (no se reconstruye).
Si en el futuro el maintainer regenera el tarball con `R CMD build`, deberia
antes anadir a `.Rbuildignore` las lineas siguientes para que los archivos de
repo no entren al paquete ni generen NOTEs de "hidden/non-standard files":
```
^\.gitattributes$
^ESTADO_SUMISION\.md$
```
No se modifico `.Rbuildignore` ahora porque es parte del fuente y la sumision
no reconstruye el tarball (regla 2).

---

## Definicion de exito de la mision — estado FINAL

| Criterio | Estado |
|---|---|
| Repo poblado con el fuente integro (sha verificados) | ✅ |
| CI verde en las 4 plataformas | ✅ (run 28987795111) |
| win-builder disparado o instrucciones entregadas | ✅ (instrucciones manuales, §4) |
| ESTADO_SUMISION.md con checklist humano | ✅ (este archivo) |
| Ni un byte del paquete alterado | ✅ (solo se anadio `.gitattributes`, fuera del paquete) |

**Mision completada** hasta el limite acordado: todo queda listo ANTES del
formulario de CRAN. La sumision y el clic de confirmacion son actos del
maintainer humano (§6).

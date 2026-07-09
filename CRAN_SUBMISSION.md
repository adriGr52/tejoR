# Checklist de sumision a CRAN — tejoR 0.2.1

Estado: R CMD check --as-cran local = 0 ERROR / 0 WARNING / 0 NOTE.
Tarball submittable: tejoR_0.2.1.tar.gz (no lo reempaquetes sin re-correr check).

Pasos que quedan de tu lado, en orden:
1. (Opcional, recomendado) Crear el repo GitHub y agregar en DESCRIPTION:
   URL: https://github.com/<usuario>/tejoR
   BugReports: https://github.com/<usuario>/tejoR/issues
   Luego: R CMD build tejoR && R CMD check --as-cran del nuevo tarball.
2. Verificar nombre libre en el momento: https://CRAN.R-project.org/package=tejoR
   (debe dar 404).
3. win-builder con el tarball: https://win-builder.r-project.org/
   Subir a R-devel Y a R-release; los resultados llegan a adrig63@gmail.com
   (~30-60 min). Deben salir 0E/0W y a lo sumo el NOTE "New submission".
4. Leer una vez la CRAN Repository Policy (PDF en cran.r-project.org).
5. Someter: https://cran.r-project.org/submit.html
   - adjuntar tejoR_0.2.1.tar.gz y el contenido de cran-comments.md
   - confirmar el correo de verificacion que llega a adrig63@gmail.com
6. Responder con calma a los comentarios de los voluntarios si los hay
   (iteraciones son normales en primeras sumisiones).

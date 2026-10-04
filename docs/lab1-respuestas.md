# Respuestas — Laboratorio 1: Git Fundamentals

## 1. Working Directory, Staging Area y Local Repository

El Working Directory es la carpeta del proyecto que veo y modifico directamente en mi ordenador. La Staging Area es una zona intermedia donde selecciono los cambios concretos que quiero guardar en el siguiente commit. El Local Repository es el historial de commits almacenado localmente dentro de la carpeta `.git`.

Por ejemplo, modifico `README.md` en el Working Directory; después ejecuto `git add README.md` para llevar esa versión a la Staging Area; finalmente uso `git commit -m "docs: update README"` para guardarla en el historial local.

## 2. Cambio sin `git add`

No. Si modifico un archivo y no ejecuto `git add`, ese cambio no se incluye en el siguiente commit. `git commit` guarda únicamente los cambios que estén preparados previamente en la Staging Area.

## 3. Carpetas vacías

Git no controla carpetas vacías como objetos independientes; registra archivos. Por eso las carpetas vacías no aparecían en `git status`. Para conservarlas, añadimos dentro un archivo placeholder llamado `.gitkeep`.

## 4. HEAD

HEAD es el puntero que indica la posición actual de trabajo en Git. Normalmente apunta a la branch activa y, a través de ella, al último commit de esa rama. Al cambiar de branch con `git switch`, HEAD pasa a apuntar a la nueva branch y Git actualiza el Working Directory según su contenido.

## 5. Branch frente a carpeta

Crear una branch con `git switch -c feature/customer-search` crea una línea independiente de evolución dentro del historial de Git; no crea una carpeta física llamada `feature`. En cambio, `mkdir feature` sí crea una carpeta real en el disco. Lo comprobamos al ejecutar `ls -la`: al crear la branch no apareció ninguna carpeta nueva.

## 6. Marcadores de conflicto

El texto entre `<<<<<<< HEAD` y `=======` representa la versión que ya estaba en mi rama actual, que durante el ejercicio era `main`. El texto entre `=======` y `>>>>>>> fix/readme-subtitle` representa la versión que procedía de la rama que se estaba fusionando.

## 7. Por qué no hacer `--amend` tras `push`

No se debe usar `git commit --amend` sobre un commit ya publicado porque modifica ese commit y genera otro con un hash distinto. Si otras personas ya descargaron el historial anterior, sus ramas pueden divergir y la sincronización se complica. Para corregir un cambio público es más seguro crear un commit nuevo.

## 8. Borrar `.git`

Si borro la carpeta `.git`, pierdo la base de datos interna del repositorio: historial de commits, ramas, etiquetas, configuración local y referencias al remoto. El código fuente y los documentos que están fuera de `.git` permanecen en el disco, pero dejan de estar controlados por ese repositorio Git.

## 9. Diferencia entre Git y GitHub

Git es el sistema de control de versiones instalado en mi equipo: permite crear commits, ramas, merges y consultar el historial incluso sin conexión. GitHub es una plataforma que aloja repositorios Git y facilita colaborar mediante repositorios remotos, Pull Requests, revisiones, Issues y automatización.

## 10. Archivo `.env` con contraseñas

No se debe subir un archivo `.env` con credenciales reales porque una clave expuesta puede copiarse, descargarse o permanecer en el historial incluso si después se elimina el archivo. Un repositorio privado reduce la exposición, pero no elimina el riesgo: otros colaboradores o accesos indebidos podrían obtener las credenciales. Debe añadirse `.env` al archivo `.gitignore` y compartirse, si hace falta, una plantilla `.env.example` sin secretos.

## 11. Error non-fast-forward

Probablemente el repositorio remoto tiene commits que mi copia local todavía no tiene, por ejemplo porque se modificó un archivo desde GitHub u otro ordenador. Primero ejecutaría `git pull` para traer e integrar esos cambios; si aparece un conflicto lo resolvería, haría el commit necesario y después ejecutaría `git push`.

## 12. Tipos de Conventional Commits

Para añadir un índice de rendimiento a una tabla usaría `perf(db): add customer lookup index`, porque es una mejora de rendimiento. Para corregir una restricción mal definida usaría `fix(db): correct customer foreign key`, porque corrige un error. Para actualizar el README usaría `docs: update README`, porque es un cambio exclusivamente documental.
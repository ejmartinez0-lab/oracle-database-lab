# Laboratorio 3 — Respuestas de comprobación

Issue relacionado: #5

## Docker

### 1. ¿Qué diferencia hay entre una imagen y un contenedor?

Una imagen es una plantilla de solo lectura que contiene un programa y sus
dependencias. Un contenedor es una instancia creada a partir de esa imagen,
con sus procesos, configuración y capa de escritura.

En G2, hello-world ejecutó un programa a partir de su imagen y terminó.
En G4, entrar con docker exec permitió ejecutar otro proceso dentro de un
contenedor que ya estaba funcionando. Entrar en él no modifica la imagen.

### 2. ¿Por qué nota.txt desapareció en G5 y no en G6?

En G5, el archivo estaba en la capa de escritura del contenedor. Al eliminar
ese contenedor y crear otro, el nuevo no conservó el archivo.

En G6, el archivo estaba en un volumen. El volumen tiene un ciclo de vida
independiente y el nuevo contenedor pudo acceder al mismo contenido al
montarlo. Detener un contenedor, por sí solo, no borra su capa de escritura.

### 3. ¿Qué diferencia hay entre docker ps y docker ps -a?

docker ps muestra los contenedores en ejecución. docker ps -a muestra también
los detenidos.

Exited (0) significa que el proceso principal terminó y devolvió el código 0,
que normalmente indica una finalización correcta. No significa que siga
funcionando como servicio.

### 4. ¿Cómo se interpreta la publicación de puertos?

La sintaxis es -p PUERTO_DEL_EQUIPO:PUERTO_DEL_CONTENEDOR.

En -p 8181:8181, el primer 8181 pertenece al equipo y el segundo al contenedor.

Con -p 80:8080, las conexiones al puerto 80 del equipo se enviarían al 8080
del contenedor. Solo funcionaría si el servicio del contenedor escuchara en
8080. Si nginx escucha en su puerto habitual 80, habría que publicar ese
puerto interno, por ejemplo con -p 8080:80 para acceder desde el 8080 del equipo.

### 5. ¿Por qué Oracle permanece en marcha y hello-world termina?

Un contenedor permanece activo mientras continúa su proceso principal.
Oracle se ejecuta como un servicio de larga duración.

hello-world imprime su mensaje y termina su proceso principal. Por eso su
contenedor se detiene sin que eso sea un fallo.

### 6. ¿Qué es el digest y por qué registrarlo si usamos latest?

El digest es un identificador basado en el contenido de la imagen.
Permite identificar con precisión el artefacto descargado.

latest es una etiqueta que puede apuntar a otra imagen en el futuro.
Registrar el digest permite distinguir versiones aunque compartan esa etiqueta
y ayuda a reproducir y revisar la instalación.

### 7. ¿Qué comando borraría realmente los datos de Oracle?

La operación destructiva sería eliminar el volumen que contiene los datos.
En este laboratorio, el volumen se llama oralab-26ai-data.

El comando docker volume rm oralab-26ai-data eliminaría ese volumen si no
estuviera siendo utilizado. No debe ejecutarse como parte de la verificación.

docker rm oralab-26ai elimina el contenedor detenido, pero no elimina
automáticamente el volumen con nombre. Otro contenedor puede volver a montar
ese volumen y recuperar los datos.

## Git, organización y evidencia

### 8. ¿Por qué usamos repositorio, Issue, branch y Pull Request?

Porque la instalación debe ser reproducible, revisable y trazable.

El Issue describe el trabajo, la branch aísla los cambios, los scripts
documentan cómo ejecutarlos y las evidencias muestran los resultados.
El Pull Request permite revisar todo antes de incorporarlo a main.

Una carpeta independiente sin ese historial no ofrece la misma trazabilidad.

### 9. ¿Qué diferencia hay entre source y bash para cargar 00-config.sh?

source ejecuta el archivo dentro de la shell actual. Sus variables y
funciones quedan disponibles en esa terminal.

bash ejecuta el archivo en otro proceso. Los cambios de variables de ese
proceso no se incorporan a la shell que lo llamó.

Usamos source para poder reutilizar las constantes del proyecto y la función
ts en los comandos posteriores.

### 10. ¿Qué significa 20260915T091230Z_02-docker.script.log?

20260915 corresponde al 15 de septiembre de 2026.
T separa la fecha de la hora.
091230 representa las 09:12:30.
Z indica que la hora está expresada en UTC.

El guion bajo separa la marca temporal del paso.
02 identifica el paso que produjo la evidencia.
docker describe el contenido.
.script.log indica que es un registro de terminal, no un spool SQL ni una imagen.

### 11. ¿Para qué sirve .gitattributes?

Establece reglas de tratamiento de archivos para Git. En este laboratorio
fija finales de línea LF para los archivos .sh, .sql y .md.

Así se evitan diferencias innecesarias entre Windows y Linux y errores al
ejecutar scripts que contienen retornos de carro de finales CRLF.

### 12. ¿Por qué Create a merge commit y no Squash and merge?

Porque los commits de este laboratorio representan pasos de instalación
y verificación con valor individual.

Un merge commit conserva ese historial y permite revisar cuándo se incorporó
cada script y su evidencia. Squash reuniría los cambios en un único commit
y se perdería esa separación en el historial de main.

## Seguridad

### 13. ¿Cuáles son las cuatro capas de la estrategia de contraseñas?

1. Configurar .gitignore para excluir el archivo privado antes de crearlo.
2. Versionar una plantilla con nombres de variables y valores de ejemplo.
3. Guardar los valores reales en un archivo local que no se versiona.
4. Cargar esos valores al ejecutar, sin escribirlos literalmente en scripts.

En mi repositorio, los archivos son config.env.example y config.env.

Si se omite la primera capa, un git add puede preparar el archivo privado.
Si llega a un commit, añadirlo después a .gitignore no elimina el secreto
del historial ni deja de seguir automáticamente un archivo ya versionado.

### 14. ¿Por qué no escribir la contraseña literalmente en docker run?

Porque puede quedar en el historial de la terminal, en capturas, grabaciones,
logs o copias del script, aunque ese script no se publique en Git.

Leerla desde el archivo privado evita escribirla literalmente en el código
y en el comando guardado en el historial. Esto no sustituye la protección
del equipo ni impide que un administrador pueda inspeccionar el entorno.

### 15. ¿Basta con borrar una contraseña de un commit publicado?

No. Un commit nuevo no elimina la contraseña de los commits anteriores,
y otras personas pueden haberla copiado.

Hay que tratarla como comprometida: cambiarla o revocarla inmediatamente,
avisar al docente o responsable y revisar dónde pudo quedar expuesta.
Después se coordina la limpieza del historial y de otras copias o registros.
Limpiar el historial no sustituye la rotación de la contraseña.

## Oracle y herramientas

### 16. ¿Por qué no usamos SPOOL ni @archivo.sql dentro del contenedor?

Ambos se pueden usar, pero sus rutas se interpretan dentro del sistema de
archivos donde se ejecuta SQL*Plus.

Un SPOOL dentro del contenedor escribiría allí, no directamente en mi
repositorio. @archivo.sql también buscaría el archivo dentro del contenedor.

Por eso enviamos el SQL local mediante redirección de entrada y docker exec -i,
y guardamos la salida con tee en Ubuntu. Con SQLcl instalado en Ubuntu sí
usamos SPOOL directamente sobre una ruta del repositorio.

### 17. ¿Qué hace WHENEVER SQLERROR EXIT SQL.SQLCODE?

Ordena a SQL*Plus salir con un código de error si una sentencia SQL o un
bloque PL/SQL falla.

Sin esa instrucción, podría continuar con las siguientes sentencias y dejar
una migración parcialmente aplicada. En el script de shell, pipefail ayuda
a detectar ese fallo aunque la salida pase por tee.

Esta instrucción no deshace automáticamente los cambios DDL ya realizados.

### 18. ¿Qué es una migración y por qué no se edita tras aplicarla?

Es un script versionado y ordenado que transforma el estado de una base.

V000 crea los tablespaces y usuarios de negocio. V001 crea sus tablas,
restricciones e índices.

Si se modifica una migración ya aplicada, dos personas podrían tener bases
distintas usando un archivo con el mismo nombre. Las correcciones deben
registrarse en una nueva migración para conservar un historial reproducible.

### 19. ¿Por qué usamos FREEPDB1 y no FREE ni un SID?

FREEPDB1 es el servicio de la PDB donde trabajamos y creamos los esquemas.

FREE identifica la instancia y también puede aparecer como servicio de la
base contenedora. No debemos confundirlo con la PDB de trabajo.

Seleccionar Service name = FREEPDB1 permite dirigir la conexión a esa PDB.
Un SID identifica una instancia, no selecciona por sí solo la PDB deseada.

### 20. ¿Qué aporta SQLcl frente a SQL*Plus?

SQLcl ofrece funciones de uso diario como autocompletado, historial,
formatos de salida más cómodos, conexiones guardadas e integración con
herramientas de migraciones.

SQL*Plus sigue siendo una herramienta tradicional muy extendida en entornos
Oracle y útil para administración y automatización.

Un DBA debe conocer ambas para trabajar tanto en terminales de servidores
como en su entorno habitual. En este laboratorio usamos SQL*Plus dentro del
contenedor y SQLcl instalado en Ubuntu.

## Entorno de trabajo

### 21. ¿Por qué pasamos de Git Bash a Ubuntu en WSL 2?

Porque WSL 2 proporciona un entorno Linux real, más parecido al de los
servidores y contenedores con los que trabajamos.

Git Bash puede convertir argumentos que parecen rutas de Linux y alterar
comandos de Docker. También puede necesitar soluciones adicionales para
terminales interactivas y no incluye por defecto muchas utilidades habituales
de administración, como ss, free o htop.

Ubuntu permite trabajar con rutas, permisos, paquetes y herramientas Linux
de forma coherente con los scripts del laboratorio.

### 22. ¿Por qué trabajar en ~/oracle-database-lab y usar bash?

Al trabajar desde Linux, guardar el repositorio en su sistema de archivos
evita el coste de acceder continuamente a archivos de Windows mediante
/mnt/c y reduce problemas de permisos y diferencias entre sistemas.

La copia de trabajo de esta práctica está en ~/oracle-database-lab dentro
de Ubuntu. Desde Windows puedo abrirla con explorer.exe . ejecutado allí.

Recomendamos bash para los scripts compartidos porque es muy habitual en
servidores Linux y coincide con el intérprete utilizado en el laboratorio.
zsh es válida como shell interactiva, pero tiene diferencias de comportamiento.
Un script con cabecera de bash debe ejecutarse con bash aunque la shell
interactiva del usuario sea otra.

# Respuestas — Laboratorio 2

## 1. ¿Por qué un Issue sin criterios de aceptación es un problema, aunque la descripción general parezca clara?

Porque la descripción puede explicar la intención, pero no define cuándo el trabajo se considera terminado. Sin criterios de aceptación, cada persona puede interpretar de forma distinta el resultado esperado.

Los criterios de aceptación convierten el Issue en una lista de condiciones verificables. Así, el autor sabe qué debe entregar y el reviewer puede comprobar objetivamente si el trabajo está completo.

## 2. Explica la diferencia entre `Refs #N` y `Closes #N` en un mensaje de commit o en la descripción de un Pull Request.

`Refs #N` crea una referencia al Issue, pero no lo cierra. Sirve para relacionar el trabajo con ese Issue y mantener la trazabilidad.

`Closes #N` indica que el cambio resuelve el Issue. Cuando el Pull Request se fusiona en `main`, GitHub cierra automáticamente ese Issue.

Ejemplo:

```text
Refs #1
```

solo enlaza el cambio con el Issue.

```text
Closes #1
```

hace que el Issue se cierre al integrarse el PR.

## 3. ¿Qué ocurre exactamente si intentas hacer `git push` directamente sobre una branch `main` protegida? ¿Es un error tuyo o un fallo del sistema?

GitHub rechaza el `push` e informa de que la branch está protegida y que los cambios deben hacerse mediante un Pull Request.

No es un fallo del sistema. Es precisamente la protección funcionando correctamente. La rama `main` está configurada para impedir cambios directos y obligar a seguir el flujo de revisión.

## 4. Un compañero te dice: “He aprobado el PR sin mirar los archivos, total ya me fío”. ¿Qué riesgo tiene esa forma de revisar?

El riesgo es aprobar cambios incorrectos, incompletos o accidentales sin detectarlos. También pueden pasar errores funcionales, incumplimientos del Issue o incluso problemas de seguridad.

La revisión debe hacerse sobre el diff real, los commits, la descripción del PR y los criterios de aceptación. La confianza en la persona no sustituye la comprobación técnica.

## 5. Si el reviewer pide un cambio y tú ya habías hecho `push` de tu branch, ¿tienes que abrir un Pull Request nuevo? Explica qué ocurre técnicamente con el PR existente cuando haces un nuevo commit.

No, no hay que abrir un Pull Request nuevo. Lo correcto es seguir trabajando sobre la misma branch, hacer un nuevo commit y volver a hacer `push`.

Técnicamente, el PR sigue apuntando a esa misma branch, así que GitHub incorpora automáticamente el nuevo commit al PR existente. Por eso se actualizan `Commits`, `Files changed` y la conversación sin perder el historial de revisión.

## 6. Describe con tus palabras la diferencia entre Merge commit, Squash and merge y Rebase and merge. ¿Cuál usarías para una branch con commits `wip`, `fix`, `fix2`, `ok ya`?

- **Merge commit:** conserva todos los commits de la branch y añade un commit de fusión.
- **Squash and merge:** combina todos los commits de la branch en un único commit antes de integrarlos en `main`.
- **Rebase and merge:** reaplica los commits de la branch sobre `main`, manteniendo un historial lineal y sin commit de merge adicional.

Para una branch con commits como `wip`, `fix`, `fix2` y `ok ya`, usaría **Squash and merge**, porque esos commits son intermedios y no aportan valor individual al historial principal. Así queda un único commit limpio y descriptivo.

## 7. ¿Por qué borrar una branch después del merge no elimina el trabajo realizado en ella?

Porque la branch solo es una referencia a una línea de trabajo. Una vez fusionada, sus commits ya forman parte del historial de `main`.

Al borrar la branch, se elimina la referencia, pero no el trabajo ya integrado. Por eso el contenido mergeado sigue existiendo en el repositorio.

## 8. ¿Qué información debería contener siempre la descripción de un Pull Request, como mínimo?

Como mínimo, debería incluir:

- Un resumen de qué hace el cambio.
- Una lista de los cambios principales.
- Cómo se ha comprobado o probado.
- El Issue relacionado.

Un ejemplo de estructura mínima sería:

```markdown
## Summary
Explicación breve del objetivo del cambio.

## Changes
- Cambio 1.
- Cambio 2.

## Testing
- Prueba realizada.
- Verificación hecha.

## Related Issue
Closes #1
```

## 9. Un reviewer escribe solo “esto está mal” como comentario. ¿Qué le falta a ese comentario para ser útil? Reescríbelo tú con un ejemplo inventado.

Le falta precisión, contexto, explicación y una acción concreta. Un buen comentario debe indicar qué está mal, por qué importa y qué se espera corregir.

Ejemplo útil:

```text
issue (blocking): En README.md falta el enlace a CONTRIBUTING.md, aunque aparece en los criterios de aceptación del Issue. Añádelo y comprueba que funcione correctamente en GitHub.
```

Ese comentario identifica el problema, lo justifica y propone la corrección.

## 10. ¿Qué diferencia hay entre que `main` esté protegida y que simplemente el equipo “se ponga de acuerdo” en no hacer `push` directo?

Si solo existe un acuerdo, la norma depende de la memoria y disciplina de las personas. Puede incumplirse por error o por descuido.

Si `main` está protegida, GitHub aplica la norma técnicamente. Eso significa que el sistema rechaza el `push` directo y obliga a pasar por Pull Request, revisión y aprobación.

## 11. Explica con un ejemplo propio la diferencia entre un comentario `issue: (blocking)` y uno `nitpick: (if-minor)` en formato Conventional Comments.

Un comentario `issue: (blocking)` indica un problema que debe resolverse antes del merge.

Ejemplo:

```text
issue (blocking): El enlace a CONTRIBUTING.md apunta a una ruta incorrecta y no cumple el criterio de aceptación. Corrígelo antes de fusionar.
```

Un comentario `nitpick: (if-minor)` señala una mejora menor que no bloquea el merge.

Ejemplo:

```text
nitpick (if-minor): Podrías dejar una línea en blanco antes del encabezado “Pull Requests” para mejorar la legibilidad.
```

La diferencia principal es la severidad: el primero bloquea la integración y el segundo es solo una sugerencia menor.

## 12. Si tu próximo commit es `feat!: cambia la firma de la función principal de la API`, ¿qué tipo de versión SemVer se dispara y por qué?

Se dispara una versión **MAJOR**.

El motivo es que `feat!` indica un cambio incompatible con versiones anteriores. Si cambia la firma principal de la API, los consumidores del código pueden tener que modificar su implementación, así que se considera un cambio rompedor.

## 13. ¿Por qué abrir un Draft PR desde el primer commit estructural puede ahorrar tiempo al equipo, aunque parezca más lento para el autor individual?

Porque permite enseñar pronto la dirección del cambio y detectar errores de enfoque antes de invertir más tiempo. Así el equipo puede dar feedback temprano y evitar rehacer trabajo más adelante.

Aunque al autor le parezca más lento al principio, en conjunto reduce rondas de corrección, malentendidos y cambios grandes al final. Es una forma de fallar pronto y corregir cuando todavía es barato hacerlo.

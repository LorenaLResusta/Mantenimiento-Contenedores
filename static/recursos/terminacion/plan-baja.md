# Plan de baja de BiciAlacant

| Dato | Valor |
|---|---|
| Servicio | BiciAlacant (web, api, db, cache) · espacio de nombres `bicialacant` |
| Motivo de la baja | Fin del contrato con el ayuntamiento (AAAA-MM-DD) |
| Responsable | Nombre Apellidos |
| Ventana | AAAA-MM-DD HH:MM – HH:MM |
| Aprobado por | Responsable del servicio / del tratamiento de datos |

## 1. Inventario de lo que hay que eliminar

| Elemento | Dónde | Contiene datos personales | Cómo se elimina | Cómo se comprueba |
|---|---|---|---|---|
| Datos de la base de datos | Volumen `datos-db-0` | Sí (abonados, alquileres) | `borrado-datos-personales.sql` + borrado del volumen | Recuento 0 · PV inexistente |
| Copias lógicas | Garage `bicialacant-copias/postgres/` | Sí | Borrado de objetos, depósito y clave | Listado vacío · clave inexistente |
| Copias de Velero | Garage `velero/` | Sí (volumen y Secrets) | `velero backup delete` · `velero schedule delete` | `velero backup get` vacío |
| Registros | Loki · Mailpit | Posible (IP, nombres de Pod) | API de borrado de Loki · borrado de correos | Consulta vacía |
| Métricas | Prometheus | No (pero referencias al servicio) | API de administración de Prometheus | `series` vacía |
| Objetos de Kubernetes | Clúster «produccion» | Secret `db-cred`, `copia-s3` | `kubectl delete namespace` | `comprobar-baja.sh` |
| Integración con la monitorización | `monitorizacion` · Grafana · Alertmanager | No | Borrado de reglas, paneles, alertas, rutas y CronJob de revisión | `comprobar-baja.sh` |
| Imágenes | Nodos de kind · Docker de ct-lab | No | `crictl rmi` · `docker rmi` | `comprobar-baja.sh` |

## 2. Lo que se conserva (y por qué)

| Qué | Dónde | Motivo | Hasta cuándo |
|---|---|---|---|
| Estadística anónima de uso (`resumen_anonimo`) | Entregada al ayuntamiento en CSV | Lo pide el contrato; no contiene datos personales | Lo que decida el cliente |
| Libro de operaciones | Repositorio Git | Documentación del servicio | Indefinido |

## 3. Orden de las operaciones

1. Avisar a los usuarios y silenciar las alarmas del servicio durante la ventana.
2. Retirar el tráfico (ruta HTTP) y comprobar que ya no llegan peticiones.
3. Exportar lo que se conserva.
4. Borrar los datos personales de la base de datos.
5. Retirar la aplicación y liberar sus recursos.
6. Borrar las copias y los registros en los sistemas externos.
7. Desintegrar la monitorización.
8. Comprobar (`comprobar-baja.sh`) y emitir el certificado de borrado.

## 4. Riesgos y vuelta atrás

Hasta el paso 6 se puede volver atrás restaurando la última copia. **Después del paso 6 no hay vuelta atrás**: por eso los pasos 4 a 6 solo empiezan con la aprobación escrita del responsable.

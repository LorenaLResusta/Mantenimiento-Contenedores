# Certificado de borrado de datos · BiciAlacant

**Referencia:** BAJA-BICIALACANT-AAAA-NN · **Fecha:** AAAA-MM-DD

Yo, Nombre Apellidos, técnico de operaciones, certifico que en la fecha indicada se ha dado de baja el servicio BiciAlacant y se han eliminado los datos y recursos que se relacionan, con el método y la comprobación indicados.

| Soporte / sistema | Datos | Método de borrado | Comprobación | Resultado |
|---|---|---|---|---|
| Base de datos PostgreSQL (`datos-db-0`) | Abonados y alquileres | `DELETE` + `VACUUM FULL`; después borrado del volumen | Recuento 0; PV inexistente | ✔ |
| Almacén Garage `bicialacant-copias` | Copias lógicas (N objetos) | Borrado de objetos, depósito y clave de acceso | `aws s3 ls` → `NoSuchBucket`; `garage key list` | ✔ |
| Almacén Garage `velero` | N copias de Velero | `velero backup delete --all`; desinstalación | `velero backup get` vacío | ✔ |
| Loki | Registros de `namespace="bicialacant"` | Petición de borrado por API, ejecutada por el compactador | Consulta de 7 días sin resultados | ✔ |
| Prometheus | Series de `namespace="bicialacant"` | `delete_series` + `clean_tombstones` | `series` vacía | ✔ |
| Mailpit | Correos de alarmas e informes | Borrado de mensajes | Bandeja vacía | ✔ |
| Nodos del clúster y ct-lab | Imágenes y directorios de volúmenes | `crictl rmi`, `docker rmi`, borrado del directorio | `comprobar-baja.sh` | ✔ |

**Limitaciones conocidas del borrado:** en discos SSD y en sistemas de ficheros con copia en escritura, sobrescribir un fichero (`shred`) no garantiza que los bloques antiguos desaparezcan físicamente. La garantía completa se obtiene destruyendo la clave de cifrado de los datos (borrado criptográfico) o el soporte. [Describe aquí la situación real de cada soporte.]

**Datos conservados:** estadística anónima de uso entregada al cliente (`resumen_anonimo.csv`), sin datos personales.

**Evidencias:** `evidencias/comprobacion-baja.txt` y salidas de cada paso, en el *commit* `abc1234` del libro de operaciones.

Firma: ______________________

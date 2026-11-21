// Prueba de CARGA de BiciAlacant (UD02, práctica 2.4).
// Simula la hora punta: RPS peticiones por segundo constantes durante DURACION.
// Ejecución (desde ct-lab, en la carpeta del script):
//   docker run --rm -i --network host -u "$(id -u)" -v "$PWD":/trabajo -w /trabajo \
//     -e RPS=30 -e DURACION=5m grafana/k6 run carga.js
// Código de salida: 0 si se cumplen los umbrales del SLA; 99 si alguno falla.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';

const RPS = Number(__ENV.RPS || 30);
const DURACION = __ENV.DURACION || '5m';
const BASE = 'http://bicialacant.local';

export const options = {
  hosts: { 'bicialacant.local': __ENV.IP || '127.0.0.1' },
  scenarios: {
    hora_punta: {
      executor: 'constant-arrival-rate',
      rate: RPS,
      timeUnit: '1s',
      duration: DURACION,
      preAllocatedVUs: 20,
      maxVUs: 200,
    },
  },
  // Umbrales = SLA (guía > Sistema que mantienes)
  thresholds: {
    http_req_failed: ['rate<0.01'],                    // < 1 % de errores
    'http_req_duration{tipo:api}': ['p(95)<300'],      // p95 de la API < 300 ms
    'http_req_duration{tipo:web}': ['p(95)<300'],
    checks: ['rate>0.99'],
  },
};

// Respuestas que NO son error: 409 = estación sin bicis (respuesta correcta del negocio)
const alquilerOk = http.expectedStatuses(200, 409);

export default function () {
  const r = Math.random();
  let res;
  if (r < 0.40) {
    res = http.get(`${BASE}/api/estaciones`, { tags: { tipo: 'api', nombre: 'estaciones' } });
    check(res, { 'estaciones 200': (x) => x.status === 200, 'estaciones JSON': (x) => x.body.includes('bicis_libres') });
  } else if (r < 0.60) {
    res = http.get(`${BASE}/`, { tags: { tipo: 'web', nombre: 'portada' } });
    check(res, { 'portada 200': (x) => x.status === 200 });
  } else if (r < 0.80) {
    res = http.get(`${BASE}/api/visitas`, { tags: { tipo: 'api', nombre: 'visitas' } });
    check(res, { 'visitas 200': (x) => x.status === 200 });
  } else if (r < 0.95) {
    res = http.get(`${BASE}/api/salud`, { tags: { tipo: 'api', nombre: 'salud' } });
    check(res, { 'salud 200': (x) => x.status === 200 });
  } else {
    const estacion = 1 + Math.floor(Math.random() * 5);
    res = http.post(`${BASE}/api/alquiler/${estacion}`, null,
      { tags: { tipo: 'api', nombre: 'alquiler' }, responseCallback: alquilerOk });
    check(res, { 'alquiler 200 o 409': (x) => x.status === 200 || x.status === 409 });
  }
  sleep(0.1);
}

// Guarda el resumen como evidencia, con fecha y parámetros en el nombre
export function handleSummary(datos) {
  const fecha = new Date().toISOString().slice(0, 16).replace(/[:T]/g, '-');
  const nombre = `evidencias/${fecha}_carga-${RPS}rps.json`;
  return {
    [nombre]: JSON.stringify(datos, null, 2),
    stdout: textSummary(datos, { indent: ' ', enableColors: true }),
  };
}

// Prueba de ESTRÉS de BiciAlacant (UD02, práctica 2.4).
// Sube el tráfico por escalones hasta encontrar el punto de rotura y después lo baja
// para comprobar que el sistema se recupera solo.
//   docker run --rm -i --network host -u "$(id -u)" -v "$PWD":/trabajo -w /trabajo grafana/k6 run estres.js
// Criterio de parada: si más del 20 % de las peticiones falla durante 30 s, k6 aborta la prueba.
import http from 'k6/http';
import { check } from 'k6';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';

const BASE = 'http://bicialacant.local';
const MAX = Number(__ENV.MAX || 120);          // peticiones/s del último escalón

export const options = {
  hosts: { 'bicialacant.local': __ENV.IP || '127.0.0.1' },
  scenarios: {
    escalones: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 400,
      stages: [
        { target: 20, duration: '1m' }, { target: 20, duration: '2m' },
        { target: Math.round(MAX * 0.33), duration: '1m' }, { target: Math.round(MAX * 0.33), duration: '2m' },
        { target: Math.round(MAX * 0.66), duration: '1m' }, { target: Math.round(MAX * 0.66), duration: '2m' },
        { target: MAX, duration: '1m' }, { target: MAX, duration: '2m' },
        { target: 10, duration: '1m' }, { target: 10, duration: '3m' },     // recuperación
      ],
    },
  },
  thresholds: {
    // Los umbrales del SLA se registran (pasa / no pasa) pero no paran la prueba
    http_req_failed: [
      'rate<0.01',
      { threshold: 'rate<0.20', abortOnFail: true, delayAbortEval: '30s' },   // criterio de parada
    ],
    'http_req_duration{tipo:api}': ['p(95)<300'],
  },
};

export default function () {
  const res = http.get(`${BASE}/api/estaciones`, { tags: { tipo: 'api', nombre: 'estaciones' } });
  check(res, { 'estaciones 200': (x) => x.status === 200 });
}

export function handleSummary(datos) {
  const fecha = new Date().toISOString().slice(0, 16).replace(/[:T]/g, '-');
  return {
    [`evidencias/${fecha}_estres-max${MAX}rps.json`]: JSON.stringify(datos, null, 2),
    stdout: textSummary(datos, { indent: ' ', enableColors: true }),
  };
}

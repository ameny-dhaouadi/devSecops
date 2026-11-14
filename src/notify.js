// Simulation d'un service de notification (aucun appel réseau réel).
// VULN-04 corrigée : la clé vient de l'environnement et n'est jamais écrite dans les journaux.
const { API_KEY } = require('./config');

function notifyBooking(patientNom, medecinNom, date, heure) {
  const mode = API_KEY ? 'service' : 'local';
  console.log(`[notify:${mode}] RDV ${date} ${heure} : ${patientNom} -> ${medecinNom}`);
}

module.exports = { notifyBooking };

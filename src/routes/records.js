// Détail d'un dossier médical + ajout de note (médecin)
const express = require('express');
const db = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');
const { wrap, redirectWithToast, renderError } = require('../utils');

const router = express.Router();

/**
 * VULN-02 corrigée : un dossier n'est visible que par son patient
 * ou par un médecin qui suit ce patient (rendez-vous ou médecin traitant).
 */
async function peutAcceder(user, patientId) {
  if (user.role === 'patient') return user.id === patientId;
  if (user.role === 'medecin') {
    const rel = await db.query(
      `SELECT 1 FROM appointments WHERE medecin_id = $1 AND patient_id = $2
       UNION
       SELECT 1 FROM users WHERE id = $2 AND medecin_traitant_id = $1
       LIMIT 1`,
      [user.id, patientId]
    );
    return rel.rowCount > 0;
  }
  return false; // secrétaire, admin : pas d'accès aux dossiers médicaux
}

router.get('/records/:id', requireAuth, wrap(async (req, res) => {
  // Le rôle secrétaire n'a aucun droit d'accès aux dossiers médicaux
  if (req.user.role === 'secretaire') {
    return renderError(res, 403, 'Accès interdit', 'Les secrétaires ne sont pas autorisées à consulter les dossiers médicaux.');
  }

  const id = parseInt(req.params.id, 10) || 0;
  const { rows } = await db.query(
    'SELECT r.*, u.nom AS patient_nom FROM medical_records r JOIN users u ON u.id = r.patient_id WHERE r.id = $1', [id]);
  if (!rows[0]) return renderError(res, 404, 'Dossier introuvable', "Ce dossier n'existe pas.");
  // VULN-02 corrigée : vérification que l'utilisateur a le droit de voir ce dossier
  if (!(await peutAcceder(req.user, rows[0].patient_id))) {
    return renderError(res, 403, 'Accès refusé', "Vous n'avez pas accès à ce dossier.");
  }
  res.render('pages/record', { title: 'Dossier médical', r: rows[0] });
}));

router.post('/records/:id/notes', requireRole('medecin'), wrap(async (req, res) => {
  const id = parseInt(req.params.id, 10) || 0;
  const texte = String(req.body.note || '').trim();
  if (texte.length < 3 || texte.length > 500) {
    return redirectWithToast(res, `/records/${id}`, 'La note doit contenir entre 3 et 500 caractères.', 'error');
  }
  // VULN-02 corrigée : le médecin doit suivre le patient pour ajouter une note
  const dossier = (await db.query('SELECT patient_id FROM medical_records WHERE id = $1', [id])).rows[0];
  if (!dossier) return renderError(res, 404, 'Dossier introuvable', "Ce dossier n'existe pas.");
  if (!(await peutAcceder(req.user, dossier.patient_id))) {
    return renderError(res, 403, 'Accès refusé', "Vous n'avez pas accès à ce dossier.");
  }
  const ligne = `[${new Date().toISOString().slice(0, 10)}] ${req.user.nom} : ${texte}`;
  const r = await db.query("UPDATE medical_records SET notes = COALESCE(notes || E'\\n', '') || $1 WHERE id = $2", [ligne, id]);
  if (!r.rowCount) return renderError(res, 404, 'Dossier introuvable', "Ce dossier n'existe pas.");
  redirectWithToast(res, `/records/${id}`, 'Note ajoutée au dossier.');
}));

module.exports = router;

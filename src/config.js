// Configuration centrale de l'application.
// VULN-04 corrigée : aucun secret n'est écrit dans le code. Les valeurs viennent de
// l'environnement : fichier .env (jamais commité) en local, Secret Kubernetes en déploiement.

// Clé du service de notification (facultative : sans clé, les notifications sont simplement journalisées)
const API_KEY = process.env.API_KEY || '';

// Secret de signature des JWT : obligatoire, aucune valeur par défaut
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error("JWT_SECRET n'est pas défini : renseignez-le dans .env (voir .env.example)");
}

module.exports = { API_KEY, JWT_SECRET };

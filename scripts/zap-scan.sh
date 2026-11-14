#!/usr/bin/env bash
# =============================================================================
#  Scan dynamique OWASP ZAP de MediTrack déployée sur Minikube.
#  À lancer depuis la racine du projet, port-forward actif dans un autre terminal :
#      bash scripts/zap-scan.sh avant      (version vulnérable)
#      bash scripts/zap-scan.sh apres      (après les corrections)
#  Rapports : reports/zap/zap-<phase>.html et .json
# =============================================================================
export MSYS_NO_PATHCONV=1            # Git Bash / MSYS2 : pas de conversion des chemins Docker
PHASE="${1:-avant}"
ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable"
TARGET="http://$(minikube ip | tr -d '\r'):30080"     # NodePort, joignable depuis le réseau Docker "minikube"
mkdir -p reports/zap
if pwd -W >/dev/null 2>&1; then OUT="$(pwd -W)/reports/zap"; else OUT="$(pwd)/reports/zap"; fi

# Jeton de session d'un médecin pour un scan authentifié (via le port-forward)
TOKEN="$(curl -s -c - -H 'Content-Type: application/json' \
  -d '{"email":"medecin1@meditrack.test","password":"Password123!"}' \
  http://localhost:3000/api/auth/login | tr -d '\r' | awk -F'\t' '$6 == "token" {print $7}')"
if [ -z "$TOKEN" ]; then
  echo "Connexion impossible : lancez d'abord 'kubectl port-forward svc/meditrack-app 3000:3000 -n meditrack'"; exit 1
fi

# Un seul scan à la fois : arrête un ancien conteneur ZAP resté bloqué
docker ps -q --filter "ancestor=$ZAP_IMAGE" | xargs -r docker kill >/dev/null 2>&1

# Scan COMPLET (spider + attaques actives), dimensionné pour un PC portable :
#   --memory / --cpus         : ZAP ne peut pas saturer Docker (et donc Kubernetes)
#   -Xmx1536m                 : mémoire Java de ZAP
#   scanner.threadPerHost=2   : 2 attaques en parallèle sur la cible
#   maxRuleDurationInMins=3   : chaque type d'attaque dure au plus 3 minutes
#   maxScanDurationInMins=25  : le scan actif dure au plus 25 minutes
#   -d                        : affiche la progression (Spider progress %, Active Scan progress %)
rm -f "reports/zap/zap-$PHASE.html" "reports/zap/zap-$PHASE.json"   # pas d'ancien rapport
echo "Scan ZAP complet ($PHASE) de $TARGET : 20 à 35 minutes, progression affichée ci-dessous."
docker run --rm -e PYTHONUNBUFFERED=1 --network minikube --memory=3g --cpus=1.5 \
  -e ZAP_AUTH_HEADER=Cookie -e ZAP_AUTH_HEADER_VALUE="token=$TOKEN" \
  -v "$OUT":/zap/wrk:rw "$ZAP_IMAGE" \
  zap-full-scan.py -t "$TARGET" -m 2 -T 15 -I -d \
  -r "zap-$PHASE.html" -J "zap-$PHASE.json" \
  -z "-Xmx1536m -config scanner.threadPerHost=2 -config scanner.maxRuleDurationInMins=3 -config scanner.maxScanDurationInMins=25"

if [ -f "reports/zap/zap-$PHASE.html" ]; then
  echo; echo "Scan terminé."
else
  echo; echo "Le rapport n'a pas été créé : envoyez les dernières lignes ci-dessus."; exit 1
fi
echo "Rapport : reports/zap/zap-$PHASE.html"

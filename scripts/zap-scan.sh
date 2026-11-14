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

echo "Scan ZAP ($PHASE) de $TARGET : 10 à 25 minutes..."
docker run --rm --network minikube \
  -e ZAP_AUTH_HEADER=Cookie -e ZAP_AUTH_HEADER_VALUE="token=$TOKEN" \
  -v "$OUT":/zap/wrk:rw "$ZAP_IMAGE" \
  zap-full-scan.py -t "$TARGET" -m 3 -T 25 -I \
  -r "zap-$PHASE.html" -J "zap-$PHASE.json"

echo "Rapport : reports/zap/zap-$PHASE.html"

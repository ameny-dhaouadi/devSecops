#!/usr/bin/env bash
# =============================================================================
#  Déploie MediTrack sur Minikube. À lancer depuis la racine du projet :
#      bash k8s/deploy.sh
#  Pré-requis : minikube démarré, image construite (minikube image build -t meditrack:latest .)
# =============================================================================
set -e
cd "$(dirname "$0")/.."

echo "== Namespace"
kubectl apply -f k8s/00-namespace.yaml

echo "== Secret (créé une seule fois, valeurs aléatoires, jamais écrites dans Git)"
if kubectl get secret meditrack-secrets -n meditrack >/dev/null 2>&1; then
  echo "   le Secret existe déjà : on le garde"
else
  rnd() { head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'; }
  PW="$(rnd 16)"
  kubectl create secret generic meditrack-secrets -n meditrack \
    --from-literal=POSTGRES_PASSWORD="$PW" \
    --from-literal=JWT_SECRET="$(rnd 32)" \
    --from-literal=DATABASE_URL="postgresql://meditrack:$PW@meditrack-db:5432/meditrack"
fi

echo "== Schéma SQL de la base (ConfigMap à partir de db/schema.sql)"
kubectl create configmap meditrack-db-schema -n meditrack \
  --from-file=schema.sql=db/schema.sql --dry-run=client -o yaml | kubectl apply -f -

echo "== Configuration, base, application, NetworkPolicy"
kubectl apply -f k8s/01-configmap.yaml -f k8s/02-postgres.yaml -f k8s/03-app.yaml -f k8s/04-networkpolicy.yaml

echo "== Attente du démarrage"
kubectl rollout status deployment/meditrack-db -n meditrack --timeout=180s
kubectl rollout status deployment/meditrack-app -n meditrack --timeout=300s
kubectl get pods,svc,networkpolicy -n meditrack
echo
echo "Accès depuis le navigateur (garder ce terminal ouvert) :"
echo "   kubectl port-forward svc/meditrack-app 3000:3000 -n meditrack"

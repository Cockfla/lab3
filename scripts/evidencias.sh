#!/usr/bin/env bash
# Genera las evidencias obligatorias del laboratorio en la carpeta evidencias/
# Uso: bash scripts/evidencias.sh
set -u
ALUMNO=elias-bahamondes
NS=ns-$ALUMNO
APP=app-$ALUMNO
SVC=svc-$ALUMNO
OUT=evidencias
mkdir -p "$OUT"

# Quita los codigos de color ANSI de los logs de Nest
strip_colors() { sed -E 's/\x1B\[[0-9;]*m//g'; }

run() {
  local file="$OUT/$1"; shift
  {
    echo "\$ $*"
    "$@" 2>&1 | strip_colors
  } | tee "$file"
  echo
}

run 01-cluster-info.txt       kubectl cluster-info
run 02-get-nodes.txt          kubectl get nodes -o wide
run 03-get-pods.txt           kubectl get pods -n "$NS" -o wide
run 04-get-deployment.txt     kubectl get deployment "$APP" -n "$NS" -o wide
run 05-get-svc.txt            kubectl get svc "$SVC" -n "$NS" -o wide
run 06-logs.txt               kubectl logs "deployment/$APP" -n "$NS"
run 07-exec-printenv.txt      kubectl exec "deployment/$APP" -n "$NS" -- printenv
run 08-get-configmap.txt      kubectl get configmap "config-$ALUMNO" -n "$NS" -o yaml
run 09-get-secret.txt         kubectl get secret "secret-$ALUMNO" -n "$NS"

# Prueba con port-forward + curl
kubectl port-forward "svc/$SVC" 8080:80 -n "$NS" > "$OUT/10-port-forward.log" 2>&1 &
PF_PID=$!
for _ in $(seq 1 20); do curl -s -o /dev/null http://localhost:8080/ && break; sleep 1; done
{
  echo "\$ kubectl port-forward svc/$SVC 8080:80 -n $NS"
  cat "$OUT/10-port-forward.log"
  echo
  echo "\$ curl -i http://localhost:8080/lab"
  curl -s -i http://localhost:8080/lab
  echo
} | tee "$OUT/10-port-forward-curl.txt"
kill "$PF_PID" 2>/dev/null
rm -f "$OUT/10-port-forward.log"

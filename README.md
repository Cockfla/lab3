# Laboratorio 3 - Mi despliegue CI/CD en Kubernetes

**Alumno:** Elias Bahamondes (`elias-bahamondes`)

API NestJS que expone `GET /lab`, que devuelve la variable `AMBIENTE` (leída desde un ConfigMap) y `API_KEY` (leída desde un Secret). Se construye con Docker, se publica en Docker Hub y GitHub Container Registry, y se despliega en Kubernetes con un pipeline de Jenkins que usa agentes Kubernetes.

## Nombres usados

| Recurso          | Nombre                                                      |
| ---------------- | ----------------------------------------------------------- |
| Namespace        | `ns-elias-bahamondes`                                       |
| Deployment       | `app-elias-bahamondes` (2 réplicas)                         |
| Service          | `svc-elias-bahamondes` (puerto 80 → 3000)                   |
| ConfigMap        | `config-elias-bahamondes` (`AMBIENTE`)                      |
| Secret           | `secret-elias-bahamondes` (`API_KEY`)                       |
| Imagen (nombre)  | `cockfla/tarea-final:elias-bahamondes`                      |
| Imagen (versión) | `cockfla/tarea-final:${APP_VERSION}` (`APP_VERSION=3.0.0`)  |
| Imagen GHCR      | `ghcr.io/cockfla/tarea-final:elias-bahamondes` y `:3.0.0`   |
| Pipeline         | `Jenkinsfile.Elias-Bahamondes`                              |
| Job Jenkins      | `lab3-elias-bahamondes`                                     |

## Estructura de la entrega

```text
Dockerfile                     # build multi-etapa (node:24-alpine), corre como usuario node
.dockerignore
Jenkinsfile.Elias-Bahamondes   # stages: install, test, build, push, deploy
agent.yaml                     # pod del agente Kubernetes: node, docker + dind, kubectl
entrega.yaml                   # Namespace, ConfigMap, Secret, Deployment, Service
k8s/jenkins.yaml               # Jenkins dentro del cluster (JCasC + plugin kubernetes)
k8s/jenkins-rbac.yaml          # ServiceAccount con permisos para el stage deploy
scripts/evidencias.sh          # genera las salidas de comandos en evidencias/
evidencias/                    # salidas de kubectl/curl y log del pipeline
src/, test/                    # aplicación NestJS y sus tests
```

## Requisitos

- Docker Desktop con Kubernetes habilitado (cluster local `docker-desktop`)
- `kubectl`
- Cuenta en Docker Hub y en GitHub (token con `write:packages` para GHCR)
- Node.js 24 y pnpm 11 (solo para correr la app fuera de Docker)

## 1. Ejecutar la app localmente

```bash
pnpm install
pnpm test
pnpm test:e2e
AMBIENTE=local API_KEY=demo pnpm start
curl http://localhost:3000/lab
```

Si `AMBIENTE` o `API_KEY` no están definidas, la app usa el valor `SIN COMPLETAR` y lo advierte en el log.

## 2. Validación manual: build, push y apply

```bash
docker build -t cockfla/tarea-final:elias-bahamondes -t cockfla/tarea-final:3.0.0 .
docker run --rm -p 3000:3000 -e AMBIENTE=local -e API_KEY=demo cockfla/tarea-final:elias-bahamondes

docker login
docker push cockfla/tarea-final:elias-bahamondes
docker push cockfla/tarea-final:3.0.0

kubectl apply -f entrega.yaml
kubectl rollout status deployment/app-elias-bahamondes -n ns-elias-bahamondes
```

El Deployment usa el tag por nombre (`:elias-bahamondes`) con `imagePullPolicy: Always`. Por eso el pipeline hace `kubectl rollout restart` en cada despliegue, para que se descargue la imagen nueva.

## 3. Jenkins en el cluster

```bash
kubectl create namespace jenkins
kubectl -n jenkins create secret generic jenkins-admin --from-literal=password='<clave-admin>'
kubectl apply -f k8s/jenkins.yaml -f k8s/jenkins-rbac.yaml
kubectl -n jenkins rollout status deploy/jenkins
kubectl -n jenkins port-forward svc/jenkins 8081:8080
```

Abre <http://localhost:8081> y entra con el usuario `admin`. La clave se puede leer así:

```bash
kubectl -n jenkins get secret jenkins-admin -o jsonpath='{.data.password}' | base64 -d
```

`k8s/jenkins.yaml` instala los plugins (kubernetes, pipeline, git, credentials-binding, JCasC, job-dsl) y deja configurados:

- la nube **kubernetes**, que crea los agentes en el namespace `jenkins` y se conecta por WebSocket;
- el job **`lab3-elias-bahamondes`** (Pipeline from SCM, rama `main`, Script Path `Jenkinsfile.Elias-Bahamondes`).

### Credenciales (nunca en el Jenkinsfile)

En *Manage Jenkins → Credentials → System → Global → Add Credentials*, crea dos credenciales de tipo **Username with password**:

| ID                           | Usuario   | Password                                             |
| ---------------------------- | --------- | ---------------------------------------------------- |
| `dockerhub-elias-bahamondes` | `cockfla` | Access Token de Docker Hub                           |
| `ghcr-elias-bahamondes`      | `Cockfla` | Personal Access Token de GitHub con `write:packages` |

El Jenkinsfile solo referencia esos IDs con `withCredentials`, y el login se hace con `--password-stdin`.

El stage `deploy` no usa kubeconfig: el pod del agente corre con la ServiceAccount `jenkins-deployer-elias-bahamondes`, que tiene permisos (RBAC) solo para los recursos de `entrega.yaml`.

### Stages del pipeline

| Stage     | Contenedor | Qué hace                                                                  |
| --------- | ---------- | ------------------------------------------------------------------------- |
| `install` | `node`     | instala pnpm 11.7.0 y corre `pnpm install --frozen-lockfile`              |
| `test`    | `node`     | corre `pnpm test` (unitarios) y `pnpm test:e2e`                           |
| `build`   | `docker`   | `docker build` con los tags `:elias-bahamondes` y `:3.0.0` para ambos registries |
| `push`    | `docker`   | hace login y push a Docker Hub y a GHCR                                   |
| `deploy`  | `kubectl`  | `kubectl apply -f entrega.yaml`, rollout restart/status y smoke test a `/lab` |

El build usa Docker-in-Docker (`docker:29-dind`, privilegiado) como sidecar del pod agente.

## 4. Evidencias

```bash
bash scripts/evidencias.sh
```

El script guarda en `evidencias/` la salida de: `cluster-info`, `get nodes`, `get pods`, `get deployment`, `get svc`, `logs`, `exec ... printenv`, `get configmap`, `get secret`, y el `port-forward` + `curl http://localhost:8080/lab`.

> Nota: en el enunciado, `kubectl get deployment` y `kubectl get svc` aparecen con `-n app-...` y `-n svc-...`, y `get configmap` / `get secret` aparecen sin namespace. Como todos los recursos viven en `ns-elias-bahamondes`, el script usa `-n ns-elias-bahamondes` en todos los comandos.

El log del pipeline se guarda en `evidencias/jenkins-pipeline.log` (Console Output del build exitoso).

Respuesta esperada:

```json
{"AMBIENTE":"laboratorio-elias-bahamondes","API_KEY":"api-key-elias-bahamondes-2026"}
```

## Problemas comunes

- **Pod sin iniciar:** `kubectl describe pod -n ns-elias-bahamondes <pod>` y `kubectl logs ...`.
- **Service sin endpoints:** el label `app: app-elias-bahamondes` del template del Deployment debe coincidir con el `selector` del Service.
- **Agente de Jenkins en `Pending`:** `kubectl -n jenkins get pods` y `kubectl -n jenkins describe pod <agente>`.

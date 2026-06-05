# Inception-of-Things (IoT) — Project Implementation Specification

> **Source:** `en.subject.pdf` (Version 4.0) — 42 / 1337 School System Administration project.
> **Purpose of this document:** Provide an AI/coding-model with every implementation-relevant detail needed to build the project end-to-end (Vagrant + K3s + K3d + Argo CD + optional GitLab).

---

## 1. Project Overview

### 1.1 Goal
Build a minimal, hands-on introduction to **Kubernetes** by:
1. Provisioning VMs with **Vagrant**.
2. Running lightweight Kubernetes clusters with **K3s** (server + agent).
3. Exposing multiple apps via Kubernetes **Ingress** with host-based routing.
4. Running an even simpler local cluster with **K3d** (K3s in Docker).
5. Implementing GitOps continuous delivery with **Argo CD**, synced from a public **GitHub** repo.
6. (Bonus) Self-hosting **GitLab** inside the cluster as the Git source for Argo CD.

### 1.2 High-level deliverables
- 3 mandatory parts: **p1**, **p2**, **p3** (folders at repo root).
- 1 optional bonus part: **bonus** (folder at repo root).
- All work must run **inside a virtual machine** on the host.

### 1.3 Repository layout (required)
```
repo-root/
├── p1/
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
├── p2/
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
├── p3/
│   ├── scripts/
│   └── confs/
└── bonus/                # optional
    ├── Vagrantfile       # if needed
    ├── scripts/
    └── confs/
```
- All scripts go in `scripts/`, all YAML/conf files in `confs/`.
- Evaluation runs on the **evaluated group's own computer**.

---

## 2. General Constraints

| Constraint | Rule |
|---|---|
| Host environment | Everything inside a VM |
| Linux distro | Latest stable version of student's choice |
| Provider (Vagrant) | Free choice (VirtualBox is the implied default given `modifyvm` examples) |
| Resources per VM | Strongly advised: **1 CPU**, **512 MB or 1024 MB RAM** |
| Network interface | Use **predictable names** (e.g. `enp0s8`, `enp0s9`), not `eth0/eth1`. Use `ip a` to inspect |
| SSH | Passwordless SSH access to all VMs |
| Vagrantfile style | "Modern practices" |
| Repo naming | Must contain the **login of one group member** |

---

## 3. Part 1 — K3s and Vagrant (`p1/`)

### 3.1 Objective
Provision **two VMs** with Vagrant, install K3s in **server + agent** topology, and verify with `kubectl`.

### 3.2 VM specifications

| Role | Hostname | IP (eth/enp interface) | K3s mode |
|---|---|---|---|
| Server (control-plane) | `<login>S` (e.g. `wilS`) | `192.168.56.110` | controller (server) |
| Worker | `<login>SW` (e.g. `wilSW`) | `192.168.56.111` | agent |

- Hostnames **must end** with capital `S` and `SW` respectively.
- The `<login>` is the 42 login of a team member.
- Dedicated IP on the **primary network interface** (private network).
- Resources: 1 CPU, 512–1024 MB RAM.
- Passwordless SSH (Vagrant default insecure key is fine).

### 3.3 Required software inside each VM
- K3s (server on first VM, agent on second VM)
- `kubectl`

### 3.4 Subject-provided Vagrantfile skeleton (verbatim)
```ruby
Vagrant.configure(2) do |config|
  [...]
  config.vm.box = REDACTED
  config.vm.box_url = REDACTED

  config.vm.define "wilS" do |control|
    control.vm.hostname = "wilS"
    control.vm.network REDACTED, ip: "192.168.56.110"
    control.vm.provider REDACTED do |v|
      v.customize ["modifyvm", :id, "--name", "wilS"]
      [...]
    end
    config.vm.provision :shell, :inline => SHELL
      [...]
    SHELL
    control.vm.provision "shell", path: REDACTED
  end

  config.vm.define "wilSW" do |control|
    control.vm.hostname = "wilSW"
    control.vm.network REDACTED, ip: "192.168.56.111"
    control.vm.provider REDACTED do |v|
      v.customize ["modifyvm", :id, "--name", "wilSW"]
      [...]
    end
    config.vm.provision "shell", inline: <<-SHELL
      [..]
    SHELL
    control.vm.provision "shell", path: REDACTED
  end
end
```
Notes:
- `modifyvm` calls imply **VirtualBox** as Vagrant provider.
- Replace `REDACTED` with `:private_network` for `vm.network` and `"virtualbox"` for `vm.provider`.
- Use `config.vm.box` like `"generic/centos8"`, `"debian/bookworm64"`, `"ubuntu/jammy64"`, etc.

### 3.5 K3s installation outline
- **Server** install command (typical):
  ```bash
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --bind-address=192.168.56.110 --advertise-address=192.168.56.110 --flannel-iface=<iface>" sh -
  ```
  Then read the join token: `cat /var/lib/rancher/k3s/server/node-token`.
- **Agent** install command (typical):
  ```bash
  curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 \
       K3S_TOKEN=<token> \
       INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=<iface>" sh -
  ```
- Share the token between VMs via a synced folder or `scp`.

### 3.6 Acceptance criteria
- `vagrant up` brings both VMs up with the configured names/IPs.
- `vagrant ssh wilS` and `vagrant ssh wilSW` succeed without password.
- On the server, `kubectl get nodes -o wide` shows **both** nodes `Ready`, with `INTERNAL-IP` of `192.168.56.110` (control-plane,master) and `192.168.56.111` (worker), e.g.:
  ```
  NAME    STATUS   ROLES                  AGE   VERSION       INTERNAL-IP      OS-IMAGE
  wilS    Ready    control-plane,master   16m   v1.21.4+k3s1  192.168.56.110   ...
  wilSW   Ready    <none>                 78s   v1.21.4+k3s1  192.168.56.111   ...
  ```

### 3.7 Common pitfall (called out in subject)
- Modern Linux distros use `enp0s8`/`enp0s9`-style interface names, not `eth0`/`eth1`. Detect them with `ip a` before passing `--flannel-iface` / `--node-ip`.

---

## 4. Part 2 — K3s + 3 Web Apps with Ingress (`p2/`)

### 4.1 Objective
Single VM running K3s (server mode). Deploy **3 web apps** routed by **HTTP HOST header** through an Ingress.

### 4.2 VM specs
- 1 VM, hostname `<login>S` (e.g. `wilS`), IP `192.168.56.110`.
- Latest stable distro of choice. K3s in server mode.

### 4.3 Routing requirements (HOST-based ingress on `192.168.56.110`)

| HTTP Host header | Route to | Replicas |
|---|---|---|
| `app1.com` | app1 | 1 |
| `app2.com` | app2 | **3** |
| (default / anything else) | app3 | 1 |

- App2 must have **3 replicas** (Deployment `replicas: 3`).
- All three apps are web apps of the student's choice (e.g. `nginx` with custom content, or any small `Hello`-style image).

### 4.4 Kubernetes resources to produce (in `p2/confs/`)
For each app:
- A `Deployment` (app2's deployment uses `replicas: 3`).
- A `Service` of type `ClusterIP` (port 80, or whatever the container exposes).
A single `Ingress` (Traefik is the default ingress controller bundled with K3s) with rules:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apps-ingress
spec:
  rules:
    - host: app1.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: app-one,   port: { number: 80 } }
    - host: app2.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: app-two,   port: { number: 80 } }
  defaultBackend:
    service:
      name: app-three
      port: { number: 80 }
```
> Note: The default routing for "anything else" can be done via `defaultBackend` OR an additional rule without `host`. The subject says "Otherwise, app3 will be selected by default."

### 4.5 Verification
- `kubectl get all` shows 3 deployments, 3 services, 5 pods (1+3+1) all `Running`.
- From host (or VM): `curl -H "Host: app1.com" http://192.168.56.110` → app1 content.
- `curl -H "Host: app2.com" http://192.168.56.110` → app2 content (HTML output shown in subject).
- `curl http://192.168.56.110` (no host override, or any other host) → app3 content.
- Subject example shows responses like "Hello from app1.", "Hello from app2.", "Hello from app3." rendered in a Kubernetes-styled HTML page.

### 4.6 Defense
- Ingress object is **not** shown in subject screenshots on purpose. Be ready to show `kubectl get ingress` / `kubectl describe ingress` to the evaluators.

---

## 5. Part 3 — K3d and Argo CD (`p3/`)

### 5.1 Objective
Set up a **K3d** cluster (no Vagrant), install **Argo CD**, deploy an application from a **public GitHub repo** into a `dev` namespace, demonstrate GitOps by changing the image tag in the repo and seeing the live cluster update.

### 5.2 Required installer script (`p3/scripts/...`)
A shell script must install **all** prerequisites on the VM:
- Docker (k3d runs the cluster inside Docker containers).
- `kubectl`.
- `k3d`.
- `argocd` CLI (optional but recommended).
- Any helpers (`curl`, `git`, etc.).

### 5.3 K3s vs K3d (must be understood)
- **K3s**: lightweight Kubernetes distro running directly on the OS (used in p1/p2).
- **K3d**: wrapper that runs K3s **inside Docker** containers — fast local clusters, no VM-in-VM concerns aside from Docker.

### 5.4 Cluster topology

| Namespace | Purpose |
|---|---|
| `argocd` | Argo CD control plane (server, repo-server, application-controller, redis, dex) |
| `dev`    | Application workload deployed and managed by Argo CD |

Create with:
```bash
kubectl create namespace argocd
kubectl create namespace dev
```

### 5.5 Argo CD install
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# wait for pods
kubectl wait --for=condition=available --timeout=600s -n argocd deployment/argocd-server
# expose UI (port-forward is fine for the defense)
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
# initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### 5.6 The application to deploy

#### Option A — Use Wil's prebuilt image (recommended)
- Docker Hub: `wil42/playground`
- Source URL: <https://hub.docker.com/r/wil42/playground>
- Listens on port **8888**.
- Has tags **`v1`** and **`v2`** (visible under the *TAG* section on Docker Hub).
- Returns JSON, e.g.:
  - v1 → `{"status":"ok", "message": "v1"}`
  - v2 → `{"status":"ok", "message": "v2"}`

#### Option B — Bring your own
- Build a small app, push it to a **public Docker Hub repo**.
- Tag two versions **`v1`** and **`v2`** with visibly different behaviour.

### 5.7 GitHub repository requirements
- Must be **public**.
- Name must include the **login of a group member**.
- Hosts the Argo CD–watched manifests (Deployment, Service, possibly Ingress for the app).
- Layout is free; common layout:
  ```
  manifests/
    deployment.yaml
    service.yaml
  ```

### 5.8 Argo CD `Application` resource example (`p3/confs/argocd-app.yaml`)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wil-playground
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<login>/<repo-with-login-in-name>.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 5.9 App Deployment manifest (in the GitHub repo)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wil-playground
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels: { app: wil-playground }
  template:
    metadata:
      labels: { app: wil-playground }
    spec:
      containers:
        - name: app
          image: wil42/playground:v1    # <-- the tag students will flip to v2
          ports:
            - containerPort: 8888
---
apiVersion: v1
kind: Service
metadata:
  name: wil-playground
  namespace: dev
spec:
  selector: { app: wil-playground }
  ports:
    - port: 8888
      targetPort: 8888
```

### 5.10 K3d cluster creation (port-mapping for app)
```bash
k3d cluster create iot \
  --api-port 6550 \
  -p "8888:8888@loadbalancer" \
  --agents 0
```
The `-p` mapping makes `localhost:8888` on the VM reach the in-cluster service (when combined with an appropriate Service/Ingress on port 8888).

### 5.11 GitOps flow to demonstrate
1. Repo `manifests/deployment.yaml` has `image: wil42/playground:v1`.
2. Argo CD syncs → pod runs v1.
3. Verify:
   ```
   $ curl http://localhost:8888/
   {"status":"ok", "message": "v1"}
   ```
4. Edit repo: change `v1` → `v2`, commit, push:
   ```bash
   sed -i 's/wil42\/playground\:v1/wil42\/playground\:v2/g' deployment.yaml
   git add deployment.yaml
   git commit -m "v2"
   git push
   ```
5. Argo CD auto-syncs (or trigger manual sync) → pod re-rolls to v2.
6. Verify:
   ```
   $ curl http://localhost:8888/
   {"status":"ok", "message": "v2"}
   ```

### 5.12 Verification commands (subject-shown)
```
$ kubectl get ns
NAME     STATUS   AGE
...
argocd   Active   19h
dev      Active   19h

$ kubectl get pods -n dev
NAME                               READY   STATUS    RESTARTS   AGE
wil-playground-65f745fdf4-d2l2r    1/1     Running   0          8m9s
```

### 5.13 Defense expectations
- Show namespaces, pods, Argo CD UI (sync status `Healthy` / `Synced`).
- Demonstrate version flip from `v1` to `v2` live via GitHub push.

---

## 6. Bonus — Self-hosted GitLab (`bonus/`)

### 6.1 Objective
Replace (or supplement) the external GitHub repo by hosting **GitLab** inside the cluster, and have Argo CD pull from that local GitLab instead.

### 6.2 Requirements
- Run **GitLab locally** in the cluster.
- Use the **latest version** of GitLab from the official source.
- Create a dedicated namespace named **`gitlab`**.
- Configure GitLab so it integrates with the K3d cluster.
- Everything from Part 3 must work using the **local GitLab** as the source repo for Argo CD.
- **Helm** is explicitly suggested (use the official GitLab Helm chart).

### 6.3 Implementation outline
- Install Helm.
- Add GitLab Helm repo: `helm repo add gitlab https://charts.gitlab.io/`.
- Create namespace: `kubectl create ns gitlab`.
- `helm upgrade --install gitlab gitlab/gitlab -n gitlab -f values.yaml` with appropriate values (disable cert-manager or use self-signed for local; expose via Traefik / NodePort).
- Configure local DNS / `/etc/hosts` so the GitLab hostname resolves.
- Push the same manifests from Part 3 into a project on this GitLab.
- Update the Argo CD `Application.spec.source.repoURL` to point to the local GitLab URL.
- Re-run the v1 → v2 flow against the local GitLab.

### 6.4 Evaluation rule
> **Bonus is evaluated only if the mandatory part is flawless** (fully complete and bug-free). Any failing item in p1/p2/p3 means the bonus is not graded at all.

---

## 7. Tech Stack Summary

| Layer | Technology |
|---|---|
| VM provisioning | Vagrant (VirtualBox provider implied) |
| Guest OS | Latest stable Linux distro (choice) |
| Cluster (p1, p2) | K3s (server + agent in p1, server-only in p2) |
| Cluster (p3) | K3d (K3s in Docker) |
| Container runtime backing K3d | Docker |
| Ingress controller | Traefik (bundled with K3s/K3d) |
| GitOps controller | Argo CD |
| Source of truth | Public GitHub repo (mandatory) / local GitLab (bonus) |
| App image | `wil42/playground:v1` & `:v2` (port 8888) — or own image |
| Package manager (bonus) | Helm |

---

## 8. Implementation Order (suggested)

1. **p1** — Vagrantfile + provisioning scripts → 2 VMs → K3s server+agent → `kubectl get nodes` shows both Ready.
2. **p2** — Single-VM Vagrantfile → K3s server → write app manifests (deployments, services) + Ingress with host rules → verify with `curl -H "Host: app{1,2}.com" http://192.168.56.110`.
3. **p3** — Installer script (Docker, kubectl, k3d) → `k3d cluster create` → install Argo CD → create `dev` namespace → push manifests to public GitHub repo → create Argo CD `Application` → verify v1 → flip to v2 via Git push → verify v2.
4. **bonus** — Helm-install GitLab in `gitlab` namespace → migrate manifests to a GitLab project → repoint Argo CD `Application` → re-validate p3 flow.

---

## 9. Critical Subject Notes (do not miss)

- Hostnames must literally use the **uppercase `S`** and **`SW`** suffixes.
- IPs are **exactly** `192.168.56.110` and `192.168.56.111`.
- App2 needs **exactly 3 replicas** (or more — but the spec says 3).
- App3 is the **default**, not host-bound.
- p3 GitHub repo must be **public** and named to include a group member's login.
- The application image in p3 must have **two distinct, visibly different versions** tagged `v1` and `v2`.
- Provisioning scripts must install **all** required packages (Docker, kubectl, k3d, etc.) so the defense machine can be set up reproducibly.
- Ingress is intentionally hidden from screenshots — be ready to show it live.
- All work must run inside a VM; the evaluation happens on the student's machine.
- Bonus is graded **only** if all mandatory parts are flawless.

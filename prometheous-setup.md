
## 🧩 **Goal**

Deploy Prometheus manually on Kubernetes using:

* **ConfigMap** → configuration file (`prometheus.yml`)
* **Deployment** → runs Prometheus container
* **Service** → exposes it for access

---

## ⚙️ **Step 1 — Create Namespace**

```bash
kubectl create namespace monitoring
```

---

## 📄 **Step 2 — Create Prometheus Configuration**

Create a file named **`prometheus-config.yaml`**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
  labels:
    name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      # Scrape Prometheus itself
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      # Scrape all Kubernetes pods with annotation
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.*)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            target_label: __address__
            regex: (.*):(\d+)
            replacement: $1:$2
```

Apply it:

```bash
kubectl apply -f prometheus-config.yaml
```

---

## 📦 **Step 3 — Create Prometheus Deployment**

Create **`prometheus-deployment.yaml`**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-deployment
  namespace: monitoring
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.52.0
        args:
          - "--config.file=/etc/prometheus/prometheus.yml"
          - "--storage.tsdb.path=/prometheus/"
        ports:
          - containerPort: 9090
        volumeMounts:
          - name: prometheus-config-volume
            mountPath: /etc/prometheus/
      volumes:
        - name: prometheus-config-volume
          configMap:
            name: prometheus-config
```

Apply it:

```bash
kubectl apply -f prometheus-deployment.yaml
```

---

## 🌐 **Step 4 — Expose Prometheus**

Create **`prometheus-service.yaml`**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: monitoring
  labels:
    app: prometheus
spec:
  type: NodePort
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30090
  selector:
    app: prometheus
```

Apply it:

```bash
kubectl apply -f prometheus-service.yaml
```

---

## 🧪 **Step 5 — Verify Everything**

```bash
kubectl get all -n monitoring
```

Expected:

```
NAME                                       READY   STATUS    RESTARTS   AGE
pod/prometheus-deployment-xxxxxxx-xxxxx    1/1     Running   0          1m

service/prometheus-service   NodePort   10.x.x.x   <none>   9090:30090/TCP   1m
```

---

## 🌍 **Step 6 — Access Prometheus UI**

If using a local cluster (like Vagrant, Minikube, Kind):

```bash
kubectl port-forward svc/prometheus-service -n monitoring 9090:9090
```

Then open:
👉 **[http://localhost:9090](http://localhost:9090)**

---

## 🧠 **Step 7 — Test Queries**

Inside the web UI → go to **Graph** tab:

* `up` → checks running targets
* `prometheus_http_requests_total` → shows internal metrics

---

## 🧾 **Step 8 — Add a Sample App to Monitor**

Deploy a test app (like `nginx`) and add scrape annotations:

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80
kubectl annotate pod -l app=nginx prometheus.io/scrape="true" prometheus.io/port="80"
```

Now Prometheus automatically scrapes NGINX pod metrics!

---

## 🧑‍🏫 **How to Explain to Students**

| Concept           | What Happens                                                   |
| ----------------- | -------------------------------------------------------------- |
| **ConfigMap**     | Holds Prometheus configuration (what to monitor)               |
| **Deployment**    | Runs the Prometheus container                                  |
| **Service**       | Exposes Prometheus UI on NodePort 30090                        |
| **Scrape Target** | Each pod or service that exports metrics                       |
| **Annotation**    | Labels that tell Prometheus which pods to collect metrics from |

---
Here’s a clean, step-by-step guide to **run Grafana as a container inside Kubernetes** (no Helm) — so students can understand how Grafana actually runs and connects to Prometheus.

---

## 🧩 **Goal**

Run Grafana on Kubernetes, connect it to Prometheus, and open the dashboard.

---

## ⚙️ Step 1 — Namespace (if not created)

```bash
kubectl create namespace monitoring
```

---

## 📄 Step 2 — Create a ConfigMap for Grafana Datasource

Create a file named **`grafana-datasource.yaml`**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasource
  namespace: monitoring
data:
  datasource.yml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus-service.monitoring.svc.cluster.local:9090
        isDefault: true
```

Apply it:

```bash
kubectl apply -f grafana-datasource.yaml
```

---

## 📦 Step 3 — Create Grafana Deployment

Create **`grafana-deployment.yaml`**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.2.0
        ports:
          - containerPort: 3000
        env:
          - name: GF_SECURITY_ADMIN_USER
            value: admin
          - name: GF_SECURITY_ADMIN_PASSWORD
            value: admin123
        volumeMounts:
          - name: grafana-storage
            mountPath: /var/lib/grafana
          - name: grafana-datasource
            mountPath: /etc/grafana/provisioning/datasources/
      volumes:
        - name: grafana-storage
          emptyDir: {}
        - name: grafana-datasource
          configMap:
            name: grafana-datasource
```

Apply it:

```bash
kubectl apply -f grafana-deployment.yaml
```

---

## 🌐 Step 4 — Expose Grafana Service

Create **`grafana-service.yaml`**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
  labels:
    app: grafana
spec:
  type: NodePort
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30300
  selector:
    app: grafana
```

Apply it:

```bash
kubectl apply -f grafana-service.yaml
```

---

## 🧪 Step 5 — Verify Deployment

```bash
kubectl get all -n monitoring
```

Expected:

```
pod/grafana-xxxxxx       Running
service/grafana          NodePort   3000:30300/TCP
```

---

## 🌍 Step 6 — Access Grafana

If you’re using a local cluster (Vagrant/Minikube):

```bash
kubectl port-forward svc/grafana -n monitoring 3000:3000
```

Then open your browser →
👉 **[http://localhost:3000](http://localhost:3000)**

Login:

* Username: `admin`
* Password: `admin123`

---

## 🧠 Step 7 — Confirm Prometheus Connection

In Grafana →
**Connections → Data sources → Prometheus → Test connection**

It should show ✅ *Data source is working!*


http://prometheus-service.monitoring.svc.cluster.local:9090
---

## 🧩 Step 8 — Import Dashboards

* Go to **Dashboards → Import**
* Use any of these IDs from Grafana Labs:

  * **1860** → Node Exporter / Cluster overview
  * **3662** → K8s pods metrics
  * **12019** → Loki logs (if Loki installed)

---

## 🧠 For Students: How It Fits Together

| Component              | Role                                                              |
| ---------------------- | ----------------------------------------------------------------- |
| **Prometheus**         | Collects metrics (CPU, memory, pod usage)                         |
| **Grafana**            | Visualizes metrics via dashboards                                 |
| **ConfigMap**          | Preconfigures Prometheus as a data source                         |
| **Service (NodePort)** | Exposes Grafana web UI                                            |
| **Kubernetes Objects** | Students learn how Deployments, ConfigMaps, and Services interact |

---


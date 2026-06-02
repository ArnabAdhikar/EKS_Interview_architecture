# 📊 Observability Pipeline Documentation (OpenTelemetry, OpenSearch, Jaeger, Grafana, Alertmanager)

This branch contains the production-grade implementation of a unified observability pipeline on **Amazon EKS** using the **OpenTelemetry (OTel) Collector**. This configuration collects and routes the three pillars of telemetry:
1. 📝 **Logs:** Harvested from host nodes and pushed to **Amazon OpenSearch Service** (Elasticsearch API compatible).
2. 🔍 **Traces:** Ingested from application pods via OTLP and sent to **Jaeger** for distributed trace path visualization.
3. 📈 **Metrics:** Scraped by Prometheus and visualized in **Grafana**, with resource alert routes configured via **Alertmanager**.

---

## 🛠️ Step-by-Step Actions Executed

The following actions were performed to configure and test this observability pipeline:

### Step 1: OpenSearch Domain Setup (Terraform)
* **Configuration File:** Added [terraform/opensearch.tf](file:///c:/Users/arnab/OneDrive/Desktop/Project_Archieve/EKS_Interview_architecture/terraform/opensearch.tf) to define an Amazon OpenSearch domain named `eks-app-logs` in private subnets with a security group restricting traffic only to EKS worker nodes on port `443`.
* **Execution:** Ran `terraform apply` which successfully updated the VPC infrastructure and provisioned the active domain endpoint:
  ```
  https://vpc-eks-app-logs-hfjqijbltgfra32zg6y2umc7ya.us-west-2.es.amazonaws.com
  ```

### Step 2: Jaeger Deployment (Kubernetes)
* **Configuration File:** Added [k8s_manifests/jaeger.yaml](file:///c:/Users/arnab/OneDrive/Desktop/Project_Archieve/EKS_Interview_architecture/k8s_manifests/jaeger.yaml) defining Jaeger `all-in-one` with OTLP ingestion enabled.
* **Execution:** Deployed Jaeger Collector and Query services:
  ```bash
  kubectl apply -f k8s_manifests/jaeger.yaml
  ```

### Step 3: OpenTelemetry Collector Setup & Exporter Patching
* **Configuration File:** Added [k8s_manifests/otel-collector.yaml](file:///c:/Users/arnab/OneDrive/Desktop/Project_Archieve/EKS_Interview_architecture/k8s_manifests/otel-collector.yaml) defining the OTel ConfigMap, Deployment, and Service.
* **Refinements Performed:**
  - Configured `exporters.opensearch` to use the correct `http.endpoint` syntax nested structure required by the OpenTelemetry `opensearchexporter` plugin.
  - Omitted the unsupported container logs operator format to allow native log stream parsing of CRI-formatted files from `/var/log/pods`.
* **Execution:** Applied the configuration and successfully rolled out the healthy collector pod:
  ```bash
  kubectl apply -f k8s_manifests/otel-collector.yaml
  ```

### Step 4: Metric Alert Rules (Prometheus Operator)
* **Configuration File:** Added [k8s_manifests/prometheus-alert-rules.yaml](file:///c:/Users/arnab/OneDrive/Desktop/Project_Archieve/EKS_Interview_architecture/k8s_manifests/prometheus-alert-rules.yaml) defining a `PrometheusRule` resource for EKS node resource alerts.
* **Rules Configured:**
  - **`EKSNodeHighCPU`**: Triggers if node CPU utilization is >85% for 5 minutes.
  - **`EKSNodeHighMemory`**: Triggers if node memory usage is >85% for 5 minutes.
  - **`PodCPUThrottling`**: Triggers if containers are actively being throttled by Kubernetes scheduler limits.
* **Execution:** Applied the rule mapping to the EKS prometheus namespace:
  ```bash
  kubectl apply -f k8s_manifests/prometheus-alert-rules.yaml
  ```

### Step 5: Application Telemetry SDK Configuration
* **Configuration Files:** Modified existing deployment manifests:
  - [k8s_manifests/backend-deployment.yaml](file:///c:/Users/arnab/OneDrive/Desktop/Project_Archieve/EKS_Interview_architecture/k8s_manifests/backend-deployment.yaml)
  - [k8s_manifests/frontend-deployment.yaml](file:///c:/Users/arnab/OneDrive/Desktop/Project_Archieve/EKS_Interview_architecture/k8s_manifests/frontend-deployment.yaml)
* **Logic:** Injected environment variables so the applications point to the collector's internal DNS endpoint on startup:
  ```yaml
  env:
    - name: OTEL_EXPORTER_OTLP_ENDPOINT
      value: "http://otel-collector-svc.workshop.svc.cluster.local:4317"
    - name: OTEL_SERVICE_NAME
      value: "backend-api" # or "frontend-web"
  ```
* **Execution:** Deployed and confirmed rollout:
  ```bash
  kubectl apply -f k8s_manifests/backend-deployment.yaml
  kubectl apply -f k8s_manifests/frontend-deployment.yaml
  ```

---

## 🔍 Verification of Deployed Resources

All EKS pods are fully operational and stable in the `workshop` namespace:

```bash
$ kubectl get pods -n workshop
NAME                              READY   STATUS    RESTARTS   AGE
api-68cbd8fb85-sflqx              1/1     Running   0          5m
api-68cbd8fb85-xrqfj              1/1     Running   0          5m
frontend-695bdd9b86-tcxlt         1/1     Running   0          5m
jaeger-64d5dcd677-zwgd9           1/1     Running   0          20m
mongodb-7f58f6bc67-hppnq          1/1     Running   0          3h33m
otel-collector-57d789dcb5-l52tq   1/1     Running   0          6m
```

---

## 🌐 How to Access Observability Dashboards

### 1. distributed Tracing (Jaeger UI)
Establish a local tunnel to the Jaeger service:
```bash
kubectl port-forward svc/jaeger-query 8083:80 -n workshop
```
* **URL:** [http://localhost:8083](http://localhost:8083)

### 2. Log Analysis (OpenSearch Dashboards)
Because the Amazon OpenSearch domain is hosted inside a private VPC, start a lightweight proxy inside EKS to forward your local port:
```bash
# Start proxy
kubectl run os-proxy --image=alpine/socat -n workshop -- tcp-listen:5601,fork,reuseaddr tcp:vpc-eks-app-logs-hfjqijbltgfra32zg6y2umc7ya.us-west-2.es.amazonaws.com:443

# Tunnel traffic
kubectl port-forward pod/os-proxy 5601:5601 -n workshop
```
* **URL:** [https://localhost:5601/_dashboards](https://localhost:5601/_dashboards) *(Be sure to use **https://** explicitly and bypass the browser's SSL warning).*

### 3. Unified Metrics (Grafana)
Establish a local tunnel to Grafana:
```bash
kubectl port-forward svc/prometheus-grafana 8082:80 -n prometheus
```
* **URL:** [http://localhost:8082](http://localhost:8082)
* **Default credentials:** Username: `admin` / Password: `prom-operator`

Add OpenSearch index (`eks-container-logs`) and Jaeger endpoint (`http://jaeger-query.workshop.svc.cluster.local`) as Data Sources in Grafana to enable full telemetry correlation.

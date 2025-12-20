
# Crossplane on Kubernetes – Setup Guide

*(Including Helm Installation, Until Provider Enabled)*

This guide explains how to install **Crossplane** on a Kubernetes cluster (kubeadm-based) using **Helm**, and how to enable an **Azure provider**, without creating any cloud resources.

> **Scope of this README**
>
> * Install Helm
> * Install Crossplane using Helm
> * Verify Crossplane core components
> * Install Azure provider package
> * Verify provider is installed and healthy
>   ❌ No Azure authentication
>   ❌ No Azure resources created

---

## 1. Prerequisites

* Kubernetes cluster running

  * Example: kubeadm (1 master, 2 workers)
* `kubectl` configured and working
* Internet access from nodes
* OS: Linux (Ubuntu / RHEL / CentOS)

Verify Kubernetes access:

```bash
kubectl get nodes
kubectl cluster-info
```

---

## 2. Install Helm (Kubernetes Package Manager)

Helm is required to install Crossplane.

### 2.1 Download Helm (Linux amd64)

```bash
curl -fsSL https://get.helm.sh/helm-v3.15.4-linux-amd64.tar.gz -o helm.tar.gz
```

Extract:

```bash
tar -zxvf helm.tar.gz
```

Move Helm binary to PATH:

```bash
sudo mv linux-amd64/helm /usr/local/bin/helm
```

Verify installation:

```bash
helm version
```

Expected output (example):

```text
version.BuildInfo{Version:"v3.15.4", GoVersion:"go1.xx.x"}
```

---

### 2.2 (Optional) Enable bash completion

```bash
helm completion bash | sudo tee /etc/bash_completion.d/helm
source ~/.bashrc
```

---

## 3. Install Crossplane

### 3.1 Add Crossplane Helm repository

```bash
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
```

---

### 3.2 Create Crossplane namespace

```bash
kubectl create namespace crossplane-system
```

---

### 3.3 Install Crossplane using Helm

```bash
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system
```

---

## 4. Verify Crossplane Installation

### 4.1 Check Crossplane pods

```bash
kubectl get pods -n crossplane-system
```

Expected pods:

* `crossplane`
* `crossplane-rbac-manager`

Both should be in `Running` state.

---

### 4.2 Check Crossplane version

```bash
kubectl get deployment -n crossplane-system crossplane \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Example output:

```text
xpkg.crossplane.io/crossplane/crossplane:v2.x.x
```

---

### 4.3 Verify Crossplane CRDs

```bash
kubectl get crds | grep crossplane
```

This confirms Crossplane APIs are installed.

---

## 5. Understanding Providers in Crossplane

* Crossplane core **does nothing by itself**
* All integrations are done via **Providers**
* Providers:

  * Install CRDs
  * Run controller pods
  * Connect Kubernetes to external systems (Azure, AWS, etc.)

Before installing any provider:

```bash
kubectl get providers
```

Output:

```text
No resources found
```

(This is expected.)

---

## 6. Install Azure Provider (Provider Family)

> This step **only installs the provider runtime**.
> No Azure credentials or resources are created.

### 6.1 Create Provider manifest

Create file: `provider-family-azure.yaml`

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-family-azure
spec:
  package: xpkg.upbound.io/upbound/provider-family-azure:v2.3.0
```

---

### 6.2 Apply the Provider

```bash
kubectl apply -f provider-family-azure.yaml
```

---

## 7. Verify Provider Installation

### 7.1 Check provider status

```bash
kubectl get providers
```

Expected (initially):

```text
NAME                    INSTALLED   HEALTHY   PACKAGE
provider-family-azure   True        False     xpkg.upbound.io/upbound/provider-family-azure:v2.3.0
```

> `HEALTHY=False` is normal immediately after installation.

---

### 7.2 Check provider pods

```bash
kubectl get pods -n crossplane-system
```

Expected:

```text
provider-family-azure-xxxxxx   1/1   Running
```

---

### 7.3 Check ProviderRevision (important)

```bash
kubectl get providerrevisions
```

Example output:

```text
NAME                                 HEALTHY   RUNTIME   STATE
provider-family-azure-xxxxxxxxx      True      True      Active
```

This confirms:

* Provider package unpacked successfully
* Runtime controllers are healthy
* Provider is ready for authentication

---

## 8. Current State Summary (End of This README)

At this point:

✅ Helm installed
✅ Crossplane installed using Helm
✅ Crossplane core running
✅ Azure provider installed
✅ ProviderRevision healthy
❌ No Azure authentication configured
❌ No Azure resources created

This is the **correct stopping point** before enabling:

* Service Principal authentication **or**
* Managed Identity authentication

---

## 9. What Comes Next (Out of Scope)

The next steps should be in a **separate README**:

1. Configure Azure authentication

   * Managed Identity **or**
   * Service Principal
2. Create `ProviderConfig`
3. Use existing Azure Resource Group
4. Create a small test resource (Storage Account)

---

## 10. Useful Debug Commands

```bash
kubectl get pods -n crossplane-system
kubectl get providers
kubectl get providerrevisions
kubectl describe provider provider-family-azure
kubectl get events -n crossplane-system --sort-by=.lastTimestamp | tail -n 20
```

---

## 11. Key Concept (For Learners)

> **Helm installs Crossplane
> Crossplane installs Providers
> Providers enable infrastructure control**

---

If you want next, I can generate:

* `README-auth-managed-identity.md`
* `README-auth-service-principal.md`
* `README-crossplane-first-resource.md`
* A **single combined lab manual (PDF / DOCX)**

Just tell me 👍

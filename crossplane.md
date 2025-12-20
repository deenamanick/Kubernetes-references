
# Crossplane on Kubernetes – Setup Guide

*(Including Helm, Azure Provider & AWS Provider – Until Authentication)*

This guide explains how to install **Crossplane** on a Kubernetes cluster (kubeadm-based) using **Helm**, and how to enable **both Azure and AWS providers**, without creating any cloud resources.

> **Scope of this README**
>
> ✅ Install Helm
> ✅ Install Crossplane using Helm
> ✅ Verify Crossplane core components
> ✅ Install Azure provider
> ✅ Install AWS provider
> ✅ Verify providers are installed and healthy
>
> ❌ No cloud authentication
> ❌ No cloud resources created

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

---

## 5. Understanding Providers in Crossplane

* Crossplane core **does nothing by itself**
* Every cloud integration requires a **Provider**
* Providers:

  * Install cloud-specific CRDs
  * Run controller pods
  * Talk to cloud APIs (Azure, AWS, etc.)

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

> This step installs the Azure provider runtime only.
> **No Azure credentials or resources are created.**

### 6.1 Create Azure Provider manifest

Create file: `provider-family-azure.yaml`

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-family-azure
spec:
  package: xpkg.upbound.io/upbound/provider-family-azure:v2.3.0
```

Apply:

```bash
kubectl apply -f provider-family-azure.yaml
```

---

## 7. Install AWS Provider (Provider Family)

> This step installs the AWS provider runtime only.
> **No AWS credentials or resources are created.**

### 7.1 Create AWS Provider manifest

Create file: `provider-family-aws.yaml`

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-family-aws
spec:
  package: xpkg.upbound.io/upbound/provider-family-aws:v1.16.0
```

Apply:

```bash
kubectl apply -f provider-family-aws.yaml
```

---

## 8. Verify Provider Installation (Azure + AWS)

### 8.1 Check providers

```bash
kubectl get providers
```

Expected output (initially):

```text
NAME                    INSTALLED   HEALTHY   PACKAGE
provider-family-azure   True        False     xpkg.upbound.io/upbound/provider-family-azure:v2.3.0
provider-family-aws     True        False     xpkg.upbound.io/upbound/provider-family-aws:v1.16.0
```

> `HEALTHY=False` is normal immediately after installation.

---

### 8.2 Check provider pods

```bash
kubectl get pods -n crossplane-system
```

Expected pods:

```text
provider-family-azure-xxxxx   1/1   Running
provider-family-aws-xxxxx     1/1   Running
```
## result should be like this

```

[vagrant@kubemaster ~]$ kubectl get pods -n crossplane-system -o wide
NAME                                                READY   STATUS    RESTARTS   AGE   IP            NODE              NOMINATED NODE   READINESS GATES
crossplane-7f9956d85f-j8vjh                         1/1     Running   0          95s   10.244.1.50   worker1.uat.com   <none>           <none>
crossplane-rbac-manager-6d7d5844bd-b2gxc            1/1     Running   0          20m   10.244.1.47   worker1.uat.com   <none>           <none>
provider-family-aws-4c8d237e76d4-847f455fd9-p95dq   1/1     Running   0          89s   10.244.2.73   worker2.uat.com   <none>           <none>

[vagrant@kubemaster ~]$ kubectl get provider
NAME                  INSTALLED   HEALTHY   PACKAGE                                               AGE
provider-family-aws   True        True      xpkg.upbound.io/upbound/provider-family-aws:v1.16.0   3m50s
[vagrant@kubemaster ~]$ kubectl get providerrevisions
NAME                               HEALTHY   RUNTIME   IMAGE                                                 STATE    AGE
provider-family-aws-4c8d237e76d4   True      True      xpkg.upbound.io/upbound/provider-family-aws:v1.16.0   Active   3m13s
[vagrant@kubemaster ~]$ 

```


---

### 8.3 Check ProviderRevisions (important)

```bash
kubectl get providerrevisions
```

Example output:

```text
NAME                                  HEALTHY   RUNTIME   STATE
provider-family-azure-xxxxxxx         True      True      Active
provider-family-aws-xxxxxxx           True      True      Active
```

This confirms:

* Provider packages unpacked successfully
* Runtime controllers are healthy
* Providers are ready for authentication

---

## 9. Current State Summary (End of This README)

At this point:

✅ Helm installed
✅ Crossplane installed using Helm
✅ Crossplane core running
✅ Azure provider installed
✅ AWS provider installed
✅ ProviderRevisions healthy
❌ No Azure authentication
❌ No AWS authentication
❌ No cloud resources created

This is the **correct stopping point** before enabling:

* Azure authentication (Managed Identity or Service Principal)
* AWS authentication (IAM User / IAM Role / IRSA)

---

## 10. What Comes Next (Out of Scope)

Create **separate READMEs** for authentication and resource creation:

1. Azure authentication

   * Managed Identity
   * Service Principal
2. AWS authentication

   * IAM User (Access Key)
   * IAM Role / IRSA
3. Create `ProviderConfig`
4. Use existing Resource Groups / VPCs
5. Create small test resources

   * Azure Storage Account
   * AWS S3 Bucket

---

## 11. Useful Debug Commands

```bash
kubectl get pods -n crossplane-system
kubectl get providers
kubectl get providerrevisions
kubectl describe provider provider-family-azure
kubectl describe provider provider-family-aws
kubectl get events -n crossplane-system --sort-by=.lastTimestamp | tail -n 20
```

---

## 12. Key Concept (For Learners)

> **Helm installs Crossplane**
> **Crossplane installs Providers**
> **Providers enable multi-cloud infrastructure control**

---

Just tell me what you want next 👍

## Kubernetes Resource Checker.

Checks Your Kubernetes resource for failing resources. Can be integrated with an on-failure call. 

### Usage

The Scripts checks the following Resources

  - PODS: Restarting PODS and incomplete PODS
  - Services: Services Without Endpoint and Pending Services 
  - Failed Deployments
  - Failed Jobs
  - Failed Statefulset
  - Failed Daemonset.

### Installation

#### Dependencies

  - jq
  - Kubectl

**Ensure Kubectl and jq are installed and your cluster is properly connected. And file has sufficient permisiion (executable permission)** 

To make file executable run

```bash
chmod 700 k8-check.sh
```

Run checks using:

```bash
./k8-check.sh -o=<output-filename>  -n=<namespace>
```

#### Flags
  - -o name of output file. **REQUIRED**
  - -n namespace to check. (all for all namespaces). **REQUIRED**

### Improvements
  - --ignore flag is to be added to ignore certain parameters.
  - .k8ignore file to ignore multiple parameters.

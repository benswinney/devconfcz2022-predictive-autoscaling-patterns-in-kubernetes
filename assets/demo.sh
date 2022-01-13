. demo-magic.sh -n

# WARNING: This demoscript needs VerticalPodAutoscaler operator installed.

PROMPT_TIMEOUT=7

p "# Deploying applications without VPA"
pei "PROJECT=test-novpa-devconf22"
p ""

p "# Namespace creation"
pei "oc new-project $PROJECT"
p ""

p "# Delete existing LimitRange"
pei "oc delete limitrange --all -n $PROJECT"
p ""

p "# Deploying example application"
pei 'cat <<EOF | oc -n $PROJECT apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-novpa
spec:
  selector:
    matchLabels:
      app: stress
  replicas: 1
  template:
    metadata:
      labels:
        app: stress
    spec:
      containers:
      - name: stress
        image: polinux/stress
        resources:
          requests:
            memory: "100Mi"
          limits:
            memory: "200Mi"
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "250M"]
EOF'
p ""

PROMPT_TIMEOUT=60
wait

p "# Listing pod status"
pei "oc describe pod | grep Reason:"
p ""

p "# The pods gets killed as the the vm the container use is above the spec.resources.limits.memory"
p ""

p "# Deploying applications with VPA"

pei "PROJECT=test-vpa-devconf22"

p ""
p "# Namespace creation"
pei "oc new-project $PROJECT"
p ""

p "# Delete existing LimitRange"
pei "oc delete limitrange --all -n $PROJECT"
p ""

p "# Now, define the requests as 100Mi and the limits with 200Mi for the container stress."
p ""

pei 'cat <<EOF | oc -n $PROJECT apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress
spec:
  selector:
    matchLabels:
      app: stress
  replicas: 1
  template:
    metadata:
      labels:
        app: stress
    spec:
      containers:
      - name: stress
        image: polinux/stress
        resources:
          requests:
            memory: "100Mi"
          limits:
            memory: "200Mi"
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "150M"]
EOF'

wait
p ""
pei "oc get pods -n $PROJECT"
p ""

p "# Describe the requests/limits on the application"
pei "oc get pod -l app=stress -o yaml | grep -e limit -e requests -A1"
p ""

p "# VPA will use the metrics to adapt the application resources, let's check them"
wait
# NOTE: metrics will take at least 20 sec to show on the following output, adapt the demo explanation taking this in consideration (f. ex: explaining above objects and talking about requests/limits)

pei "oc adm top pod --namespace=$PROJECT --use-protocol-buffers"
p ""

p "# VPA can include max/mins to encapsulate resource requests and limits"
pei "cat <<EOF | oc -n $PROJECT apply -f -
apiVersion: 'autoscaling.k8s.io/v1'
kind: VerticalPodAutoscaler
metadata:
  name: stress-vpa
spec:
  targetRef:
    apiVersion: 'apps/v1'
    kind: Deployment
    name: stress
  resourcePolicy:
    containerPolicies:
      - containerName: '*'
        minAllowed:
          cpu: 100m
          memory: 50Mi
        maxAllowed:
          cpu: 1000m
          memory: 1024Mi
        controlledResources: ['cpu', 'memory']
EOF"
p ""

p "# Check the vpa status"
wait
p "oc get vpa -n $PROJECT"
p "oc get vpa stress-vpa -o jsonpath='{.status}' | jq -r ."


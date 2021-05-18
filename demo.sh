# ArgoCD Cluster IP
kubectl get svc/argocd-server -n argocd -ojson | jq .spec.clusterIP

# Port forward ArgoCD load balancer
kubectl port-forward svc/argocd-server -n argocd 8090:443

# Port forward Tekton Dashboard so that its available at
# http://localhost:8001/api/v1/namespaces/tekton-pipelines/services/tekton-dashboard:http/proxy
kubectl proxy

# Create namespace cdcon
kubectl create namespace cdcon

# Create ArgoCD secret and Service Account
kubectl apply -n cdcon -f pipeline/argocdsecret.yaml
kubectl apply -n cdcon -f pipeline/service-account.yaml

# ArgoCD is available at
https://localhost:8090/

# Create ArgoCD app to sync Tekton Pipeline
argocd app create cdcon-app-build --repo https://github.com/pritidesai/cdCon2021 --path pipeline --dest-name docker-desktop --dest-namespace cdcon

# Sync Tekton Pipeline
argocd app sync cdcon-app-build

# Create ArgoCD app to sync Deployment
argocd app create cdcon-app-deploy --repo https://github.com/pritidesai/cdCon2021 --path deployment --dest-name docker-desktop --dest-namespace cdcon

# No sync here since the app image is not available yet

# Port forward Tekton Event Listener
kubectl port-forward  svc/el-cdcon-el -n cdcon 8080

# expose event listener so that the GitHub webhook can deliver the JSON payload
~/Downloads/ngrok http 8080

# Setup GitHub webhook

# Change the application in Github and commit changes which will activate the trigger and pipelineRun must start

# Confirm the PipelineRun started

# Access the application at
http://localhost:32426/





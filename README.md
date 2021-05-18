# Build, publish, and deploy using Tekton and ArgoCD

This repository contains a simple application that uses [ArgoCD](https://argoproj.github.io/argo-cd/) to deploy its
[Tekton pipeline](https://github.com/tektoncd/pipeline) to [Docker Desktop](https://docs.docker.com/desktop/kubernetes/).
It uses Tekton to build an image and publish it to the Container Registry after a developer commits changes to the
application. And it executes an ArgoCD sync to deploy the application.

### Run Sample Application and Test Locally with Docker

The sample application is created following this [tutorial](https://nodejs.org/fr/docs/guides/nodejs-docker-webapp/)
simulating how a new user might learn to containerize a Node Application.

1. To run the application locally, [Install Docker Desktop](https://www.docker.com/products/docker-desktop).

2. We can run the application locally if we have [node](https://nodejs.org/en/) installed

```shell
cd cdCon2021/
npm install
node server.js
```

3. Since we have the code, docker build with a tag

```shell
docker build -t <your username>/cdcon2021 .
```

4. Run the application in a container.

```shell
docker run -p 49162:8082 -d <your username>/cdcon2021
```

5. Check that the container is running.

```shell
docker ps
```

6. Test the Application

```shell
curl -i localhost:49162
```

### Pre-requisites

To complete this tutorial, we need:

* [Docker Desktop with Kubernetes](https://docs.docker.com/desktop/kubernetes/)
* [ArgoCD](https://argoproj.github.io/argo-cd/cli_installation/)
* [Tekton Pipelines](https://github.com/tektoncd/pipeline)
* [Tekton Triggers](https://github.com/tektoncd/triggers)
* [Tekton Dashboard](https://github.com/tektoncd/dashboard)

### Install ArgoCD

Install ArgoCD

```shell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Download ArgoCD CLI

```shell
brew install argocd
```

Change the argocd-server service type to LoadBalancer:

```shell
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

Kubectl port-forwarding can also be used to connect to the API server without exposing the service.

```shell
kubectl port-forward svc/argocd-server -n argocd 8090:443
```

The API server can then be accessed using the http://localhost:8090

Login Using the CLI, using the username `admin` and the password from below:

```shell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Change the password using the command:

```shell
argocd login localhost:8090
argocd account update-password
```

Register a cluster `docker-desktop` to deploy apps to

```shell
argocd cluster add docker-desktop
```

### Install Tekton Pipelines

```shell
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.24.1/release.yaml
```

### Install Tekton Triggers

```shell
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
```

### Install Tekton Dashboard

```shell
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml
```

The Dashboard can be accessed through its ClusterIP Service by running kubectl proxy. Assuming `tekton-pipelines` is the installed namespace for the Dashboard, run the following command:

```shell
kubectl proxy
```

Browse http://localhost:8001/api/v1/namespaces/tekton-pipelines/services/tekton-dashboard:http/proxy/ to access your Dashboard.

### Create Namespace

```shell
kubectl create namespace cdcon
```

### Install the Argo CD Tekton Task into the `argocd` namespace

After Tekton builds the application and pushes the container image into the Image Repository, Tekton needs to trigger a
new Deployment. There is a special task that allows Tekton to trigger a ArgoCD sync. We have to install the [Argo CD Tekton Task](https://github.com/tektoncd/catalog/tree/main/task/argocd-task-sync-and-wait/0.1) for that.


```shell
kubectl apply -n cdcon -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/argocd-task-sync-and-wait/0.1/argocd-task-sync-and-wait.yaml
```

### Update ArgoCD secret

There is a file called `argocdsecret.template` which contains

* `argocd-env-configmap`: `ConfigMap` with `ARGOCD_SERVER` used for server address
* `argocd-env-secret`: `Secret` with `ARGOCD_USER` and `ARGOCD_PASSWORD` used for authentication

Create a copy of that file as yaml.

```shell
cd pipeline/
cp argocdsecret.template  argocdsecret.yaml
```

In the newly created file, replace the value for `ARGOCD_SERVER` (`localhost:8090`) with the ArgoCD server,
`ARGOCD_USERNAME` with the username and `ARGOCD_PASSWORD` with the Base 64 encoded password.

### Update ServiceAccount secret

There is a file called `serviceaccount.template` which contains

* `dockerhub-user-pass`: `Secret` with `${DOCKER_USERNAME}` and `${DOCKER_PASSWORD}` used for authentication
* `cdcon-app-builder`: `ServiceAccount` using the secret `dockerhub-user-pass`

Create a copy of that file as yaml.

```shell
cd pipeline/
cp serviceaccount.template  serviceaccount.yaml
```

In the newly created file, replace the value for `DOCKER_USERNAME` and `DOCKER_PASSWORD` with your docker credentials.

### What's inside Pipeline?

* [pipeline-resources.yaml](pipeline/pipeline-resources.yaml):
  [Pipeline Resources](https://github.com/tektoncd/pipeline/blob/main/docs/resources.md) are configured for the
  pipeline. We will create two resources (`git` and `image`), which will need the name of the git repository, and the
  name of the Container Image using the Docker Hub.  Note, the resources here allow us to run a Pipeline from the Tekton
  Dashboard or CLI. It hard codes default values. They will be overridden by Trigger Template when builds are done via a
  git push.


* [pipeline.yaml](pipeline/pipeline.yaml): Our [Pipeline](https://github.com/tektoncd/pipeline/blob/main/docs/pipelines.md)
  for building, publishing, and deploying our application. There are two
  [Tasks](https://github.com/tektoncd/pipeline/blob/main/docs/tasks.md). We make use of the shared tasks rather than
  creating our own. Tasks:

    - the `build-and-publish-image` uses Kaniko to build an image.
    - the `argocd-sync-deployment` uses the ArgoCD task we installed earlier.


* [triggertemplate.yaml](pipeline/triggertemplate.yaml):  Now that the pipeline is setup, there are several resources
  created in this file.  This file creates the needed resources for triggering builds from an external source,
  in our case a Git webhook. We can learn more about Tekton Triggers [here](https://github.com/tektoncd/triggers).
  We have created the following.

    - A TriggerTemplate is used to create a template of the same pipeline resources, but dynamically generated to not
      hard code image name or source. It also creates a PipelineRun Template that will be created when a build is triggered.

    - A TriggerBinding that binds the incoming event data to the template (this will populate things like git repo name,
      revision, etc)

    - An EventListener that will create a pod application bringing together a binding and a template.

### Create and configure ArgoCD App for Tekton Pipeline

We can use ArgoCD to deploy the Tekton build for the application.

```shell
argocd app create cdcon-app-build --repo https://github.com/pritidesai/cdCon2021 --path pipeline --dest-name docker-desktop --dest-namespace cdcon
```

Once you run sync, your pipeline should be deployed, and your screen in ArgoCD should look like below.

```shell
argocd app sync cdcon-app-build
```

![alt argo-pipeline](images/argocd-tekton-pipeline.png)

```shell
kubectl get eventlistener -n cdcon
NAME       ADDRESS                                           AVAILABLE   REASON                     READY   REASON
cdcon-el   http://el-cdcon-el.cdcon.svc.cluster.local:8080   True        MinimumReplicasAvailable
```

```shell
kubectl port-forward  svc/el-cdcon-el -n cdcon 8080
```

### What's inside Deployment?

* [deployment.yaml](deployment/deployment.yaml) - This represents our Kubernetes Deployment.

* [service.yaml](deployment/service.yaml):  This expose the sample application to the cluster.

### Create ArgoCD App for Web App Resources

Just like we used ArgoCD to deploy the `tekton` pipeline, we will create another ArgoCD app that corresponds to the
deployment.

```shell
argocd app create cdcon-app-deploy --repo https://github.com/pritidesai/cdCon2021 --path deployment --dest-name docker-desktop --dest-namespace cdcon
```
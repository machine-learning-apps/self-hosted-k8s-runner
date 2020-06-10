![](https://github.com/machine-learning-apps/self-hosted-k8s-runner/workflows/Update-Image/badge.svg)

# Create A Self-Hosted Actions Runner On Your Kubernetes Cluster

<!-- vscode-markdown-toc -->
* 1. [Why?](#Why)
* 2. [Customize Your Self Hosted Runner (Optional)](#CustomizeYourSelfHostedRunnerOptional)
* 3. [Install `envsubst`](#Installenvsubst)
* 4. [Setup Your K8s Cluster For Actions](#SetupYourK8sClusterForActions)
* 5. [Deploy A Self Hosted Runner](#DeployASelfHostedRunner)
	* 5.1. [Set Environment Variables](#SetEnvironmentVariables)
		* 5.1.1. [Required Varaibles](#RequiredVaraibles)
		* 5.1.2. [Optional Variables](#OptionalVariables)
	* 5.2. [Deploy Self Hosted Runner](#DeploySelfHostedRunner)
* 6. [Delete An Actions Runner](#DeleteAnActionsRunner)

<!-- vscode-markdown-toc-config
	numbering=true
	autoSave=true
	/vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->


##  1. <a name='Why'></a>Why?

[GitHub Actions](https://github.com/features/actions) allow you to use [self hosted runners](https://help.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners).  From the docs:

> Self-hosted runners offer more control of hardware, operating system, and software tools than GitHub-hosted runners provide. With self-hosted runners, you can choose to create a custom hardware configuration with more processing power or memory to run larger jobs, install software available on your local network, and choose an operating system not offered by GitHub-hosted runners. Self-hosted runners can be physical, virtual, in a container, on-premises, or in a cloud.

This repository shows **how to run a self hosted runner in a Kubernetes cluster**, which is useful if your Actions runner needs to create resources or update deployments.  This is also helpful for integration with cloud-native machine learning pipelines with projects like [Kubeflow](https://www.kubeflow.org/) or [Argo](https://argoproj.github.io/).  

This project inherits from [github/self-hosted-runners-anthos](https://github.com/github-developer/self-hosted-runners-anthos).  We use docker-in-docker in order to accomplish instantiation of a self-hosted runner on kubernetes.

___

##  2. <a name='CustomizeYourSelfHostedRunnerOptional'></a>Customize Your Self Hosted Runner (Optional)

**Note: you only need to do this if you wish to customize your Actions runner.  Otherwhise, you can proceed to step 2**. I 

**We have a pre-built Docker image hosted at [github/k8s-actions-runner](https://hub.docker.com/r/github/k8s-actions-runner)**, with the following additional dependencies installed:

- [gettext-base](https://www.gnu.org/software/gettext/) for [envsubst](https://manpages.debian.org/stretch/gettext-base/envsubst.1.en.html)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)
- [Argo CLI](https://github.com/argoproj/argo/releases)

This image is [tagged](https://hub.docker.com/r/github/k8s-actions-runner/tags) with the version of the [actions/runner release](https://github.com/actions/runner/releases/).  For example, the image ` github/k8s-actions-runner:2.263.0` corresponds to the [actions/runner v2.263.0 release](https://github.com/actions/runner/releases/tag/v2.263.0).

If you wish to customize the Actions runner with additional dependencies you can edit the [Dockerfile](./Dockerfile).  If you customize the docker image, you need to build and push the container to your Docker repository.

```bash
# Refresh Docker Image
docker build -t $ACTIONS_IMAGE_NAME . 
docker push $ACTIONS_IMAGE_NAME
```
___

##  3. <a name='Installenvsubst'></a>Install `envsubst`

You will need a cli tool called `envsubst`.  You can [install envsubst](https://command-not-found.com/envsubst) like this:

- on mac: `brew install gettext`
- on ubuntu: `apt-get install gettext-base`

##  4. <a name='SetupYourK8sClusterForActions'></a>Setup Your K8s Cluster For Actions

We will use a namespace called `actions` throughout this tutorial.  If you don't have this namespace, you can create it with `kubectl create namespace actions`. **Note: you only need to do this once per cluster**

1. Create a namespace called `actions` if it does not exist.  You can list your available namespaces with `kubectl get namespaces`.  You can create this namespace with `kubectl create namespace actions`.

2. Create a [Personal Access Token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line). From the [documentation](https://developer.github.com/v3/actions/self_hosted_runners/), "Access tokens require repo scope for private repos and public_repo scope for public repos".  **Note: you should only have to do this once per cluster.  You should use a service account, not a personal account as this will be used to register your runner with your repositories.**  Store your PAT in an enviornment variable named `ACTIONS_PAT`.  You can do this in the terminal like so:

    > export ACTIONS_PAT={YOUR_PAT}

3. Apply these secrets to your K8s cluster, along with role bindings to the `actions` namespace:

    > envsubst "\$ACTIONS_PAT" < k8s_setup/authorize.yml | kubectl -n actions apply -f -


##  5. <a name='DeployASelfHostedRunner'></a>Deploy A Self Hosted Runner
 

###  5.1. <a name='SetEnvironmentVariables'></a>Set Environment Variables

You must set the below variables before deploying your self-hosted Actions runner:

####  5.1.1. <a name='RequiredVaraibles'></a>Required Varaibles

- `ACTIONS_GITHUB_REPO`: 
  - this is the GitHub repository in the form of orginization/repository.  For example, a valid value is `github/semantic` which refers to [this repo](https://github.com/github/semantic).

####  5.1.2. <a name='OptionalVariables'></a>Optional Variables
- `ACTIONS_IMAGE_NAME`: (optional)
  - the Docker Image that references the location of the image of your self-hosted runner.  If this is a private repository, your k8s cluster must have the ability to pull from this registry.  Furthermore, if your private registry requires a login, you may have to modify [deployment.yml](./deployment.yml) to include an [ImagePullSecret](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/), which is outside the scope of this tutorial.  If no value is specified, this defaults to `github/k8s-actions-runner:latest`
- `ACTIONS_DEPLOY_NAME`: (optional) 
  - you can name this anything you want, you need a unique name for each repo.  If this is not specified the execution script will set this to `actions-runner-$ACTIONS_GITHUB_REPO`, with the forward slash `/` replaced with a dash `-`.

You can set your environment variables in the terminal like this:

```bash
# example: "github/semantic"
export ACTIONS_GITHUB_REPO={Your_Org}/{Your Repo}

# example: "github/k8s-actions-runner:2.263.0"
export ACTIONS_IMAGE_NAME={Your Image Name}
```

###  5.2. <a name='DeploySelfHostedRunner'></a>Deploy Self Hosted Runner

Run this from the terminal:

> ./deploy_runner/deploy.sh

You can check the status of your runner with

> kubectl -n actions get deployment

___

##  6. <a name='DeleteAnActionsRunner'></a>Delete An Actions Runner

1. See your runners, take note of the deployment names you want to shut down.

> kubectl -n actions get deploy

2. Delete the specific deployment(s)

> kubectl -n actions delete <deployment_name>

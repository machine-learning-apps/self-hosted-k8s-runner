![](https://github.com/machine-learning-apps/self-hosted-k8s-runner/workflows/Update-Image/badge.svg) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

# Create A Self-Hosted Actions Runner On Your Kubernetes Cluster

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Create A Self-Hosted Actions Runner On Your Kubernetes Cluster](#create-a-self-hosted-actions-runner-on-your-kubernetes-cluster)
- [Motivation](#motivation)
- [Optional: Customize Your Self Hosted Runner](#optional-customize-your-self-hosted-runner)
- [Refresh Docker Image](#refresh-docker-image)
- [Setup Instructions](#setup-instructions)
	- [1. Install `envsubst`](#1-install-envsubst)
	- [2. Setup Your K8s Cluster For Actions](#2-setup-your-k8s-cluster-for-actions)
	- [3. Deploy A Self Hosted Runner](#3-deploy-a-self-hosted-runner)
		- [3.1. Set Environment Variables](#31-set-environment-variables)
			- [3.1.1. Required Varaibles](#311-required-varaibles)
			- [3.1.2. Optional Variables](#312-optional-variables)
		- [3.2. Deploy](#32-deploy)
	- [Delete An Actions Runner](#delete-an-actions-runner)

<!-- /TOC -->

# Motivation

[GitHub Actions](https://github.com/features/actions) allow you to use [self hosted runners](https://help.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners).  From the docs:

> Self-hosted runners offer more control of hardware, operating system, and software tools than GitHub-hosted runners provide. With self-hosted runners, you can choose to create a custom hardware configuration with more processing power or memory to run larger jobs, install software available on your local network, and choose an operating system not offered by GitHub-hosted runners. Self-hosted runners can be physical, virtual, in a container, on-premises, or in a cloud.

This repository shows **how to run a self hosted runner in a Kubernetes cluster**, which is useful if your Actions runner needs to create resources or update deployments.  This is also helpful for integration with cloud-native machine learning pipelines with projects like [Kubeflow](https://www.kubeflow.org/) or [Argo](https://argoproj.github.io/).  

This project builds upon [github-developer/self-hosted-runners-anthos](https://github.com/github-developer/self-hosted-runners-anthos).  We use docker-in-docker in order to accomplish instantiation of a self-hosted runner on kubernetes.

___

# Optional: Customize Your Self Hosted Runner

**Note: you only need to do this if you wish to customize your Actions runner.  Otherwhise, you can proceed to step 2**. I

**We have a pre-built Docker image hosted at [github/k8s-actions-runner](https://hub.docker.com/r/github/k8s-actions-runner)**, with the following additional dependencies installed:

- [gettext-base](https://www.gnu.org/software/gettext/) for [envsubst](https://manpages.debian.org/stretch/gettext-base/envsubst.1.en.html)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)
- [Argo CLI](https://github.com/argoproj/argo/releases)

This image is [tagged](https://hub.docker.com/r/github/k8s-actions-runner/tags) with the version of the [actions/runner release](https://github.com/actions/runner/releases/).  For example, the image ` github/k8s-actions-runner:2.263.0` corresponds to the [actions/runner v2.263.0 release](https://github.com/actions/runner/releases/tag/v2.263.0).

If you wish to customize the Actions runner with additional dependencies you can edit the [Dockerfile](./Dockerfile).  If you customize the docker image, you need to build and push the container to your Docker repository.

```bash
# Build Docker Image For Custom Runner (Optional)
export ACTIONS_IMAGE_NAME="your_docker_repo/your_image_name"
docker build -t $ACTIONS_IMAGE_NAME .
docker push $ACTIONS_IMAGE_NAME
```
___

# Setup Instructions

##  1. Install `envsubst`

You will need a cli tool called `envsubst`.  You can [install envsubst](https://command-not-found.com/envsubst) like this:

- on mac: `brew install gettext`
- on ubuntu: `apt-get install gettext-base`

##  2. Setup Your K8s Cluster For Actions

:alert: **If you are sharing a cluster with others that have already setup a self-hosted Actions runner you can probably skip this step.**

The scripts in this repo will use a k8s namespace called `actions`.  If this namespace is not available it will be created for you.

1. Create a [Personal Access Token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line). From the [documentation](https://developer.github.com/v3/actions/self_hosted_runners/), "Access tokens require repo scope for private repos and public_repo scope for public repos".  **You should use a service account, not a personal account as this will be used to register your runner with your repositories.  Finally, you should only do this if you are confident that your kubernetes cluster is secure as anyone with access to your cluster will be able to obtain this token.**  

Store your PAT in an enviornment variable named `ACTIONS_PAT`.  You can do this in the terminal like so:

    > export ACTIONS_PAT={YOUR_PAT}

2. Store these secrets to your K8s cluster, along with role bindings to the `actions` namespace:

    > ./k8s_setup/setup.sh


    By default, this script will not update secrets for self-hosted runners if one already exists in your cluster.  You can override this with a `--force-update` flag:

    > ./k8s_setup/setup.sh --force-update

##  3. Deploy A Self Hosted Runner For A GitHub Repo

You must perform the below steps for each repository you want to bind self-hosted runners to.  While it is possible to create [a self-hosted runner for an organization](https://github.blog/changelog/2020-04-22-github-actions-organization-level-self-hosted-runners/), the tools in this repo currently only support repo-level self hosted runners.  

###  3.1. Set Environment Variables

You must set the below variables before deploying your self-hosted Actions runner:

####  3.1.1. Required Varaibles

- `ACTIONS_GITHUB_REPO`:
  - this is the GitHub repository in the form of orginization/repository.  For example, a valid value is `github/semantic` which refers to [this repo](https://github.com/github/semantic).

####  3.1.2. Optional Variables
- `ACTIONS_IMAGE_NAME`: (optional)
  - the Docker Image that references the location of the image of your self-hosted runner.  If this is a private repository, your k8s cluster must have the ability to pull from this registry.  Furthermore, if your private registry requires a login, you may have to modify [deployment.yml](./deploy_runner/deployment.yml) to include an [ImagePullSecret](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/), which is outside the scope of this tutorial.  If no value is specified, this defaults to `github/k8s-actions-runner:latest`
- `ACTIONS_DEPLOY_NAME`: (optional)
  - you can name this anything you want, you need a unique name for each repo.  If this is not specified the execution script will set this to `actions-runner-$ACTIONS_GITHUB_REPO`, with the forward slash `/` replaced with a dash `-`.

You can set your environment variables in the terminal like this:

```bash
export ACTIONS_GITHUB_REPO={Your_Org}/{Your Repo} # ex: "github/semantic"
export ACTIONS_IMAGE_NAME={Your Image Name} # ex: "github/k8s-actions-runner:2.263.0"
```

###  3.2. Deploy

Run this from the terminal:

> ./deploy_runner/deploy.sh

You can check the status of your runner with

> kubectl -n actions get deployment

___

##  Delete An Actions Runner

1. To see your runners, take note of the deployment names you want to shut down.

> kubectl -n actions get deploy

2. Delete the specific deployment(s)

> kubectl -n actions delete <deployment_name>

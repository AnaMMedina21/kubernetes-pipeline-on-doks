# Kubernetes Scaffolding Script

This project has been derivated from [this Github repo](https://github.com/DefrostedTuna/kubernetes-scaffolding). Many thanks to [Rick Bennett @ Github/DefrostedTuna](https://github.com/DefrostedTuna). 

This project takes a few deviations:

- Instead of a separate DNS and load balancer a single DNA A record such as *.yourdom.com points to a single load balancer that delegates to the NGINX ingress controller then to the ingressed services such as Jenkins and Harbor. 
- Script goal is to run on pure Linux, without dependencies on Brew. Local CLI tools (doctl, helm and kubectl) are more assumed as a prerequisite than something to provision locally.
- The Jenkins and Harbor versions and associated plugin have been updated to the latest versions.
- The Helm provisioning was missing an important `helm repo update`.
- Changed some messaging and added spinner for those blocking moments.
- Other minor changes [noted in this change set](https://github.com/DefrostedTuna/kubernetes-scaffolding/pull/1).

At some point this script might run more independently in a container. Converting to Anisible may also be a good leap forward.

Below is the unmodified readme from the original project.

----------------
## What is this?

While experimenting with Kubernetes on DigitalOcean, I found myself spinning up clusters fairly often to try new things. I got very familiar with the process of doing this and decided to [write a guide](https://gist.github.com/DefrostedTuna/1cf0367b3b121d82a0591e177d6887b8) covering how to set up a barebones cluster, along with common tools that I personally use. This bash script project is an extension of that guide, automating the process of setting up a cluster on DigitalOcean and installing a subset of software to get fresh cluster up and running quickly.

## What are the requirements?

* MacOS Mojave (Untested on other Unix based systems, or other versions of MacOS)
* Homebrew
* Kubectl
* Helm
* Doctl

## What does it install and configure?

The script will first and foremost check for the proper dependencies. These dependencies include:

* Homebrew
* Kubectl
* Helm
* Doctl

If these dependencies are not found on the system, the script will attempt to install them for you.

**Note:** The Homebrew installation may take a considerable amount of time if the X Code Development Tools are not found on your system.

Once these dependencies are present the script will configure the following:

* Creating a Kubernetes cluster on DigitalOcean
* Copying a kubeconfig file to your local machine (If opted against creating a cluster)
* Initializing Helm/Tiller
* Installing an Nginx Ingress
* Installing Cert Manager
* Installing and configuring Jenkins
* Installing and configuring Harbor
* Installing Kubernetes Dashboard

**Note:** Setting up the Ingress *WILL* configure a DigitalOcean Load Balancer. This is a service that DigitalOcean charges for, so keep that in mind.

A miminimum of two 8 GB Memory / 4 vCPUs droplets (=4 K8s Worker Nodes) is recommended if you answer yes to many of the questions to install packages.

## How do I use this script?

Clone the repository onto your local machine.

```
git clone https://github.com/DefrostedTuna/kubernetes-scaffolding.git && cd kubernetes-scaffolding
```

Make the script executable.

```
chmod +x init-cluster.sh && chmod -R +x scripts
```

Run the script.

```
./init-cluster.sh
```

The script will guide you through the setup process, prompting for input when necessary. Follow the instructions in the script and you'll be good to go!

## Cluster Removal

There are instructions [here](https://www.digitalocean.com/docs/kubernetes/how-to/delete-clusters/) on how to remove the cluster an associated resources. A cluster can also be removed with doctl, see `doctl kubernetes cluster delete <cluster-name>`. After this be sure to remove any associated DNS records, load balancers and volumes associated with this removed cluster. Caution: In most cases your volumes may contain data and you probably want to leave the volumes intact.
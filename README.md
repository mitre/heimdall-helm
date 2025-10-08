# heimdall2-helm

A helm chart for Heimdall2 project found at [https://github.com/mitre/heimdall2](https://github.com/mitre/heimdall2).

## Requirements

Written for Helm 3.

## Example use

You can clone this repo, enter the repository folder and then execute something like the [start_heimdall2.sh](start_heimdall2.sh):

```
./start_heimdall2.sh
```

The script will spin up Heimdall2 using the example [values.yaml](heimdall2/values.yaml) values file.  You will need
to provide your own if you want to configure other settings, and ingress, etc.  Look at the [values.yaml](heimdall2/values.yaml)
file for what to place in your own.

To generate the postgres user's password consider using

```bash
openssl rand -hex 33
```

And to to generate a value for JWS_SECRET consider using

```bash
openssl rand -hex 64
```

The start_heimdall.sh script generates some of these values for you, and demonstrates how to pass in values from the cli instead of using the values.yaml file via the `--set` flag.

## To install via MITRE chart repository

```
helm repo add heimdall2-helm https://mitre.github.io/heimdall2-helm/
helm repo update
helm search repo heimdall2
wget https://raw.githubusercontent.com/mitre/heimdall2-helm/main/values.yaml
vi values.yaml # configure values.yaml for your organization
helm install heimdall heimdall2-helm/heimdall --namespace heimdall --create-namespace -f values.yaml
watch -n 15 kubectl get pods -n heimdall
```

Give it time for Heimdall2 to come fully up.  It has to "migrate" data, and the frontend site needs to build. It takes a few minutes.

## Accessing Heimdall2

If you've spun up Heimdall2 using the [start_heimdall2.sh](start_heimdall2.sh) script, you can access it in your
browser via exposing via `kubectl port-forward` like so

```
kubectl port-forward -n heimdall service/heimdall 8081:3000
```

then open in your browser [http://localhost:8081](http://localhost:8081)

Or configure an ingress via your values file by adding an `ingress` configuration under
`heimdall` in your values file likes so:

```
heimdall:
  ingress:
    enabled: true
    annotations:
      traefik.ingress.kubernetes.io/router.entrypoints: web
    hosts:
      - host: heimdall.example.com
        paths:
          -  "/"
    tls: []
```

This example uses Traefik to expose the ingress.  Configuring Traefik is out of scope of this 
readme.

## SOPS
You have the choice of secret handling within this repo, either internally or using SOPS encryption.

Using SOPS, the secrets are encrypted and are exposed via a Secret resource in a separate pod.

If you do not wish to use SOPS encryption, the secrets can be kept in plain text in the values.yml file where they will be injected into the internally defined Secret resource.

There should only be the one Secret resource. Please ensure that if you are enabling SOPS, that the SOPS Secret has the equivalent name as the template for "heimdall.fullname" (which by default is "heimdall2") and it is in the same namespace as the Heimdall application.

## How to use SOPS

### Install Kustomize

https://github.com/kubernetes-sigs/kustomize

### Install the SOPS application

https://github.com/getsops/sops?tab=readme-ov-file#usage

### Create SOPS config (AWS KMS Example)

```
cat <<EOF > .sops.yaml
creation_rules:
- path_regex: ./sops/.*
  kms: arn:
EOF
```

### Create the sops file using your default editor.

```
sops sops/sops-secrets.enc.yaml
```

### Specify the secrets you want encrypted

```
adminPassword: <your-password>
... other secrets ...
```

### Modify the secrets-generator.yml to have the correct Secret name and namespace

## Author Information

* Michael Joseph Walsh <mjwalsh@nemonik.com>
* MITRE SAF team <saf@mitre.org>

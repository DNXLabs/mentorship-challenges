# Cloud Native Workspace

> **A ready‑to‑use development environment packed with AWS, Docker, Kubernetes, Terraform, Node.js, Python and more – delivered via Dev Containers.**

---

## Table of Contents

1. [Features](#features)
2. [Getting Started](#getting-started)

   1. [Prerequisites](#prerequisites)
   2. [Quick start with VS Code](#quick-start-with-vs-code)
   3. [Running with GitHub Codespaces](#running-with-github-codespaces)
   4. [Using the Dev Container CLI](#using-the-dev-container-cli)
3. [Included Tools](#included-tools)
4. [Customising Your Workspace](#customising-your-workspace)
5. [Tips & Tricks](#tips--tricks)
6. [Contributing](#contributing)
7. [License](#license)

---

## Features

* **Ubuntu 22.04** base image (`devcontainers/base:jammy`).
* Pre‑installed CLI tools:

  * **AWS CLI v2**
  * **Amazon Q CLI** (installed post‑create and aliased to `q`, giving ChatGPT‑style help for AWS development.)
  * **Docker‑in‑Docker** runtime
  * `kubectl`, **Helm** & **Minikube**
  * **Node.js** LTS + npm
  * **Python 3** + pip
  * **Terraform**
  * **AWS CDK**
  * `jq`, `yq`, `gron` and other JSON/YAML processors
  * `curl`, `wget`, **GitHub CLI**
* Automatic binding of your `~/.ssh` keys for seamless Git access.
* Works locally with VS Code or remotely in **GitHub Codespaces**.
* Ready for CI pre‑building via the `devcontainer build` command.

---

## Getting Started

### Clone the repository

```bash
git clone https://github.com/DNXLabs/cloud-native-workspace.git
cd cloud-native-workspace
```

### Prerequisites

| Local workflow                                                                                                                                                                                                                                                                  | Remote workflow                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| • [Docker Desktop](https://www.docker.com/products/docker-desktop/) *(or any Docker daemon)*<br>• [Visual Studio Code](https://code.visualstudio.com/) <br>• [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) | • A GitHub account with **Codespaces** enabled |

### Quick start with VS Code

1. Open the folder in VS Code.
2. When prompted, click **“Reopen in Container”**. 
   VS Code will build the container and attach to it automatically. The first build takes 2‑4 minutes.
3. Verify the toolchain:

```bash
aws --version
q --help           # Amazon Q
kubectl version --client
terraform version
node -v
python --version
docker version
```

### Running with GitHub Codespaces

1. On the repository page, press **`▷ Code → “Create codespace on main”`**.
2. Wait for the codespace to build and launch VS Code in your browser.
3. Use the integrated terminal as normal – all tools are pre‑installed.

### Using the Dev Container CLI

If you prefer the terminal, you can build and open the workspace with the [Dev Container CLI](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli):

```bash
npm install -g @devcontainers/cli

devcontainer open --workspace-folder .
```

---

## Included Tools

| Feature                 | Version / Notes                                    |
| ----------------------- | -------------------------------------------------- |
| `aws-cli`               | v2                                                 |
| `amazon‑q-cli`          | Installed via post‑create script, invoked with `q` |
| `docker-in-docker`      | Docker 24.x daemon running as rootless             |
| `kubectl-helm-minikube` | `kubectl`, Helm, Minikube                          |
| `node`                  | Latest LTS                                         |
| `python`                | Python 3                                           |
| `terraform`             | Latest                                             |
| `jq-likes`              | `jq`, `yq`, `gron`                                 |
| `aws-cdk`               | CDK v2                                             |
| `gh-cli`                | GitHub CLI                                         |

See [`/.devcontainer/devcontainer.json`](./.devcontainer/devcontainer.json) for the authoritative list.

---

## Customising Your Workspace

* **Add more tools** – edit `.devcontainer/devcontainer.json` and append entries under `"features"`.
* **Add VS Code extensions** – add an array under `"customizations.vscode.extensions"`.
* **Forward ports** – uncomment the `"forwardPorts"` section when required.
* **Run commands after build** – modify `"postCreateCommand"` with shell scripts or commands you want to run on first‑start.

Rebuild the container any time with the command palette → **Dev Containers: Rebuild Container**.

---

## Tips & Tricks

* The **docker‑in‑docker** feature lets you run Docker commands *inside* the dev container, e.g. `docker run hello-world`.
* Your host SSH keys are mounted *read‑only* at `/home/vscode/.ssh` so Git and GitHub CLI work without additional config.
* Need root? Run `sudo -i`. The default user is **vscode**.
* **Amazon Q**: run `q` (or `q chat`) to get AI answers for AWS CLI, CDK, Terraform etc. First run `q login` to authenticate with your AWS builder ID.

---

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

---

## License

Distributed under the **Apache 2.0 License**. See [`LICENSE`](./LICENSE) for more information.

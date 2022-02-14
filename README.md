# datascience-docker
Docker image to set up a complete data science environment on a virtual server (running [caprover](https://caprover.com/)).

This is still a work in progress. Current status:
* python, rust and kotlin kernels
* conda environment, configurable in [`environment.yml`](https://github.com/potatoTVnet/datascience-docker/blob/main/environment.yml)
* open vscode server as interface, with pre-installed extensions
* git support

instructions for setup using caprover:
* in HTTP Settings:
  * set container port to 3000
  * enable websocket support
* in App Configs
  * set evironment variable `TOKEN`
  * create volume mapping for `/home/jovyan/work/` to have a persistent directory

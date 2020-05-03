[中文版 README](README_zh.md)

# Overview

Docker Swarm is Docker's official cluster orchestration solution. It has been integrated in the docker version> 1.12. Of course, it is not enabled by default. It is a command to enable it. The script mentioned below also supports cluster management operations related to the `docker swarm` command.

Here are some tested containerized service orchestration projects. Docker refers to a group of Services as a stack. So orchestrating a project is to create a Stack containing multiple Services. Services is also a front-end concept abstracted by Docker. The back-end can have multiple Containers to provide actual services to handle front-end requests.

Basically follow the "coding once, run everywhere" advocated by Docker. Veterans familiar with the `docker stack` command can directly access the required YAML files. Relevant notes, if any, will be supplemented with explanations in their corresponding catalogs.

## docker-swarm.sh script

This project provides a shell script that implements common operations through interaction. It is very suitable to quickly experience Docker's official container cluster orchestration solution.


## Compose File format

Yes, orchestration can be arranged based on a Compose file. However, the format versions of Compose files are all above 3.x, which is necessary for deploying containers in Swarm Mode. The change from upgrading to 3.x compared to 2.x is mainly the addition of `deploy:` configuration option.

See detailed service configuration:
https://docs.docker.com/compose/compose-file/compose-versioning/#compatibility-matrix

## Docker Official Document

About `docker stack` command:
https://docs.docker.com/engine/reference/commandline/stack/
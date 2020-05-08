# Quickly experience Docker Swarm

[中文版 README](README_zh.md)



## Overview

Docker Swarm is Docker's official cluster orchestration solution. Compared with Kubernetes, it is very lightweight. Although Kubernetes is currently mainstream, it is also good to know. Swarm has been integrated in the docker version> 1.12. Of course, the default is not enabled, the script mentioned below will automatically detect and confirm that it is enabled.

Docker refers to a set of Services as a stack. So orchestrating a project is to create a Stack containing multiple Services. Services is a front-end concept abstracted by Docker. The back-end can have multiple Tasks (actually Containers) to provide actual services and process requests.

Follow the "coding once, run everywhere" advocated by Docker. Veterans familiar with the `docker stack` command can directly access the required YAML files. Relevant precautions, if any, will be supplemented in the corresponding catalog.

## docker-swarm.sh script

This project provides a shell script that implements common operations through interaction, which means that you can quickly deploy and view logs without checking commands. It is very suitable to quickly experience Docker's official container cluster orchestration solution.

## Compose File format

Yes, it can be arranged based on a Compose file, similar to docker-compose. However, the format versions of Compose files required by Swarm are all above 3.x, which is necessary for deploying Services in Swarm Mode. The change of 3.x compared to 2.x is mainly the addition of `deploy:` configuration options to achieve more deployment requirements.

```
version: "3.8"
services:
  proxy:
    image: nginx
    port:
    - target: 80
      published: 8080
      protocol: tcp
      mode: ingress # host|ingress
    deploy:
      labels:
        app: "proxy"
      resources:
        limits:
          cpus: '0.50'
          memory: 50M
        reservations:
          cpus: '0.25'
          memory: 20M
      mode: replicated
      replicas: 5
      max_replicas_per_node: 2
      update_config:
        parallelism: 2
        delay: 10s
      rollback_config:
        parallelism: 2
        delay: 0s
      restart_policy:
        condition: on-failure
      placement:
        constraints:
          - "node.role==manager"
```

See detailed service configuration:
https://docs.docker.com/compose/compose-file/compose-versioning/#compatibility-matrix

## Docker Official Document Reference

About `docker stack` command:
https://docs.docker.com/engine/reference/commandline/stack/
# 快速体验 Docker Swarm 

[English README](README.md)

## 概述

Docker Swarm 是 Docker 官方的集群编排方案。相比 Kubernetes 非常地轻量，虽然目前 Kubernetes 已是主流，但是了解一下也是不错的。Swarm 已经集成在 > 1.12 的 docker 版本里了。当然默认是未启用状态，下面提到的脚本会自动检测并确认启用的。

Docker 将一组 Services 称之为一个栈 (Stack) 。那么编排一个项目就是创建一个 Stack 包含多个 Services。Services 又是 Docker 抽象出来的一个前端概念，后端可以有多个 Task (实际上就是 Container) 来提供实际的服务，处理请求。

遵循 Docker 倡导的 "编码一次，到处运行"。 熟悉 `docker stack` 命令的老手可以直接取用需要的 YAML 文件。 相关的注意事项，如果有的话，会在其对应的目录内补充说明。

## docker-swarm.sh 脚本

本项目提供了一个 Shell 脚本，通过交互的方式，实现了常用的操作，也就是说不用去查命令就能快速部署，查看日志。用来快速体验 Docker 官方的容器集群编排方案非常合适。

## Compose File 格式

对，还是基于一个 Compose 文件就可以编排部署，类似于 docker-compose 。不过 Swarm 需要的 Compose 文件的格式版本都是 3.x 以上，这是 Swarm Mode 下部署 Services 所必需的。3.x 相比 2.x 的变化主要就是增加了 `deploy:` 配置选项，实现了更多的部署需求。

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

参阅详细的服务配置：
https://docs.docker.com/compose/compose-file/compose-versioning/#compatibility-matrix

## Docker 官方文档参考

关于 `docker stack` 命令:
https://docs.docker.com/engine/reference/commandline/stack/

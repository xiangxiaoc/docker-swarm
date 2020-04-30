# 概述

Docker Swarm 是 Docker 官方的集群编排方案。已经集成在 > 1.12 的 docker 版本里了。当然默认是未启用状态，启用一下也就是一条命令的事，下面提到的脚本也支持与 `docker swarm` 命令相关的集群管理操作。 

这里是一些经过测试的容器化服务编排项目。Docker 将一组 Servives 称之为一个栈 (Stack) 。那么编排一个项目就是创建一个 Stack 包含多个 Services。Services 又是 Docker 抽象出来的一个前端概念，后端可以有多个 Containers 来提供实际的服务处理前端的请求。

基本上是遵循 Docker 倡导的 "编码一次，到处运行"。 熟悉 `docker stack` 命令的老手可以直接取用需要的 YAML 文件。 相关的注意事项，如果有的话，会在其对应的目录内补充说明。

## docker-swarm.sh 脚本

本项目提供了一个 Shell 脚本，通过交互的方式，实现了常用的操作。用来快速体验 Docker 官方的容器集群编排方案非常合适。


## Compose File 格式

对，还是基于一个 Compose 文件就可以编排部署。不过 Compose 文件的格式版本都是 3.x 以上，这是 Swarm Mode 下部署容器所必需的。升级到 3.x 相比 2.x 的变化主要就是增加了 `deploy:` 配置选项。

参阅详细的服务配置：
https://docs.docker.com/compose/compose-file/compose-versioning/#compatibility-matrix

## 小贴士

中国区 registry mirror https://registry.docker-cn.com

#!/bin/bash

# docker swarm management script

#########################
# Script Initialization #
#########################

SCRIPT_VERSION='v1'
SCRIPT_UPDATE_DATE='2020-3-11'
SCRIPT_UPDATE_TIME='22:03'
SCRIPT_UPDATE_TZ='UTC+8'

# File and Directory Path
SCRIPT_RELATIVE_PATH=$0
SCRIPT_DIR_RELATIVE_PATH=$(dirname "$SCRIPT_RELATIVE_PATH")
cd "$SCRIPT_DIR_RELATIVE_PATH" || exit 0
SCRIPT_DIR_ABSOLUTE_PATH=$(pwd)
SCRIPT_FILENAME=${SCRIPT_RELATIVE_PATH##*/}
SCRIPT_ABSOLUTE_PATH=${SCRIPT_DIR_ABSOLUTE_PATH}/${SCRIPT_FILENAME}
LOG_ABSOLUTE_PATH="${SCRIPT_ABSOLUTE_PATH}.log"

# Output Color
#CR='\e[0;31m'
FR='\e[5;31m'
CG='\e[0;32m'
#CY='\e[0;33m'
STYLE_TITLE='\e[4;36m'
RC='\e[0m'

# Format Output

function output_title() {
    local title_name=$1
    echo -e "$STYLE_TITLE$title_name\n$RC"
}

########################
# Script Configuration #
########################

CONFIG_FILE=$SCRIPT_FILENAME.conf

function parse_config_file() {
    local field=$1
    value=$(sed "/^$field=/!d;s/.*=//" "$CONFIG_FILE")
    eval echo "$value"
}

docker_host_ip=$(parse_config_file docker_host_ip)
[ -z "$docker_host_ip" ] && docker_remote_arg="" || docker_remote_arg="-H ${docker_host_ip}:2375"
[ -z "$docker_host_ip" ] && docker_host_display="localhost(/var/run/docker.sock)" || docker_host_display="${docker_host_ip}:2375"
# docker_stack_compose_dir=""
compose_file=$(parse_config_file compose_file)
[ -f "$compose_file" ] && compose_file_display="$compose_file" || compose_file_display="$compose_file $FR(not exist)$RC"
docker_stack_name=$(parse_config_file stack_name)

string_placeholders="#####"

#############
# Pre-check #
#############

[ $UID -ne 0 ] && echo "Only for root" && exit 0

function is_stack_deployed() {
    local input_stack=$1
    stack_list=$(docker -H "$docker_host_ip" stack ls | sed -n '2,$ p' | awk '{print $1}')
    is_deployed="Not deployed"
    for stack in $stack_list; do
        if [ "$stack" == "$input_stack" ]; then
            is_deployed="${CG}Deployed${RC}"
            break
        fi
    done
}

function get_stack_service_num() {
    local input_stack=$1
    is_stack_deployed "$input_stack"
    if [ "$is_deployed" == "Not deployed" ]; then
        echo "0"
    else
        docker -H "$docker_host_ip" stack ls | awk '{if($1=="'"$docker_stack_name"'")print $2}'
    fi
}

###################
# Common Function #
###################

function get_script_version() {
    cat <<EOF_show_version
Version: $SCRIPT_VERSION
Update:  $SCRIPT_UPDATE_DATE $SCRIPT_UPDATE_TIME $SCRIPT_UPDATE_TZ
EOF_show_version
}

function add_date_to_output() {
    while IFS= read -r line; do
        echo "[$(date +'%Y-%m-%d %H:%M:%S.%3N %Z(UTC%:z)')] $line"
    done
}

function locate_function_error() {
    # shellcheck disable=SC2181
    [ $? -ne 0 ] && echo "Function ERROR Located: ${FUNCNAME[1]}. Function list: ${FUNCNAME[*]}" | add_date_to_output >>"${LOG_ABSOLUTE_PATH}" || echo "No ERROR! Function list: ${FUNCNAME[*]}" >/dev/null
}

##################
# Initialization #
##################
function script_init() {
    cat <<EOF_init
$string_placeholders 集群部署脚本 $string_placeholders

初始化设置 ...

EOF_init

    read -r -p "是否改变远程 Docker Host IP 地址？[y/N]:(默认 N) " cho
    if [[ -n $cho ]]; then
        if [ "$cho" = 'y' ] || [ "$cho" = 'Y' ]; then
            read -r -p "输入远程 Docker Host 的 IP 地址（输入空则控制本地 Docker 服务 ）： " docker_host_ip_new
            sed -i "/^docker_host_ip/ c docker_host_ip=\"$docker_host_ip_new\"" "$CONFIG_FILE"
        fi
    fi
    echo

    read -r -p "是否改变集群编排文件名？[y/N]:(默认 N) " cho
    if [[ -n $cho ]]; then
        if [ "$cho" = 'y' ] || [ "$cho" = 'Y' ]; then
            read -r -p "输入集群编排文件名： " docker_stack_compose_file_new
            sed -i "/^docker_stack_compose_file/ c docker_stack_compose_file=\"$docker_stack_compose_file_new\"" "$CONFIG_FILE"
        fi
    fi
    echo

    read -r -p "是否改变服务栈名称？[y/N]:(默认 N) " cho
    if [ -n "$cho" ]; then
        if [ "$cho" = 'y' ] || [ "$cho" = 'Y' ]; then
            read -r -p "输入服务栈名称： " docker_stack_name_new
            sed -i "/^docker_stack_name/ c docker_stack_name=\"$docker_stack_name_new\"" "$CONFIG_FILE"
        fi
    fi
    echo
}

######################
# Docker Stack Entry #
######################
function docker_stack_deploy() {
    echo -e "读取部署编排文件 ./$compose_file \n开始部署服务集群 ... "
    docker "$docker_remote_arg" stack deploy --compose-file "$compose_file" "$docker_stack_name" --resolve-image=never

}

function docker_stack_services() {
    watch -n 1 \
    docker "$docker_remote_arg" stack services "$docker_stack_name" "$@"
}

########################
# Docker Service Entry #
########################
function docker_service_choose() {
    declare -A list
    i=0
    echo -e "序号  服务\n----------"
    for docker_service_name in $(docker "$docker_remote_arg" stack services "$docker_stack_name" | grep -v NAME | awk '{print $2}' | sort -n); do
        i=$((i + 1))
        if [ $i -lt 10 ]; then
            j=' '$i
            echo "$j.   $docker_service_name"
        else
            echo "$i.   $docker_service_name"
        fi
        list[$i]=$docker_service_name
    done
    echo
    read -r -p "选择服务，输入其序号，按回车执行： " cho
    docker_service_choice=${list[$cho]}
    echo
}

function docker_service_ps() {
    case $1 in
    "")
        docker_service_choose
        watch -n 1 \
        docker "$docker_remote_arg" service ps --no-trunc "$docker_service_choice"
        ;;
    "-a")
        watch -n 1 \
        docker "$docker_remote_arg" stack ps --no-trunc "$docker_stack_name"
        ;;
    esac
}

function docker_service_remove() {
    case $1 in
    "")
        docker_service_choose
        echo -e "\n开始移除服务..."
        docker "$docker_remote_arg" service rm "$docker_service_choice"
        ;;
    -a)
        read -r -p "确定移除 $docker_stack_name 服务栈?[y/N]: " cho
        if [ -n "$cho" ]; then
            if [ "$cho" = 'y' ] || [ "$cho" = 'Y' ]; then
                echo -e "\n开始移除服务..."
                docker "$docker_remote_arg" stack rm "$docker_stack_name"
            else
                exit 0
            fi
        else
            exit 233
        fi
        ;;
    esac
    echo "等待 docker 清理服务关联的容器"
    i=0
    printf "[  "
    until [ $i -eq 50 ]; do
        sleep 0.1
        printf "\b"
        printf "="
        printf ">"
        i=$((i + 1))
    done
    echo " ]"
    echo "移除完成"
}

function docker_service_update() {
    docker_service_choose
    echo -e "开始更新服务...\n"
    docker "$docker_remote_arg" service update --force "$docker_service_choice" "$@"
}

function docker_service_logs() {
    docker_service_choose
    read -r -p "要查询多久前到现在日志？  (单位：分钟 默认：全部日志)： " time_to_now
    [ -z "$time_to_now" ] && since_arg="" || since_arg="--since ${time_to_now}m"
    echo
    read -r -p "打印预览或下载到当前目录？  [ 1 预览 | 2 下载 ]（默认：1 预览）： " download_cho
    [ -z "$download_cho" ] && download_cho="1" || download_cho=$download_cho
    echo
    case $download_cho in
    1)
        docker "$docker_remote_arg" service logs -f "$since_arg" "$docker_service_choice"
        ;;
    2)
        if [ -z "${time_to_now}" ]; then
            log_cover_time="all_to_$(date "+%H时%M分%S秒")"
        else
            log_cover_time="$(date -d "-${time_to_now}minutes" "+%m月%d日_%H时%M分%S秒")_to_$(date "+%H时%M分%S秒")"
        fi
        log_filename="${docker_service_choice}_${log_cover_time}.log"
        docker "$docker_remote_arg" service logs "$since_arg" "$docker_service_choice" &>"$log_filename"
        echo "下载完成"
        ;;
    esac
}
#######################
# Docker Config Entry #
#######################
function docker_config() {
    docker "$docker_remote_arg" config "$@"
}

##############
# Help Entry #
##############
function show_help() {
    cat <<EOF_help
Docker stack deploy script , version: 1.3.4 , build: 2018-09-17 16:46:32

Usage: $0 Command [arg]

Commands:

  init              脚本初始化
  save              备份当前编排文件里面用到的镜像
  load [dir_name]   载入 ./images 目录下的镜像 [指定目录]
  port [PORT]       查看对外暴露端口 [指定对外暴露端口 示例：$0 port 51000]
  config            配置管理
  deploy            部署或更新服务栈
  ls                查看各服务概况
  ps [-a]           查看各服务任务状态 [-a 全部服务任务状态]
  rm [-a]           移除中的服务 [-a 全部]
  restart           强制重启服务
  logs              查看服务日志

  -h, --help        显示此帮助页

# 以下是目标 Docker 主机地址和正在使用的编排文件，如需变更执行 $0 init 进行初始化
Docker Daemon: $docker_host_display
Compose File: $compose_file_display
Swarm Stack Name: $docker_stack_name

EOF_help
}

##############
# Main Entry #
##############

function interactive_menu() {
    is_stack_deployed "$docker_stack_name"
    cat <<EOF_menu
$(output_title "Configuration and Status")
Docker Daemon: $docker_host_display
 Compose File: $(echo -e "$compose_file_display")
        Stack: $docker_stack_name(Status: $(echo -e "$is_deployed"); Services: $(get_stack_service_num "$docker_stack_name"))

$(output_title "Available Actions")
0. reconfigure          更改本机或远端的 Docker 服务器或编排组
1. list images          查看 docker daemon 的镜像
2. list stacks          列出所有 stack
3. view logs            查看当前编排组容器日志
4. bash/sh in container 进入容器运行用 bash/sh 进行交互
5. compose up           创建并运行当前编排组
6. compose down         停止并删除当前编排组

EOF_menu
    read -r -p "选择功能，输入其序号: " cho
    case $cho in
    '0') reconfigure ;;
    '1') docker_image_ls ;;
    '2') docker_service_ps ;;
    '3') docker_compose_logs ;;
    '4') docker_compose_bash ;;
    '5') docker_compose_up ;;
    '6') docker_compose_down ;;
    esac
}

function main() {
    main_command=$1
    shift
    case $main_command in
    '')
        interactive_menu
        ;;
    -h)
        show_help
        exit 0
        ;;
    --help)
        show_help
        exit 0
        ;;
    version)
        get_script_version
        ;;
    init)
        script_init
        exit 0
        ;;
    save)
        docker_image_save
        exit 0
        ;;
    load)
        docker_image_load "$@"
        exit 0
        ;;
    port)
        docker_stack_port "$@"
        exit 0
        ;;
    config)
        docker_config "$@"
        exit 0
        ;;
    deploy)
        docker_stack_deploy
        exit 0
        ;;
    ls)
        docker_stack_services "$@"
        exit 0
        ;;
    ps)
        docker_service_ps "$@"
        exit 0
        ;;
    rm)
        docker_service_remove "$@"
        exit 0
        ;;
    restart)
        docker_service_update "$@"
        exit 0
        ;;
    logs)
        docker_service_logs
        exit 0
        ;;
    *)
        echo "需要执行命令，后面加上 --help 查看可执行命令的更多信息"
        exit 0
        ;;
    esac
}

main "$@"

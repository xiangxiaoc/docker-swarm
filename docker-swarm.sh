#!/bin/bash

# docker swarm management script

#########################
# Script Initialization #
#########################

SCRIPT_VERSION='v1'
SCRIPT_UPDATE_DATE='2020-05-03'
SCRIPT_UPDATE_TIME='19:08'
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
CY='\e[0;33m'
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

docker_daemon_host=$(parse_config_file docker_daemon_host)
docker_daemon_port=$(parse_config_file docker_daemon_port)
if [ -z "$docker_daemon_host" ]; then
    remote_docker_daemon=""
    docker_host_display="localhost(/var/run/docker.sock)"
else
    [ -z "$docker_daemon_port" ] && docker_daemon_port="2375"
    remote_docker_daemon="$docker_daemon_host":"$docker_daemon_port"
fi
compose_file=$(parse_config_file compose_file)
[ -f "$compose_file" ] && compose_file_display="$compose_file" || compose_file_display="$compose_file $FR(not exist)$RC"
docker_stack_name=$(parse_config_file stack_name)

#############
# Pre-check #
#############

[ $UID -ne 0 ] && echo "Only for root" && exit 0

function check_swarm_mode() {
    [ -d data ] || mkdir data
    if docker -H "$remote_docker_daemon" swarm join-token worker >data/join_token.txt 2>/dev/null; then
        :
    else
        echo -e "${CY}Swarm mode is inactive. The stack can only be deployed if swarm mode is active.$RC"
        read -r -p "Enable swarm mode? [y/n](default: y): " anwser
        case $anwser in
        "" | y)
            docker -H "$remote_docker_daemon" swarm init
            ;;
        *)
            echo -e "See you!"
            exit 0
            ;;
        esac
    fi
}

function is_stack_deployed() {
    local input_stack=$1
    stack_list=$(docker -H "$remote_docker_daemon" stack ls | sed -n '2,$ p' | awk '{print $1}')
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
        docker -H "$remote_docker_daemon" stack ls --format "{{.Name}}: {{.Services}}" | awk '{if($1=="'"$docker_stack_name"':")print $2}'
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

######################
# Docker Stack Entry #
######################
function list_stacks() {
    docker -H "$remote_docker_daemon" stack ls
}

function docker_stack_deploy() {
    docker -H "$remote_docker_daemon" stack deploy --compose-file "$compose_file" --resolve-image=changed "$docker_stack_name"
}

function list_services() {
    if [ "$is_deployed" == "Not deployed" ]; then
        echo -e "${CY}Stack: $docker_stack_name is not deployed! Please deploy firstly$RC"
        return 0
    fi
    docker -H "$remote_docker_daemon" \
    stack services \
    --format "table {{.Name}}\t {{.Mode}}\t {{.Replicas}}\t {{.Image}}\t" \
    "$docker_stack_name"
}

########################
# Docker Service Entry #
########################
function docker_service_choose() {
    declare -A list
    i=0
    echo -e "Num   Service\n---   -------"
    service_list=$(docker -H "$remote_docker_daemon" stack services --format "{{.Name}}" "$docker_stack_name" | sort -n)
    for docker_service_name in $service_list; do
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
    read -r -p "Type the num to select the service, press Enter: " cho
    docker_service_choice=${list[$cho]}
    echo
}

function list_tasks() {
    if [ "$is_deployed" == "Not deployed" ]; then
        echo -e "${CY}Stack: $docker_stack_name is not deployed! Please deploy firstly$RC"
        return 0
    fi
    docker -H "$remote_docker_daemon" \
    stack ps \
    --format "table {{.Name}}\t {{.Image}}\t {{.Node}}\t {{.DesiredState}}\t {{.CurrentState}}\t {{.Error}}\t" \
    "$docker_stack_name"
}

function docker_service_remove() {
    if [ "$is_deployed" == "Not deployed" ]; then
        echo -e "${CY}Stack: $docker_stack_name is not deployed! Please deploy firstly$RC"
        return 0
    fi
    read -r -p "Remove whole the stack? [y/n](default: n): " cho
    case $cho in
    y)
        docker -H "$remote_docker_daemon" stack rm "$docker_stack_name"
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
        ;;
    "" | *)
        docker_service_choose
        docker -H "$remote_docker_daemon" service rm "$docker_service_choice"
        ;;
    esac
}

function docker_service_update() {
    docker_service_choose
    docker "$remote_docker_daemon" service update --force "$docker_service_choice" "$@"
}

function view_service_logs() {
    if [ "$is_deployed" == "Not deployed" ]; then
        echo -e "${CY}Stack: $docker_stack_name is not deployed! Please deploy firstly$RC"
        return 0
    fi
    docker_service_choose
    read -r -p "how long before now？(unit: minutes default: all logs) " time_to_now
    [ -n "$time_to_now" ] && time_to_now="${time_to_now}m"
    echo
    read -r -p "output or download？  [ 1 output | 2 download ](default：1): " download_cho
    [ -z "$download_cho" ] && download_cho="1" || download_cho=$download_cho
    echo
    case $download_cho in
    1)
        docker -H "$remote_docker_daemon" service logs -f --since "${time_to_now}" "$docker_service_choice"
        ;;
    2)
        if [ -z "${time_to_now}" ]; then
            log_cover_time="all_to_$(date "+%Y%m%d_%H%M%S")"
        else
            log_cover_time="$(date -d "-${time_to_now/m/}minutes" "+%Y%m%d_%H%M%S")_to_$(date "+%Y%m%d_%H%M%S")"
        fi
        log_filename="${docker_service_choice}_${log_cover_time}.log"
        [ -d log ] || mkdir log
        docker -H "$remote_docker_daemon" service logs --since "${time_to_now}" "$docker_service_choice" &>log/"$log_filename"
        ;;
    esac
}
#######################
# Docker Config Entry #
#######################
function docker_config() {
    docker "$remote_docker_daemon" config "$@"
}

##############
# Help Entry #
##############
function show_help() {
    cat <<EOF_help
Docker stack deploy script

Usage: $0 [Command]

Commands:
  version   Script version
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
0. List all deployed stacks in the docker daemon
1. Deploy the stack according to the specified compose file
2. List the services of $docker_stack_name
3. List the tasks (containers) of $docker_stack_name
4. View service logs of $docker_stack_name
5. Remove the stack or service of $docker_stack_name

EOF_menu
    read -r -p "Type the num to select an action: " cho
    case $cho in
    0) list_stacks ;;
    1) docker_stack_deploy ;;
    2) list_services ;;
    3) list_tasks ;;
    4) view_service_logs ;;
    5) docker_service_remove ;;
    *) return ;;
    esac
}

function main() {
    main_command=$1
    shift
    case $main_command in
    '')
        check_swarm_mode
        interactive_menu
        ;;
    version)
        get_script_version
        ;;
    *)
        show_help
        ;;
    esac
}

main "$@"

#!/usr/bin/env bash
#@Author: zoujiangtao
#@Version: 1.0.0
#@Date: 2018-12-25
#@Mail: zoujiangtao@qq.cn
#@Description: 一键安装 php nginx

green='\e[1;32m' # green
red='\e[1;31m' # red
blue='\e[1;34m' # blue
nc='\e[0m' # normal


function install(){
	echo -n "Install $@ ..."
	yum clean all &>/dev/null
	sleep 0.3
	yum  install -y $@
	i=$?
	echo -n "."
	sleep 0.3
	if [ $i == 0 ];then
		echo -e "[${green}Success${nc}]"
	else
		echo -e "[${red}Failed${nc}]"
		echo "Please check your config.."
		exit 3
	fi
}

function set_cfg(){
	sleep 0.3
	systemctl enable $@ &>/dev/null
	echo -n "Setting start-up ..."
	i=$?
	echo -n '.'
	sleep 0.3
	if [ $i == 0 ];then
		echo -e "[${green}Success${nc}]"
	else
		echo -e "[${red}Failed${nc}]"
		echo "Please check your config.."
		exit 4
	fi
}


function start(){
	echo -n "Starting $@ ..."
	sleep 0.3
	systemctl restart $@ &>/dev/null
	i=$?
	echo -n "."
	sleep 0.3
	if [ $i == 0 ];then
		echo -e "[${green}Success${nc}]"
	else
		echo -e "[${red}Failed${nc}]"
		echo "Please check your config.."
		exit 5
	fi
}

function install_nginx() {
    install "nginx"
    sleep 0.5
    start "nginx"
    set_cfg "nginx"
}

function install_php() {
    install "php"
    echo "Installing Extra Tools"
    sleep 0.5
    install "php-fpm php-mysqlnd php-gd php-json libjpeg* php-pear php-xml php-mbstring php-bcmath php-mhash"
    start "php-fpm"
    set_cfg "php-fpm"
}


usage() {
    echo "Usage: $0  [-ilh]"
    echo
    echo "Available arguments:"
    echo "-i,--install   [php|nginx]               install software tools."
    echo "-h,--help                                print the help message."
    echo
    echo "Example: $0  --list php"
    exit
}

parse_option() {
    args=$(getopt -o i:,h --long install:,help -- "$@")
    if [ $? != 0 ];then
        usage
        exit 1
    fi
    eval set -- "${args}"
    while true
    do
        case "$1" in
            -i|--install)
                case "$2" in
                    php)
                        install_php
                        shift 2
                        break
                        ;;
                    nginx)
                        install_nginx
                        shift 2
                        break
                        ;;
                    *)
                        usage
                        shift
                        exit
                        ;;
                esac
                ;;
            -h|--help)
                usage
                shift
                exit 1
                ;;
            --)
                usage
                shift
                break
                ;;
            *)
                echo "Internal error!"
                exit 1
                ;;
        esac

    done

}

parse_option $@


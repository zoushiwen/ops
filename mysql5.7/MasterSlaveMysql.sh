#!/usr/bin/env bash

#Author: zoujiangtao
#Version: 1.1
#Date: 2018-12-12
#Mail: 564710622@qq.com 
#Description: mysql5.7 主从配置脚本

PASSWORD='you_password'
HOST='localhost'
PORT=3306
MYSQL_VERSION='mysql-community-client-5.7.23'
MYSQL_SERVER_VERSION='mysql-community-server-5.7.23'
MASTER_MYSQL_HOST='10.0.0.1'
SLAVE_MYSQL_HOST='10.0.0.2'
SLAVE_MYSQL_USER="root"
MASTER_MYSQL_USER="root"

green='\e[1;32m' # green
red='\e[1;31m' # red
blue='\e[1;34m' # blue
nc='\e[0m' # normal

IP_LOCAL=$(ip a |grep inet|grep -v '127.0.0.1'|cut -d'/' -f1|awk '{print $2}')
check_mysql_status=$(ps -ef |grep mysql.sock|grep -v grep)



function check_env(){

    check_mariadb=$(rpm -qa |grep mariadb)
    check_mariadb_status=$(ps -ef |grep mariadb|grep -v mariadb)

    if [ -n "${check_mariadb_status}" ];then
         echo -e "[${red}Mariadb is running.${nc}]"
         echo -e "[${red}exit install mysql.${nc}]"
         exit 2
    else
        if [ -n "${check_mariadb}" ];then
            rpm --nodeps -e ${check_mariadb}
            echo -e "[${green}Remove ${check_mariadb} Success ${nc}]"
        fi
    fi
    sed -i  's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    chmod 777 /tmp
}

function check_mysql(){

    check_mysql=$(rpm -ql $MYSQL_VERSION)
    i=$?
    check_mysql_server=$(rpm -ql $MYSQL_SERVER_VERSION)
    if [ "$?" != 0 ] || [ "$i" != 0 ];then
        yum -y install $MYSQL_VERSION $MYSQL_SERVER_VERSION
        cp /etc/my.cnf /etc/my.cnf.backup
        service mysqld start
        if [ $? == 0 ];then
            echo -e "[${green}MySQL init Success${nc}]"
        else
            echo -e "[${red}MySQL init Failed.${nc}]"
            exit 1
        fi
    else
        echo -e "$MYSQL_VERSION or $MYSQL_SERVER_VERSION already exists."
    fi

}

function install_mysql() {
    check_mysql
    init_mysql_password=$(grep 'temporary password' /var/log/mysqld.log |awk -F 'localhost:' '{print $2}'|tr -d " "|awk 'END {print}')
    if [ -z "${init_mysql_password}" ];then
        echo -e "[${red}init_mysql_password is NULL.${nc}]"
        exit 2
    fi
    echo "${init_mysql_password}"
    mysql -uroot -p${init_mysql_password} --connect-expired-password <<EOF
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${PASSWORD}';
        grant all privileges on *.* to 'root'@'%' identified by '${PASSWORD}' with grant option;
        flush privileges;
        exit
EOF
    if [ $? == 0 ];then
        echo -e "[${green}MySQL init password Success${nc}]"
        chkconfig mysqld on
    else
        echo -e "[${red}MySQL init password Failed.${nc}]"
        exit 3
    fi


}

function config_mysql(){

    if [ -f "/etc/my.cnf" ];then
        rm -f /etc/my.cnf
        cp /etc/my.cnf.backup /etc/my.cnf
    fi

    if [ "$IP_LOCAL" == "${MASTER_MYSQL_HOST}" ];then
        sed -i "/^\[mysqld\]$/a\port = ${PORT}" /etc/my.cnf
        sed -i "/^\[mysqld\]$/a\log-bin = mysql-bin" /etc/my.cnf
        sed -i "/^\[mysqld\]$/a\server-id = 1" /etc/my.cnf
        sed -i "/^\[mysqld\]$/a\innodb_flush_log_at_trx_commit = 1" /etc/my.cnf
        sed -i "/^\[mysqld\]$/a\sync_binlog = 1" /etc/my.cnf

        mysql -uroot -p${PASSWORD} --connect-expired-password << EOF
        create user '${SLAVE_MYSQL_USER}'@'${SLAVE_MYSQL_HOST}' identified by '${PASSWORD}';
        grant replication slave on *.* to '${SLAVE_MYSQL_USER}'@'${SLAVE_MYSQL_HOST}' identified by '${PASSWORD}';
        flush tables with read lock;
        select sleep(5);
EOF
        service mysqld restart

    else
        sed -i "/^\[mysqld\]$/a\port = ${PORT}" /etc/my.cnf
        sed -i "/^\[mysqld\]$/a\server-id = 2" /etc/my.cnf
        sed -i "/^\[mysqld\]$/a\relay-log = slave-relay-bin" /etc/my.cnf
        sed -i "/^\[mysqld\]$/a\read_only = 1" /etc/my.cnf
        sed -i "/^\[mysqld\]$/a\log-bin = mysql-bin" /etc/my.cnf
        service mysqld restart
    fi
}

function remove_mysql(){
    service mysqld stop
    yum remove -y ${MYSQL_VERSION} ${MYSQL_SERVER_VERSION}
    if [ $? -eq 0 ]; then
      if [ -d "/var/lib/mysql/" ];then
        rm -rf /var/lib/mysql
      fi
    fi

}

function replication_mysql(){

    #查看master状态 获取file 以及position的信息
    bin_info=$(mysql -h${MASTER_MYSQL_HOST} -u${MASTER_MYSQL_USER} -p${PASSWORD} -e "show master status;")
    file=$(echo $bin_info | awk '{print $6}')
    position=$(echo $bin_info | awk '{print $7}')

    echo "bin_info:" $bin_info
    echo "file name:" $file
    echo "position:" $position

    #首先确保slave中的mysql 停止slave
    startCmd="mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e \"stop slave;\""
    echo "start cmd:"${startCmd}
    mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e "stop slave;"
    mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e "reset slave;"
    if [ $? -eq 0 ]; then
      echo -e "[${green}exec: <slave stop> success ${nc}]"
      echo
    else
      echo -e "[${red}exec: <slave stop> failure${nc}]"
      echo
    fi

    #change master
    changeCmd="change master to MASTER_HOST='${MASTER_MYSQL_HOST}',MASTER_PORT=${PORT},MASTER_USER='${MASTER_MYSQL_USER}',\
                MASTER_PASSWORD='${PASSWORD}',MASTER_LOG_FILE='${file}',MASTER_LOG_POS=${position};"
    echo "change cmd:" ${changeCmd}


    #登录slave的mysql进行 change操作
    remoteCmd="mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e \"${changeCmd}\""
    echo "remote cmd:" ${remoteCmd}
    mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e "${changeCmd}"

    if [ $? -eq 0 ]; then
    echo -e "[${green}exec: <change master...> success ${nc}]"
    echo
    else
    echo -e "[${red}exec: <change master...> failure${nc}]"
    echo
    fi

    #启动slave
    startCmd="mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e \"start slave;\""
    echo "start cmd:" ${startCmd}
    mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e "start slave;"
    if [ $? -eq 0 ]; then
    echo -e "[${green}exec: <start slave> success ${nc}]"
    sleep 3
    echo
    else
    echo -e "[${red}exec: <start slave> failure${nc}]"
    echo
    fi

    #查看slave状态
    statusCmd="mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e \"show slave status\G\""
    echo "status cmd:" ${statusCmd}
    mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e "show slave status\G"

    if [ $? -eq 0 ]; then
      echo -e "[${green}exec: <show slave status> success ${nc}]"
      echo
    else
      echo -e "[${red}exec: <show slave status> failure${nc}]"
      echo
    fi
}

check_env


if [ -n "${check_mysql_status}" ];then
        echo -e "[${red}MySQL is running.${nc}]"
        config_mysql
else
        remove_mysql
        install_mysql
        config_mysql
fi

if [ "$IP_LOCAL" == "${MASTER_MYSQL_HOST}" ];then
    mysql -h${SLAVE_MYSQL_HOST} -u${SLAVE_MYSQL_USER} -p${PASSWORD} -e "show databases;"
    if [ $? -eq 0 ]; then
        echo -e "[${green}exec: <Connection slave ${SLAVE_MYSQL_HOST}> success ${nc}]"
        echo
        replication_mysql
    else
        echo -e "[${red}exec: <Connection slave ${SLAVE_MYSQL_HOST}> failure${nc}]"
        echo -e "[${red}exec: <Please install slave ${SLAVE_MYSQL_HOST} MySQL.> ${nc}]"
    fi
fi


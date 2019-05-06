#!/usr/bin/env bash

USER="root"
password='you password'
HOST='localhost'
PORT=3306
MYSQL='mysql-community-client-5.7.23'
MYSQL_SERER='mysql-community-server-5.7.23'



function checkenv(){
    sed -i  's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    chmod 777 /tmp
}

function check_mysql(){
    check_mysql=$(rpm -ql $MYSQL)
    i=$?
    check_mysql_server=$(rpm -ql $MYSQL_SERER)
    if [ "$?" != 0 ] || [ "$i" != 0 ];then
        yum -y localinstall $MYSQL $MYSQL_SERER
        service mysqld start
        if [ $? == 0 ];then
            echo -e "MySQL init success."
        else
            echo -e "MySQL init Failed."
            exit 1
        fi
    else
        echo -e "$MYSQL or $MYSQL_SERER already exists."
    fi
}

function install_mysql() {
    check_mysql
    init_mysql_password=$(grep 'temporary password' /var/log/mysqld.log | awk -F 'localhost:' '{print $2}'|tr -d " ")
    if [ -z "$init_mysql_password" ];then
        echo "init_mysql_password is NULL."
        exit 2
    fi

    export MYSQL_PWD=$init_mysql_password
    export PASSWORD=$password

    mysql -uroot --connect-expired-password <<EOF
        ALTER USER 'root'@'localhost' IDENTIFIED BY "$PASSWORD";
        grant all privileges on *.* to 'root'@'%' identified by "$PASSWORD" with grant option;
        flush privileges;
        exit
EOF
    if [ $? == 0 ];then
        echo -e "MySQL init password Success."
    else
        echo -e "MySQL init password Failed."
        exit 3
    fi
}

checkenv

install_mysql

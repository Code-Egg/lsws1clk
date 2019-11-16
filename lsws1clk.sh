#!/bin/bash
# /********************************************************************
# LiteSpeed + WordPress + LSCache + PHP 7.3 + Object Cache + PHPMyAdmin
# *********************************************************************/
CMDFD='/opt'
WWWFD='/var/www'
DOCROOT='/var/www/html'
PHPMYFD='/var/www/phpmyadmin'
PHPMYCONF="${PHPMYFD}/config.inc.php"
LSDIR='/usr/local/lsws'
LSCONF="${LSDIR}/conf/httpd_config.xml"
LSVCONF="${LSDIR}/DEFAULT/conf/vhconf.xml"
USER=''
GROUP=''
THEME='twentytwenty'
MARIAVER='10.3'
PHPVER='73'
PHP_M='7'
PHP_S='3'
FIREWALLLIST="22 80 443"
PHP_BIN="${LSDIR}/lsphp${PHPVER}/bin/lsphp"
PHPINICONF=""
WPCFPATH="${DOCROOT}/wp-config.php"
REPOPATH=''
WP_CLI='/usr/local/bin/wp'
MEMCACHECONF=''
REDISSERVICE=''
REDISCONF=''
WPCONSTCONF="${DOCROOT}/wp-content/plugins/litespeed-cache/data/const.default.ini"
PLUGIN='litespeed-cache.zip'
BANNERNAME='wordpress'
BANNERDST=''
SKIP_WP=0
OSNAMEVER=''
OSNAME=''
OSVER=''

silent() {
  if [[ $debug ]] ; then
    "$@"
  else
    "$@" >/dev/null 2>&1
  fi
}

create_doc_fd(){
    if [ ! -d ${DOCROOT} ]; then
        echoG "Create ${DOCROOT} folder"
        mkdir -p ${DOCROOT}
    fi
}

echoY() {
    echo -e "\033[38;5;148m${1}\033[39m"
}
echoG() {
    echo -e "\033[38;5;71m${1}\033[39m"
}
echoR()
{
    echo -e "\033[38;5;203m${1}\033[39m"
}

get_ip(){
    if [ -e /sys/devices/virtual/dmi/id/product_uuid ] && [ "$(sudo cat /sys/devices/virtual/dmi/id/product_uuid | cut -c 1-3)" = 'EC2' ]; then
        MYIP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
    elif [ "$(sudo dmidecode -s bios-vendor)" = 'Google' ]; then
        MYIP=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
    elif [ "$(dmidecode -s system-manufacturer)" = 'Microsoft Corporation' ];then
        MYIP=$(curl -s http://checkip.amazonaws.com || printf "0.0.0.0")
    elif [ "$(dmidecode -s system-product-name | cut -c 1-7)" = 'Alibaba' ]; then
        MYIP=$(curl -s http://100.100.100.200/latest/meta-data/eipv4)
    else
        MYIP=$(ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n')
    fi
}

line_change(){
    LINENUM=$(grep -v '#' ${2} | grep -n "${1}" | cut -d: -f 1)
    if [ -n "$LINENUM" ] && [ "$LINENUM" -eq "$LINENUM" ] 2>/dev/null; then
        sed -i "${LINENUM}d" ${2}
        sed -i "${LINENUM}i${3}" ${2}
    fi
}

cked()
{
    if [ -f /bin/ed ]; then
        echoG "ed exist"
    else
        echoG "no ed, ready to install"
        if [ "${OSNAME}" = 'ubuntu' ] || [ "${OSNAME}" = 'debian' ]; then
            apt-get install ed -y > /dev/null 2>&1
        elif [ "${OSNAME}" = 'centos' ]; then
            yum install ed -y > /dev/null 2>&1
        fi
    fi
}

check_os()
{
    OSTYPE=$(uname -m)
    MARIADBCPUARCH=
    if [ -f /etc/redhat-release ] ; then
        OSVER=$(cat /etc/redhat-release | awk '{print substr($4,1,1)}')
        if [ ${?} = 0 ] ; then
            OSNAMEVER=CENTOS${OSVER}
            OSNAME=centos
            rpm -ivh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el${OSVER}.noarch.rpm >/dev/null 2>&1
        fi
    elif [ -f /etc/lsb-release ] ; then
        OSNAME=ubuntu
        wget -qO - http://rpms.litespeedtech.com/debian/enable_lst_debain_repo.sh | bash >/dev/null 2>&1
        UBUNTU_V=$(grep 'DISTRIB_RELEASE' /etc/lsb-release | awk -F '=' '{print substr($2,1,2)}')
        if [ ${UBUNTU_V} = 14 ] ; then
            OSNAMEVER=UBUNTU14
            OSVER=trusty
            MARIADBCPUARCH="arch=amd64,i386,ppc64el"
        elif [ ${UBUNTU_V} = 16 ] ; then
            OSNAMEVER=UBUNTU16
            OSVER=xenial
            MARIADBCPUARCH="arch=amd64,i386,ppc64el"
        elif [ ${UBUNTU_V} = 18 ] ; then
            OSNAMEVER=UBUNTU18
            OSVER=bionic
            MARIADBCPUARCH="arch=amd64"
        fi
    elif [ -f /etc/debian_version ] ; then
        OSNAME=debian
        wget -O - http://rpms.litespeedtech.com/debian/enable_lst_debain_repo.sh | bash
        DEBIAN_V=$(awk -F '.' '{print $1}' /etc/debian_version)
        if [ ${DEBIAN_V} = 7 ] ; then
            OSNAMEVER=DEBIAN7
            OSVER=wheezy
            MARIADBCPUARCH="arch=amd64,i386"
        elif [ ${DEBIAN_V} = 8 ] ; then
            OSNAMEVER=DEBIAN8
            OSVER=jessie
            MARIADBCPUARCH="arch=amd64,i386"
        elif [ ${DEBIAN_V} = 9 ] ; then
            OSNAMEVER=DEBIAN9
            OSVER=stretch
            MARIADBCPUARCH="arch=amd64,i386"
        elif [ ${DEBIAN_V} = 10 ] ; then
            OSNAMEVER=DEBIAN10
            OSVER=buster
        fi
    fi
    if [ "${OSNAMEVER}" = "" ] ; then
        echoR "Sorry, currently one click installation only supports Centos(6-8), Debian(7-10) and Ubuntu(14,16,18)."
        echoR "You can download the source code and build from it."
        exit 1
    else
        if [ "${OSNAME}" = "centos" ] ; then
            echoG "Current platform is ${OSNAME} ${OSVER}"
        else
            export DEBIAN_FRONTEND=noninteractive
            echoG "Current platform is ${OSNAMEVER} ${OSNAME} ${OSVER}."
        fi
    fi
}

path_update(){
    if [ "${OSNAME}" = "centos" ] ; then
        USER='nobody'
        GROUP='nobody'
        REPOPATH='/etc/yum.repos.d'
        PHPINICONF="${LSWSFD}/lsphp${PHPVER}/etc/php.ini"
        REDISSERVICE='/lib/systemd/system/redis.service'
        REDISCONF='/etc/redis.conf'
        MEMCACHESERVICE='/etc/systemd/system/memcached.service'
        MEMCACHECONF='/etc/sysconfig/memcached'
        BANNERDST='/etc/profile.d/99-one-click.sh'
    elif [ "${OSNAME}" = 'ubuntu' ] || [ "${OSNAME}" = 'debian' ]; then
        USER='www-data'
        GROUP='www-data'
        REPOPATH='/etc/apt/sources.list.d'
        PHPINICONF="${LSDIR}/lsphp${PHPVER}/etc/php/${PHP_M}.${PHP_S}/litespeed/php.ini"
        REDISSERVICE='/lib/systemd/system/redis-server.service'
        REDISCONF='/etc/redis/redis.conf'
        MEMCACHECONF='/etc/memcached.conf'
        BANNERDST='/etc/update-motd.d/99-one-click'
    fi
}

provider_ck()
{
    if [ -e /sys/devices/virtual/dmi/id/product_uuid ] && [ "$(sudo cat /sys/devices/virtual/dmi/id/product_uuid | cut -c 1-3)" = 'EC2' ]; then
        PROVIDER='aws'
    elif [ "$(dmidecode -s bios-vendor)" = 'Google' ];then
        PROVIDER='google'
    elif [ "$(dmidecode -s bios-vendor)" = 'DigitalOcean' ];then
        PROVIDER='do'
    elif [ "$(dmidecode -s system-product-name | cut -c 1-7)" = 'Alibaba' ];then
        PROVIDER='aliyun'
    elif [ "$(dmidecode -s system-manufacturer)" = 'Microsoft Corporation' ];then
        PROVIDER='azure'
    else
        PROVIDER='undefined'
    fi
}

os_hm_path()
{
    if [ ${PROVIDER} = 'aws' ] && [ -d /home/ubuntu ]; then
        HMPATH='/home/ubuntu'
    elif [ ${PROVIDER} = 'google' ] && [ -d /home/ubuntu ]; then
        HMPATH='/home/ubuntu'
    elif [ ${PROVIDER} = 'aliyun' ] && [ -d /home/ubuntu ]; then
        HMPATH='/home/ubuntu'
    else
        HMPATH='/root'
    fi
    ADMIN_PASS_PATH="${HMPATH}/.litespeed_password"
    DB_PASS_PATH="${HMPATH}/.db_password"
}

KILL_PROCESS(){
    PROC_NUM=$(pidof ${1})
    if [ ${?} = 0 ]; then
        kill -9 ${PROC_NUM}
    fi
}

ubuntu_sysupdate(){
    echoG 'System update'
    silent apt-get update
    silent DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::='--force-confdef' \
    -o Dpkg::Options::='--force-confold' upgrade
    silent DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::='--force-confdef' \
    -o Dpkg::Options::='--force-confold' dist-upgrade
}

centos_sysupdate(){
    echoG 'System update'
    silent yum update -y
    setenforce 0
}

remove_file(){
    if [ -e ${1} ]; then
        rm -rf ${1}
    fi
}

backup_old(){
    if [ -f ${1} ] && [ ! -f ${1}_old ]; then
       mv ${1} ${1}_old
    fi
}

linechange(){
    LINENUM=$(grep -n "${1}" ${2} | cut -d: -f 1)
    if [ -n "$LINENUM" ] && [ "$LINENUM" -eq "$LINENUM" ] 2>/dev/null; then
        sed -i "${LINENUM}d" ${2}
        sed -i "${LINENUM}i${3}" ${2}
    fi

}
gen_password(){
    if [ ! -f ${ADMIN_PASS_PATH} ]; then
        ADMIN_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')
    else
        ADMIN_PASS=$(grep admin_pass ${ADMIN_PASS_PATH} | awk -F'"' '{print $2}')
    fi
    if [ ! -f ${DB_PASS_PATH} ]; then
        MYSQL_ROOT_PASS=$(openssl rand -hex 24)
        MYSQL_USER_PASS=$(openssl rand -hex 24)
    else
        MYSQL_ROOT_PASS=$(grep root_mysql_pass ${DB_PASS_PATH} | awk -F'=' '{print $2}')
        MYSQL_USER_PASS=$(grep wordpress_mysql_pass ${DB_PASS_PATH} | awk -F'=' '{print $2}')
    fi
}

gen_salt(){
    GEN_SALT=$(</dev/urandom tr -dc 'a-zA-Z0-9!@#%^&*()-_[]{}<>~+=' | head -c 64 | sed -e 's/[\/&]/\&/g')
}

gen_pass_file(){
    if [ -f "${ADMIN_PASS_PATH}" ]; then
        rm -f ${ADMIN_PASS_PATH}
    fi
    if [ -f "${DB_PASS_PATH}" ]; then
        rm -f ${DB_PASS_PATH}
    fi
    echoG 'Generate .litespeed_password file'
    touch ${ADMIN_PASS_PATH}
    echoG 'Generate .db_password file'
    touch ${DB_PASS_PATH}
}

update_pass_file(){
    cat >> ${ADMIN_PASS_PATH} <<EOM
admin_pass="${ADMIN_PASS}"
EOM

    cat >> ${DB_PASS_PATH} <<EOM
root_mysql_pass="${MYSQL_ROOT_PASS}"
wordpress_mysql_pass="${MYSQL_USER_PASS}"
EOM
}

rm_old_pkg(){
    silent systemctl stop ${1}
    if [ ${OSNAME} = 'centos' ]; then
        silent yum remove ${1} -y
    else
        silent apt remove ${1} -y
    fi
    if [ $(systemctl is-active ${1}) != 'active' ]; then
        echoG "[OK] remove ${1}"
    else
        echoR "[Failed] remove ${1}"
    fi
}

restart_lsws(){
    echoG 'Restart LiteSpeed Web Server'
    ${LSDIR}/bin/lswsctrl restart >/dev/null 2>&1
}

ubuntu_pkg_basic(){
    echoG 'Install basic packages'
    if [ ! -e /bin/wget ]; then
        silent apt-get install lsb-release -y
        silent apt-get install curl wget -y
    fi
    silent apt-get install curl unzip software-properties-common -y
}

ubuntu_pkg_postfix(){
    if [ -e /usr/sbin/postfix ]; then
        echoG 'Postfix already installed'
    else
        echoG 'Installing postfix'
        DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' \
        -o Dpkg::Options::='--force-confold' install postfix >/dev/null 2>&1
        [[ -e /usr/sbin/postfix ]] && echoG 'Install postfix Success' || echoR 'Install postfix Failed'
    fi
}

ubuntu_pkg_memcached(){
    echoG 'Install Memcached'
    apt-get -y install memcached > /dev/null 2>&1
    systemctl start memcached > /dev/null 2>&1
    systemctl enable memcached > /dev/null 2>&1
}

ubuntu_pkg_redis(){
    echoG 'Install Redis'
    apt-get -y install redis > /dev/null 2>&1
    systemctl start redis > /dev/null 2>&1
}

pkg_phpmyadmin(){
    if [ ! -f ${PHPMYFD}/changelog.php ]; then
        cd ${CMDFD}/
        echoG 'Install phpmyadmin'
        wget -q --no-check-certificate https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
        unzip phpMyAdmin-latest-all-languages.zip > /dev/null 2>&1
        rm -f phpMyAdmin-latest-all-languages.zip
        mv phpMyAdmin-*-all-languages ${PHPMYFD}
        mv ${PHPMYFD}/config.sample.inc.php ${PHPMYCONF}
    else
        echoY "phpMyAdmin exist, skip!"
    fi
}

ubuntu_pkg_phpmyadmin(){
    pkg_phpmyadmin
}

ubuntu_pkg_certbot(){
    echoG "Install CertBot"
    add-apt-repository universe > /dev/null 2>&1
    echo -ne '\n' | add-apt-repository ppa:certbot/certbot > /dev/null 2>&1
    apt-get update > /dev/null 2>&1
    apt-get -y install certbot > /dev/null 2>&1
    if [ -e /usr/bin/certbot ] || [ -e /usr/local/bin/certbot ]; then
        echoG 'Install CertBot finished'
    else
        echoR 'Please check CertBot'
    fi
}

ubuntu_pkg_system(){
    if [ -e /usr/sbin/dmidecode ]; then
        echoG 'dmidecode already installed'
    else
        echoG 'Install dmidecode'
        silent apt-get install dmidecode -y
        [[ -e /usr/sbin/dmidecode ]] && echoG 'Install dmidecode Success' || echoR 'Install dmidecode Failed'
    fi
}

ubuntu_pkg_mariadb(){
    apt list --installed 2>/dev/null | grep mariadb-server-${MARIAVER} >/dev/null 2>&1
    if [ ${?} = 0 ]; then
        echoG "Mariadb ${MARIAVER} already installed"
    else
        if [ -e /etc/mysql/mariadb.cnf ]; then
            echoY 'Remove old mariadb'
            rm_old_pkg mariadb-server
        fi
        echoG "Install Mariadb ${MARIAVER}"
        silent apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
        silent add-apt-repository "deb [arch=amd64,arm64,ppc64el] http://mirror.lstn.net/mariadb/repo/${MARIAVER}/ubuntu bionic main"
        if [ "$(grep "mariadb.*${MARIAVER}" /etc/apt/sources.list)" = '' ]; then
            echoR '[Failed] to add MariaDB repository'
        fi
        silent apt update
        DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' \
            -o Dpkg::Options::='--force-confold' install mariadb-server >/dev/null 2>&1
    fi
    systemctl start mariadb
    local DBSTATUS=$(systemctl is-active mariadb)
    if [ ${DBSTATUS} = active ]; then
        echoG "MARIADB is: ${DBSTATUS}"
    else
        echoR "[Failed] Mariadb is: ${DBSTATUS}"
    fi
}

centos_pkg_basic(){
    echoG 'Install basic packages'
    if [ ! -e /bin/wget ]; then
        silent yum install epel-release -y
        silent yum update -y
        silent yum install curl yum-utils wget unzip -y
    fi
    if [[ -z "$(rpm -qa epel-release)" ]]; then
        silent yum install epel-release -y
    fi
    if [ ! -e /usr/bin/yum-config-manager ]; then
        silent yum install yum-utils -y
    fi
    if [ ! -e /usr/bin/curl ]; then
        silent yum install curl -y
    fi
}

centos_pkg_postfix(){
    if [ -e /usr/sbin/postfix ]; then
        echoG 'Postfix already installed'
    else
        echoG 'Installing postfix'
        yum install postfix -y >/dev/null 2>&1
        [[ -e /usr/sbin/postfix ]] && echoG 'Install postfix Success' || echoR 'Install postfix Failed'
    fi
}

centos_pkg_memcached(){
    echoG 'Install Memcached'
    yum -y install memcached > /dev/null 2>&1
    systemctl start memcached > /dev/null 2>&1
    systemctl enable memcached > /dev/null 2>&1
}

centos_pkg_redis(){
    echoG 'Install Redis'
    yum -y install redis > /dev/null 2>&1
    systemctl start redis > /dev/null 2>&1
}

centos_pkg_phpmyadmin(){
    pkg_phpmyadmin
}

centos_pkg_certbot(){
    echoG "Install CertBot"
    if [ ${OSVER} = 8 ]; then
        wget -q https://dl.eff.org/certbot-auto
        mv certbot-auto /usr/local/bin/certbot
        chown root /usr/local/bin/certbot
        chmod 0755 /usr/local/bin/certbot
        echo "y" | /usr/local/bin/certbot > /dev/null 2>&1
    else
        yum -y install certbot  > /dev/null 2>&1
    fi
    if [ -e /usr/bin/certbot ] || [ -e /usr/local/bin/certbot ]; then
        echoG 'Install CertBot finished'
    else
        echoR 'Please check CertBot'
    fi
}

centos_pkg_system(){
    if [ -e /usr/sbin/dmidecode ]; then
        echoG 'dmidecode already installed'
    else
        echoG 'Install dmidecode'
        silent yum install dmidecode -y
        [[ -e /usr/sbin/dmidecode ]] && echoG 'Install dmidecode Success' || echoR 'Install dmidecode Failed'
    fi
}

centos_pkg_mariadb(){
    silent rpm -qa | grep mariadb-server-${MARIAVER}

    if [ ${?} = 0 ]; then
        echoG "Mariadb ${MARIAVER} already installed"
    else
        if [ -e /etc/mysql/mariadb.cnf ]; then
            echoY 'Remove old mariadb'
            rm_old_pkg mariadb-server
        fi

        echoG "InstallMariadb ${MARIAVER}"

        if [ "${OSTYPE}" != "x86_64" ] ; then
            CENTOSVER=centos${OSVER}-x86
        else
            CENTOSVER=centos${OSVER}-amd64
        fi

        cat > ${REPOPATH}/MariaDB.repo << EOM
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/${MARIADBVER}/${CENTOSVER}
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOM
        if [ "${OSNAMEVER}" = "CENTOS8" ] ; then
            silent yum install -y boost-program-options
            silent yum --disablerepo=AppStream install -y MariaDB-server MariaDB-client
        else
            silent yum install MariaDB-server MariaDB-client -y
        fi
    fi
    systemctl start mariadb
    local DBSTATUS=$(systemctl is-active mariadb)
    if [ ${DBSTATUS} = active ]; then
        echoG "MARIADB is: ${DBSTATUS}"
    else
        echoR "[Failed] Mariadb is: ${DBSTATUS}"
        echoR "You may want to manually run the command 'yum -y install MariaDB-server MariaDB-client' to check. Aborting installation!"
        exit 1
    fi
}

set_mariadb_root(){
    SQLVER=$(mysql -u root -e 'status' | grep 'Server version')
    SQLVER_1=$(echo ${SQLVER} | awk '{print substr ($3,1,2)}')
    SQLVER_2=$(echo ${SQLVER} | awk -F '.' '{print $2}')
    mysql -u root -e "UPDATE mysql.user SET authentication_string = '' WHERE user = 'root';"
    mysql -u root -e "UPDATE mysql.user SET plugin = '' WHERE user = 'root';"
    if [ "${SQLVER_1}" -le "10" ] && [ "${SQLVER_2}" -le "2" ]; then
        mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MYSQL_ROOT_PASS}');"
    else
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';"
    fi
}

install_lsws(){
    cd ${CMDFD}/
    if [ -e ${CMDFD}/lsws* ] || [ -d ${LSDIR} ]; then
        echoY 'Remove existing LSWS'
        silent systemctl stop lsws
        KILL_PROCESS litespeed
        rm -rf ${CMDFD}/lsws*
        rm -rf ${LSDIR}
    fi
    echoG 'Download LiteSpeed Web Server'
    wget -q --no-check-certificate https://www.litespeedtech.com/packages/5.0/lsws-5.4-ent-x86_64-linux.tar.gz -P ${CMDFD}/
    silent tar -zxvf lsws-*-ent-x86_64-linux.tar.gz
    rm -f lsws-*.tar.gz
    cd lsws-*
    wget -q --no-check-certificate http://license.litespeedtech.com/reseller/trial.key
    sed -i '/^license$/d' install.sh
    sed -i 's/read TMPS/TMPS=0/g' install.sh
    sed -i 's/read TMP_YN/TMP_YN=N/g' install.sh
    sed -i '/read [A-Z]/d' functions.sh
    sed -i 's/HTTP_PORT=$TMP_PORT/HTTP_PORT=443/g' functions.sh
    sed -i 's/ADMIN_PORT=$TMP_PORT/ADMIN_PORT=7080/g' functions.sh
    sed -i "/^license()/i\
    PASS_ONE=${ADMIN_PASS}\
    PASS_TWO=${ADMIN_PASS}\
    TMP_USER=${USER}\
    TMP_GROUP=${GROUP}\
    TMP_PORT=''\
    TMP_DEST=''\
    ADMIN_USER=''\
    ADMIN_EMAIL=''
    " functions.sh

    echoG 'Install LiteSpeed Web Server'
    silent /bin/bash install.sh
    echoG 'Upgrade to Latest stable release'
    silent ${LSDIR}/admin/misc/lsup.sh -f
    silent ${LSDIR}/bin/lswsctrl start
    SERVERV=$(cat /usr/local/lsws/VERSION)
    echoG "Version: lsws ${SERVERV}"
    rm -rf ${CMDFD}/lsws-*
    cd /
}

ubuntu_install_lsws(){
    install_lsws
}

centos_install_lsws(){
    install_lsws
}

ubuntu_reinstall(){
    apt --installed list 2>/dev/null | grep ${1} >/dev/null
    if [ ${?} = 0 ]; then
        OPTIONAL='--reinstall'
    else
        OPTIONAL=''
    fi
}

centos_reinstall(){
    rpm -qa | grep ${1} >/dev/null
    if [ ${?} = 0 ]; then
        OPTIONAL='reinstall'
    else
        OPTIONAL='install'
    fi
}

ubuntu_install_php(){
    echoG 'Install PHP & Packages for LSWS'
    ubuntu_reinstall "lsphp${PHPVER}"
    for PKG in '' -common -curl -gd -json -mysql -imagick -imap -memcached -msgpack -redis -mcrypt -opcache ; do
        /usr/bin/apt ${OPTIONAL} install -y lsphp${PHPVER}${PKG} >/dev/null 2>&1
    done
}

centos_install_php(){
    echoG 'Install PHP & Packages'
    for PKG in '' -common -gd -pdo -imap -mbstring -imagick -mysqlnd -memcached -mcrypt -process -opcache -redis -json -xml -xmlrpc; do
        /usr/bin/yum install lsphp${PHPVER}${PKG} -y >/dev/null 2>&1
    done

}

set_mariadb_user(){
    mysql -u root -p${MYSQL_ROOT_PASS} -e "DELETE FROM mysql.user WHERE User = '${WP_USER}';"
    mysql -u root -p${MYSQL_ROOT_PASS} -e "CREATE DATABASE IF NOT EXISTS ${WP_NAME};"
    if [ ${?} = 0 ]; then
        mysql -u root -p${MYSQL_ROOT_PASS} -e "grant all privileges on ${WP_NAME}.* to '${WP_USER}'@'localhost' identified by '${WP_PASS}';"
    else
        echoR "Failed to create database ${WP_NAME}. It may already exist. Skip WordPress setup!"
        SKIP_WP=1
    fi
}

install_WP_CLI(){
    if [ -e ${WP_CLI} ]; then
        echoG 'WP CLI already exist'
    else
        curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        silent ${PHP_BIN} wp-cli.phar --info --allow-root
        if [ ${?} != 0 ]; then
            echoR 'Issue with wp-cli.phar, Please check PHP!'
        else
            mv wp-cli.phar ${WP_CLI}
        fi
    fi
}

install_wordpress(){
    if [ -e ${WPCFPATH} ]; then
        echoY 'WordPress already exist, skip WordPress setup !'
    else
        install_WP_CLI
        silent mysql -u root -e 'status'
        if [ ${?} = 0 ]; then
            set_mariadb_root
            WP_NAME='wordpress'
            WP_USER='wordpress'
            WP_PASS="${MYSQL_USER_PASS}"
            echoG 'Install WordPress...'
            cd ${DOCROOT}
            set_mariadb_user
            if [ ${SKIP_WP} = 0 ]; then
                wget -q --no-check-certificate https://wordpress.org/latest.zip
                unzip -q latest.zip
                mv wordpress/* ${DOCROOT}
                rm -rf latest.zip wordpress
            fi
        fi
    fi
}

gen_selfsigned_cert(){
    echoG 'Generate Cert'
    KEYNAME="${LSDIR}/conf/example.key"
    CERTNAME="${LSDIR}/conf/example.crt"
    ### ECDSA 256bit
    openssl ecparam  -genkey -name prime256v1 -out ${KEYNAME}
    silent openssl req -x509 -nodes -days 365 -new -key ${KEYNAME} -out ${CERTNAME} <<csrconf
US
NJ
Virtual
LiteSpeedCommunity
Testing
webadmin
.
.
.
csrconf
}

config_htaccess(){
    echoG 'Setting WordPress'
    if [ ! -f ${DOCROOT}/.htaccess ]; then
        touch ${DOCROOT}/.htaccess
    fi
    cat << EOM > ${DOCROOT}/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOM
}

config_wp(){
    if [ -e "${DOCROOT}/wp-config-sample.php" ]; then
        sed -e "s/database_name_here/${WP_NAME}/" -e "s/username_here/wordpress/" -e "s/password_here/${MYSQL_USER_PASS}/" \
        "${DOCROOT}/wp-config-sample.php" > "${WPCFPATH}"
    else
        echoR 'WordPress setup skip, wp-config-sample.php does not exist!'
    fi

    echoG "Install ${PLUGIN}"
    wget -q -P ${DOCROOT}/wp-content/plugins/ https://downloads.wordpress.org/plugin/${PLUGIN}
    if [ ${?} = 0 ]; then
        unzip -qq -o ${DOCROOT}/wp-content/plugins/${PLUGIN} -d ${DOCROOT}/wp-content/plugins/
    else
        echoR "${PLUGINLIST} FAILED to download"
    fi
    rm -f ${DOCROOT}/wp-content/plugins/*.zip
}

config_lscache(){
    cat << EOM > "${WPCONSTCONF}"
; This is the default LSCWP configuration file
; All keys and values please refer const.cls.php
; Here just list some examples
; Comments start with \`;\`
; OPID_PURGE_ON_UPGRADE
purge_upgrade = true
; OPID_CACHE_PRIV
cache_priv = true
; OPID_CACHE_COMMENTER
cache_commenter = true
;Object_Cache_Enable
cache_object = true
; OPID_CACHE_OBJECT_HOST
;cache_object_host = 'localhost'
cache_object_host = '/var/www/memcached.sock'
; OPID_CACHE_OBJECT_PORT
;cache_object_port = '11211'
cache_object_port = ''
auto_upgrade = true
; OPID_CACHE_BROWSER_TTL
cache_browser_ttl = 2592000
; OPID_PUBLIC_TTL
public_ttl = 604800
; ------------------------------CDN Mapping Example BEGIN-------------------------------
; Need to add the section mark \`[litespeed-cache-cdn_mapping]\` before list
;
; NOTE 1) Need to set all child options to make all resources to be replaced without missing
; NOTE 2) \`url[n]\` option must have to enable the row setting of \`n\`
;
; To enable the 2nd mapping record by default, please remove the \`;;\` in the related lines
[litespeed-cache-cdn_mapping]
url[0] = ''
inc_js[0] = true
inc_css[0] = true
inc_img[0] = true
filetype[0] = '.aac
.css
.eot
.gif
.jpeg
.js
.jpg
.less
.mp3
.mp4
.ogg
.otf
.pdf
.png
.svg
.ttf
.woff'
;;url[1] = 'https://2nd_CDN_url.com/'
;;filetype[1] = '.webm'
; ------------------------------CDN Mapping Example END-------------------------------
EOM

    if [ ! -f ${DOCROOT}/wp-content/themes/${THEME}/functions.php.bk ]; then
        cp ${DOCROOT}/wp-content/themes/${THEME}/functions.php ${DOCROOT}/wp-content/themes/${THEME}/functions.php.bk
        cked
        ed ${DOCROOT}/wp-content/themes/${THEME}/functions.php << END >>/dev/null 2>&1
2i
require_once( WP_CONTENT_DIR.'/../wp-admin/includes/plugin.php' );
\$path = 'litespeed-cache/litespeed-cache.php' ;
if (!is_plugin_active( \$path )) {
    activate_plugin( \$path ) ;
    rename( __FILE__ . '.bk', __FILE__ );
}
.
w
q
END
    fi
}

check_spec(){
    CPU_NUM=$(nproc)
}

cpu_process(){
    check_spec
    if [[ ${CPU_NUM} > 1 ]]; then
        sed -i 's/<binding>1<\/binding>/<binding><\/binding>/g' ${LSCONF}
        sed -i 's/<reusePort>0<\/reusePort>/<reusePort>1<\/reusePort>/g' ${LSCONF}
    fi
}

change_owner(){
    echoG 'Change Owner'
    chown -R ${USER}:${GROUP} ${1}
}

setup_lsws(){
    echoG 'Setting LSWS Config'
    backup_old ${LSCONF}
    backup_old ${LSVCONF}
    cat > ${LSCONF} <<END
<?xml version="1.0" encoding="UTF-8"?>
<httpServerConfig>
  <serverName>\$HOSTNAME</serverName>
  <user>www-data</user>
  <group>www-data</group>
  <priority>0</priority>
  <chrootPath>/</chrootPath>
  <enableChroot>0</enableChroot>
  <inMemBufSize>120M</inMemBufSize>
  <swappingDir>/tmp/lshttpd/swap</swappingDir>
  <autoFix503>1</autoFix503>
  <loadApacheConf>0</loadApacheConf>
  <mime>\$SERVER_ROOT/conf/mime.properties</mime>
  <showVersionNumber>0</showVersionNumber>
  <autoUpdateInterval>86400</autoUpdateInterval>
  <autoUpdateDownloadPkg>1</autoUpdateDownloadPkg>
  <adminEmails>root@localhost</adminEmails>
  <adminRoot>\$SERVER_ROOT/admin/</adminRoot>
  <logging>
    <log>
      <fileName>\$SERVER_ROOT/logs/error.log</fileName>
      <logLevel>ERROR</logLevel>
      <debugLevel>0</debugLevel>
      <rollingSize>10M</rollingSize>
      <enableStderrLog>1</enableStderrLog>
      <enableAioLog>1</enableAioLog>
    </log>
    <accessLog>
      <fileName>\$SERVER_ROOT/logs/access.log</fileName>
      <rollingSize>10M</rollingSize>
      <keepDays>30</keepDays>
      <compressArchive>0</compressArchive>
    </accessLog>
  </logging>
  <indexFiles>index.html, index.php</indexFiles>
  <htAccess>
    <allowOverride>31</allowOverride>
    <accessFileName>.htaccess</accessFileName>
  </htAccess>
  <expires>
    <enableExpires>1</enableExpires>
    <expiresByType>image/*=A604800, text/css=A604800, application/x-javascript=A604800, application/javascript=A604800,font/*=A604800,application/x-font-ttf=A604800</expiresByType>
  </expires>
  <tuning>
    <eventDispatcher>best</eventDispatcher>
    <maxConnections>100000</maxConnections>
    <maxSSLConnections>100000</maxSSLConnections>
    <connTimeout>300</connTimeout>
    <maxKeepAliveReq>10000</maxKeepAliveReq>
    <smartKeepAlive>0</smartKeepAlive>
    <keepAliveTimeout>5</keepAliveTimeout>
    <sndBufSize>0</sndBufSize>
    <rcvBufSize>0</rcvBufSize>
    <maxReqURLLen>8192</maxReqURLLen>
    <maxReqHeaderSize>16380</maxReqHeaderSize>
    <maxReqBodySize>500M</maxReqBodySize>
    <maxDynRespHeaderSize>8K</maxDynRespHeaderSize>
    <maxDynRespSize>500M</maxDynRespSize>
    <maxCachedFileSize>4096</maxCachedFileSize>
    <totalInMemCacheSize>20M</totalInMemCacheSize>
    <maxMMapFileSize>256K</maxMMapFileSize>
    <totalMMapCacheSize>40M</totalMMapCacheSize>
    <useSendfile>1</useSendfile>
    <useAIO>1</useAIO>
    <AIOBlockSize>4</AIOBlockSize>
    <enableGzipCompress>1</enableGzipCompress>
    <enableDynGzipCompress>1</enableDynGzipCompress>
    <gzipCompressLevel>1</gzipCompressLevel>
    <compressibleTypes>text/*,application/x-javascript,application/javascript,application/xml,image/svg+xml,application/rss+xml</compressibleTypes>
    <gzipAutoUpdateStatic>1</gzipAutoUpdateStatic>
    <gzipStaticCompressLevel>6</gzipStaticCompressLevel>
    <gzipMaxFileSize>1M</gzipMaxFileSize>
    <gzipMinFileSize>300</gzipMinFileSize>
    <SSLCryptoDevice>null</SSLCryptoDevice>
  </tuning>
  <security>
    <fileAccessControl>
      <followSymbolLink>1</followSymbolLink>
      <checkSymbolLink>0</checkSymbolLink>
      <requiredPermissionMask>000</requiredPermissionMask>
      <restrictedPermissionMask>000</restrictedPermissionMask>
    </fileAccessControl>
    <perClientConnLimit>
      <staticReqPerSec>0</staticReqPerSec>
      <dynReqPerSec>0</dynReqPerSec>
      <outBandwidth>0</outBandwidth>
      <inBandwidth>0</inBandwidth>
      <softLimit>10000</softLimit>
      <hardLimit>10000</hardLimit>
      <gracePeriod>15</gracePeriod>
      <banPeriod>300</banPeriod>
    </perClientConnLimit>
    <CGIRLimit>
      <maxCGIInstances>200</maxCGIInstances>
      <minUID>11</minUID>
      <minGID>10</minGID>
      <priority>0</priority>
      <CPUSoftLimit>300</CPUSoftLimit>
      <CPUHardLimit>600</CPUHardLimit>
      <memSoftLimit>1450M</memSoftLimit>
      <memHardLimit>1500M</memHardLimit>
      <procSoftLimit>1400</procSoftLimit>
      <procHardLimit>1450</procHardLimit>
    </CGIRLimit>
    <censorshipControl>
      <enableCensorship>0</enableCensorship>
      <logLevel>0</logLevel>
      <defaultAction>deny,log,status:403</defaultAction>
      <scanPOST>1</scanPOST>
    </censorshipControl>
    <accessDenyDir>
      <dir>/</dir>
      <dir>/etc/*</dir>
      <dir>/dev/*</dir>
      <dir>$SERVER_ROOT/conf/*</dir>
      <dir>$SERVER_ROOT/admin/conf/*</dir>
    </accessDenyDir>
    <accessControl>
      <allow>ALL</allow>
    </accessControl>
  </security>
  <extProcessorList>
    <extProcessor>
      <type>lsapi</type>
      <name>lsphp${PHPVER}</name>
      <address>uds://tmp/lshttpd/lsphp${PHPVER}.sock</address>
      <maxConns>200</maxConns>
      <env>PHP_LSAPI_CHILDREN=200</env>
      <env>LSAPI_AVOID_FORK=1</env>
      <initTimeout>60</initTimeout>
      <retryTimeout>0</retryTimeout>
      <persistConn>1</persistConn>
      <respBuffer>0</respBuffer>
      <autoStart>3</autoStart>
      <path>/usr/local/lsws/lsphp${PHPVER}/bin/lsphp</path>
      <backlog>100</backlog>
      <instances>1</instances>
      <priority>0</priority>
      <memSoftLimit>2047M</memSoftLimit>
      <memHardLimit>2047M</memHardLimit>
      <procSoftLimit>1000</procSoftLimit>
      <procHardLimit>1000</procHardLimit>
    </extProcessor>
  </extProcessorList>
  <scriptHandlerList>
    <scriptHandler>
      <suffix>php</suffix>
      <type>lsapi</type>
      <handler>lsphp${PHPVER}</handler>
    </scriptHandler>
    <scriptHandler>
      <suffix>php7</suffix>
      <type>lsapi</type>
      <handler>lsphp${PHPVER}</handler>
    </scriptHandler>
  </scriptHandlerList>
  <cache>
    <storage>
      <cacheStorePath>/home/lscache/</cacheStorePath>
    </storage>
  </cache>
  <phpConfig>
    <maxConns>35</maxConns>
    <env>PHP_LSAPI_CHILDREN=35</env>
    <initTimeout>60</initTimeout>
    <retryTimeout>0</retryTimeout>
    <pcKeepAliveTimeout>1</pcKeepAliveTimeout>
    <respBuffer>0</respBuffer>
    <extMaxIdleTime>60</extMaxIdleTime>
    <memSoftLimit>2047M</memSoftLimit>
    <memHardLimit>2047M</memHardLimit>
    <procSoftLimit>400</procSoftLimit>
    <procHardLimit>500</procHardLimit>
  </phpConfig>
  <railsDefaults>
    <railsEnv>1</railsEnv>
    <maxConns>5</maxConns>
    <env>LSAPI_MAX_IDLE=60</env>
    <initTimeout>180</initTimeout>
    <retryTimeout>0</retryTimeout>
    <pcKeepAliveTimeout>60</pcKeepAliveTimeout>
    <respBuffer>0</respBuffer>
    <backlog>50</backlog>
    <runOnStartUp>1</runOnStartUp>
    <priority>3</priority>
    <memSoftLimit>2047M</memSoftLimit>
    <memHardLimit>2047M</memHardLimit>
    <procSoftLimit>400</procSoftLimit>
    <procHardLimit>500</procHardLimit>
  </railsDefaults>
  <virtualHostList>
    <virtualHost>
      <name>Example</name>
      <vhRoot>\$SERVER_ROOT/DEFAULT/</vhRoot>
      <configFile>\$VH_ROOT/conf/vhconf.xml</configFile>
      <allowSymbolLink>1</allowSymbolLink>
      <enableScript>1</enableScript>
      <restrained>0</restrained>
      <setUIDMode>0</setUIDMode>
      <chrootMode>0</chrootMode>
    </virtualHost>
  </virtualHostList>
  <listenerList>
    <listener>
      <name>HTTPS</name>
      <address>*:443</address>
      <binding>1</binding>
      <reusePort>0</reusePort>
      <secure>1</secure>
      <vhostMapList>
        <vhostMap>
          <vhost>Example</vhost>
          <domain>*</domain>
        </vhostMap>
      </vhostMapList>
      <keyFile>${LSDIR}/conf/example.key</keyFile>
      <certFile>${LSDIR}/conf/example.crt</certFile>
    </listener>
    <listener>
      <name>HTTP</name>
      <address>*:80</address>
      <secure>0</secure>
      <vhostMapList>
        <vhostMap>
          <vhost>Example</vhost>
          <domain>*</domain>
        </vhostMap>
      </vhostMapList>
    </listener>
  </listenerList>
  <vhTemplateList>
    <vhTemplate>
      <name>centralConfigLog</name>
      <templateFile>\$SERVER_ROOT/conf/templates/ccl.xml</templateFile>
      <listeners>HTTPS</listeners>
    </vhTemplate>
    <vhTemplate>
      <name>PHP_SuEXEC</name>
      <templateFile>\$SERVER_ROOT/conf/templates/phpsuexec.xml</templateFile>
      <listeners>HTTPS</listeners>
    </vhTemplate>
    <vhTemplate>
      <name>EasyRailsWithSuEXEC</name>
      <templateFile>\$SERVER_ROOT/conf/templates/rails.xml</templateFile>
      <listeners>HTTPS</listeners>
    </vhTemplate>
  </vhTemplateList>
</httpServerConfig>
END

    cat > ${LSVCONF} <<END
<?xml version="1.0" encoding="UTF-8"?>
<virtualHostConfig>
  <docRoot>${DOCROOT}/</docRoot>
  <enableGzip>1</enableGzip>
  <logging>
    <log>
      <useServer>0</useServer>
      <fileName>\$VH_ROOT/logs/error.log</fileName>
      <logLevel>DEBUG</logLevel>
      <rollingSize>10M</rollingSize>
    </log>
    <accessLog>
      <useServer>0</useServer>
      <fileName>\$VH_ROOT/logs/access.log</fileName>
      <rollingSize>10M</rollingSize>
      <keepDays>30</keepDays>
      <compressArchive>0</compressArchive>
    </accessLog>
  </logging>
  <index>
    <useServer>0</useServer>
    <indexFiles>index.php, index.html</indexFiles>
    <autoIndex>0</autoIndex>
    <autoIndexURI>/_autoindex/default.php</autoIndexURI>
  </index>
  <customErrorPages>
    <errorPage>
      <errCode>404</errCode>
      <url>/error404.html</url>
    </errorPage>
  </customErrorPages>
  <htAccess>
    <allowOverride>31</allowOverride>
    <accessFileName>.htaccess</accessFileName>
  </htAccess>
  <expires>
    <enableExpires>1</enableExpires>
  </expires>
  <security>
    <hotlinkCtrl>
      <enableHotlinkCtrl>0</enableHotlinkCtrl>
      <suffixes>gif,  jpeg,  jpg</suffixes>
      <allowDirectAccess>1</allowDirectAccess>
      <onlySelf>1</onlySelf>
    </hotlinkCtrl>
    <accessControl>
      <allow>*</allow>
    </accessControl>
    <realmList>
      <realm>
        <type>file</type>
        <name>SampleProtectedArea</name>
        <userDB>
          <location>\$VH_ROOT/conf/htpasswd</location>
          <maxCacheSize>200</maxCacheSize>
          <cacheTimeout>60</cacheTimeout>
        </userDB>
        <groupDB>
          <location>\$VH_ROOT/conf/htgroup</location>
          <maxCacheSize>200</maxCacheSize>
          <cacheTimeout>60</cacheTimeout>
        </groupDB>
      </realm>
    </realmList>
  </security>
  <cache>
    <cacheEngine>7</cacheEngine>
    <storage>
      <cacheStorePath>${DOCROOT}/lscache/</cacheStorePath>
      <litemage>0</litemage>
    </storage>
  </cache>
  <contextList>
    <context>
      <type>NULL</type>
      <uri>/phpmyadmin</uri>
      <location>/var/www/phpmyadmin</location>
      <allowBrowse>1</allowBrowse>
      <indexFiles>index.php</indexFiles>
      <accessControl>
      </accessControl>
      <rewrite>
        <enable>1</enable>
        <inherit>0</inherit>
      </rewrite>
      <addDefaultCharset>off</addDefaultCharset>
      <cachePolicy>
      </cachePolicy>
    </context>
  </contextList>
  <rewrite>
    <enable>1</enable>
    <logLevel>0</logLevel>
    <rules></rules>
  </rewrite>
  <frontPage>
    <enable>0</enable>
    <disableAdmin>0</disableAdmin>
  </frontPage>
  <awstats>
    <updateMode>0</updateMode>
    <workingDir>\$VH_ROOT/awstats</workingDir>
    <awstatsURI>/awstats/</awstatsURI>
    <siteDomain>localhost</siteDomain>
    <siteAliases>127.0.0.1 localhost</siteAliases>
    <updateInterval>86400</updateInterval>
    <updateOffset>0</updateOffset>
  </awstats>
</virtualHostConfig>
END
    if [ "${OSNAME}" = 'centos' ]; then
        sed -i "s/www-data/${USER}/g" ${LSCONF}
        sed -i "s|/usr/local/lsws/lsphp${PHP_P}${PHP_S}/bin/lsphp|/usr/bin/lsphp|g" ${LSCONF}
    fi
    gen_selfsigned_cert
}

landing_pg(){
    echoG 'Setting Landing Page'
    curl -s https://raw.githubusercontent.com/litespeedtech/ls-cloud-image/master/Static/wp-landing.html \
    -o ${DOCLAND}/index.html
    if [ -e ${DOCLAND}/index.html ]; then
        echoG 'Landing Page finished'
    else
        echoR "Please check Landing Page here ${DOCLAND}/index.html"
    fi
}

config_php(){
    echoG 'Updating PHP Paremeter'
    NEWKEY='max_execution_time = 360'
    linechange 'max_execution_time' ${PHPINICONF} "${NEWKEY}"

    NEWKEY='post_max_size = 100M'
    linechange 'post_max_size' ${PHPINICONF} "${NEWKEY}"

    NEWKEY='upload_max_filesize = 100M'
    linechange 'upload_max_filesize' ${PHPINICONF} "${NEWKEY}"
    echoG 'Finish PHP Paremeter'
}

ubuntu_config_memcached(){
    echoG 'Setting Memcached'
    service memcached stop > /dev/null 2>&1
    cat >> "${MEMCACHECONF}" <<END
-s /var/www/memcached.sock
-a 0770
-p /tmp/memcached.pid
END
    NEWKEY="-u ${USER}"
    linechange '\-u memcache' ${MEMCACHECONF} "${NEWKEY}"
    systemctl daemon-reload > /dev/null 2>&1
    change_owner /var/run/memcached
    change_owner ${WWWFD}
    service memcached stop > /dev/null 2>&1
    service memcached start > /dev/null 2>&1
}

ubuntu_config_redis(){
    echoG 'Setting Redis'
    service redis-server stop > /dev/null 2>&1
    NEWKEY="Group=${GROUP}"
    linechange 'Group=' ${REDISSERVICE} "${NEWKEY}"
    cat >> "${REDISCONF}" <<END
unixsocket /var/run/redis/redis-server.sock
unixsocketperm 775
END
    systemctl daemon-reload > /dev/null 2>&1
    service redis-server start > /dev/null 2>&1
}

centos_config_memcached(){
    echoG 'Setting memcached'
    service memcached stop > /dev/null 2>&1
    cat >> "${MEMCACHESERVICE}" <<END
[Unit]
Description=Memcached
Before=httpd.service
After=network.target
[Service]
User=${USER}
Group=${GROUP}
Type=simple
EnvironmentFile=-/etc/sysconfig/memcached
ExecStart=/usr/bin/memcached -u \$USER -p \$PORT -m \$CACHESIZE -c \$MAXCONN \$OPTIONS
[Install]
WantedBy=multi-user.target
END
        cat > "${MEMCACHECONF}" <<END
PORT="11211"
USER="${USER}"
MAXCONN="1024"
CACHESIZE="64"
OPTIONS="-s /var/www/memcached.sock -a 0770 -U 0 -l 127.0.0.1"
END
    ### SELINUX permissive Mode
    if [ ! -f /usr/sbin/semanage ]; then
        yum install -y policycoreutils-python-utils > /dev/null 2>&1
    fi
    semanage permissive -a memcached_t
    setsebool -P httpd_can_network_memcache 1
    systemctl daemon-reload > /dev/null 2>&1
    change_owner /var/run/memcached
    change_owner ${WWWFD}
    service memcached start > /dev/null 2>&1
}

centos_config_redis(){
    service redis stop > /dev/null 2>&1
    NEWKEY="Group=${GROUP}"
    linechange 'Group=' ${REDISSERVICE} "${NEWKEY}"
    cat >> "${REDISCONF}" <<END
unixsocket /var/run/redis/redis-server.sock
unixsocketperm 775
END
    systemctl daemon-reload > /dev/null 2>&1
    service redis start > /dev/null 2>&1
    echoG 'Finish Object Cache'
}

ubuntu_firewall_add(){
    echoG 'Setting Firewall'
    ufw status verbose | grep inactive > /dev/null 2>&1
    if [ $? = 0 ]; then
        for PORT in ${FIREWALLLIST}; do
            ufw allow ${PORT} > /dev/null 2>&1
        done
        echo "y" | ufw enable > /dev/null 2>&1
        ufw status | grep '80.*ALLOW' > /dev/null 2>&1
        if [ $? = 0 ]; then
            echoG 'firewalld rules setup success'
        else
            echoR 'Please check ufw rules'
        fi
    else
        echoG "ufw already enabled"
    fi
}

centos_firewall_add(){
    echoG 'Setting Firewall'
    if [ ! -e /usr/sbin/firewalld ]; then
        yum -y install firewalld > /dev/null 2>&1
    fi
    service firewalld start  > /dev/null 2>&1
    systemctl enable firewalld > /dev/null 2>&1
    for PORT in ${FIREWALLLIST}; do
        firewall-cmd --permanent --add-port=${PORT}/tcp > /dev/null 2>&1
    done
    firewall-cmd --reload > /dev/null 2>&1
    firewall-cmd --list-all | grep 80 > /dev/null 2>&1
    if [ $? = 0 ]; then
        echoG 'firewalld rules setup success'
    else
        echoR 'Please check firewalld rules'
    fi
}

add_profile(){
    echo "${1}" >> /etc/profile
}

setup_domain(){
    if [ -e ${CMDFD}/domainsetup.sh ]; then
        backup_old ${CMDFD}/domainsetup.sh
    fi
    cat >> ${CMDFD}/domainsetup.sh <<EOM
MY_DOMAIN=''
MY_DOMAIN2=''
DOCHM="${DOCROOT}"
LSDIR='/usr/local/lsws'
WEBCF="\${LSDIR}/DEFAULT/conf/vhconf.xml"
UPDATELIST='/var/lib/update-notifier/updates-available'
BOTCRON='/etc/cron.d/certbot'
WWW='FALSE'
UPDATE='TRUE'
OSNAME=''

echoY() {
    echo -e "\033[38;5;148m\${1}\033[39m"
}
echoG() {
    echo -e "\033[38;5;71m\${1}\033[39m"
}

check_os(){
    if [ -f /etc/redhat-release ] ; then
        OSNAME=centos
    elif [ -f /etc/lsb-release ] ; then
        OSNAME=ubuntu    
    elif [ -f /etc/debian_version ] ; then
        OSNAME=debian
    fi         
}

domainhelp(){
    echo -e "\nTo visit your apps by domain instead of IP, please enter a valid domain."
    echo -e "If you don't have one yet, you may cancel this process by pressing CTRL+C and continuing to SSH."
    echo -e "This prompt will open again the next time you log in, and will continue to do so until you finish the setup."
    echo -e "Please make sure the domain's DNS record has been properly pointed to this server."
    echo -e "\n(If you are using top level (root) domain, please include it with \033[38;5;71mwww.\033[39m so both www and root domain will be added)"
    echo -e "(ex. www.domain.com or sub.domain.com). Do not include http/s.\n"
}

restart_lsws(){
    ${LSDIR}/bin/lswsctrl restart >/dev/null
}   

domaininput(){
    printf "%s" "Your domain: "
    read MY_DOMAIN
    if [ -z "\${MY_DOMAIN}" ] ; then
    echo -e "\nPlease input a valid domain\n"
    exit
    fi
    echo -e "The domain you put is: \e[31m\${MY_DOMAIN}\e[39m"
    printf "%s"  "Please verify it is correct. [y/N] "
}

duplicateck(){
    grep "\${1}" \${2} >/dev/null 2>&1
}

domainadd(){
    CHECK_WWW=\$(echo \${MY_DOMAIN} | cut -c1-4)
    if [[ \${CHECK_WWW} == www. ]] ; then
        WWW='TRUE'
        #check if domain starts with www.
        MY_DOMAIN2=\$(echo \${MY_DOMAIN} | cut -c 5-)

    fi
}

domainverify(){
    curl -Is http://\${MY_DOMAIN}/ | grep -i LiteSpeed > /dev/null 2>&1
    if [ \$? = 0 ]; then
        echoG "\${MY_DOMAIN} check PASS"
    else
        echo "\${MY_DOMAIN} inaccessible, please verify."; exit 1    
    fi
    if [ \${WWW} = 'TRUE' ]; then
        curl -Is http://\${MY_DOMAIN2}/ | grep -i LiteSpeed > /dev/null 2>&1
        if [ \$? = 0 ]; then 
            echoG "\${MY_DOMAIN2} check PASS"   
        else
            echo "\${MY_DOMAIN2} inaccessible, please verify."; exit 1    
        fi    
    fi
}

main_domain_setup(){
    domainhelp
    while true; do
        domaininput
        read TMP_YN
        if [[ "\${TMP_YN}" =~ ^(y|Y) ]]; then
            domainadd
            break
        fi
    done    
}
emailinput(){
    CKREG="^[a-z0-9!#\\$%&'*+/=?^_\\`{|}~-]+(\.[a-z0-9!#\\$%&'*+/=?^_\\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\\$"
    printf "%s" "Please enter your E-mail: "
    read EMAIL
    if [[ \${EMAIL} =~ \${CKREG} ]] ; then
      echo -e "The E-mail you entered is: \e[31m\${EMAIL}\e[39m"
      printf "%s"  "Please verify it is correct: [y/N] "
    else
      echo -e "\nPlease enter a valid E-mail, exit setup\n"; exit 1
    fi  
}

certbothook(){
    sed -i 's/0.*/&  --deploy-hook "\/usr\/local\/lsws\/bin\/lswsctrl restart"/g' \${BOTCRON}
    grep 'restart' \${BOTCRON} > /dev/null 2>&1
    if [ \$? = 0 ]; then 
        echoG 'Certbot hook update success'
    else 
        echoY 'Please check certbot crond'
    fi        
}

lecertapply(){
    if [ \${WWW} = 'TRUE' ]; then
        certbot certonly --non-interactive --agree-tos -m \${EMAIL} --webroot -w \${DOCHM} -d \${MY_DOMAIN} -d \${MY_DOMAIN2}
    else
        certbot certonly --non-interactive --agree-tos -m \${EMAIL} --webroot -w \${DOCHM} -d \${MY_DOMAIN}
    fi    
    if [ \${?} -eq 0 ]; then
        SSL_NUM=\$(grep -n '<vhssl>' \${WEBCF} | awk -F ':' '{print $1}')
        sed -i "\${SSL_NUM}i'<certChain>1</certChain>'" \${WEBCF}
        sed -i "\${SSL_NUM}i'<certFile>/etc/letsencrypt/live/\${MY_DOMAIN}/fullchain.pem</certFile>'" \${WEBCF}
        sed -i "\${SSL_NUM}i'<keyFile>/etc/letsencrypt/live/\${MY_DOMAIN}/privkey.pem</keyFile>'" \${WEBCF} 
        echoG "\ncertificate has been successfully installed..."
    else
        echo "Oops, something went wrong..."
        exit 1
    fi
}

force_https() {
    duplicateck "RewriteCond %{HTTPS} on" "\${DOCHM}/.htaccess"
    if [ ${?} = 1 ]; then 
        echo "\$(echo '
### Forcing HTTPS rule start       
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
### Forcing HTTPS rule end
            ' | cat - \${DOCHM}/.htaccess)" > \${DOCHM}/.htaccess
    fi
    echoG "Force HTTPS rules has been added..."
}

endsetup(){
    sed -i '/domainsetup.sh/d' /etc/profile
}

aptupgradelist() {
    PACKAGE=\$(cat \${UPDATELIST} | awk '{print \$1}' | sed -n 2p)
    SECURITY=\$(cat \${UPDATELIST} | awk '{print \$1}' | sed -n 3p)
    if [ "\${PACKAGE}" = '0' ] && [ "\${SECURITY}" = '0' ]; then 
        UPDATE='FALSE'    
    fi    
}

yumupgradelist(){
    PACKAGE=\$(yum check-update | grep -v '*\|Load*\|excluded' | wc -l)
    if [ "\${PACKAGE}" = '0' ]; then 
        UPDATE='FALSE'
    fi    
}

aptgetupgrade() {
    apt-get update > /dev/null 2>&1
    echo -ne '#####                     (33%)\r'
    DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade > /dev/null 2>&1
    echo -ne '#############             (66%)\r'
    DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade > /dev/null 2>&1
    echo -ne '####################      (99%)\r'
    apt-get clean > /dev/null 2>&1
    apt-get autoclean > /dev/null 2>&1
    echo -ne '#######################   (100%)\r'
}

yumupgrade(){
    echo -ne '#                         (5%)\r'
    yum update -y > /dev/null 2>&1
    echo -ne '#######################   (100%)\r'
}
main_cert_setup(){
    printf "%s"   "Do you wish to issue a Let's encrypt certificate for this domain? [y/N]"
    read TMP_YN
    if [[ "\${TMP_YN}" =~ ^(y|Y) ]]; then
    #in case www domain , check both root domain and www domain accessibility.
        domainverify
        while true; do 
            emailinput
            read TMP_YN
            if [[ "\${TMP_YN}" =~ ^(y|Y) ]]; then
                lecertapply
                break
            fi
        done   
        echoG 'Update certbot cronjob hook'
        certbothook 
        printf "%s"   "Do you wish to force HTTPS rewrite rule for this domain? [y/N]"
        read TMP_YN
        if [[ "\${TMP_YN}" =~ ^(y|Y) ]]; then
            force_https
        fi
        restart_lsws
    fi        
}

main_upgrade(){
    if [ "\${OSNAME}" = 'ubuntu' ]; then 
        aptupgradelist
    else
        yumupgradelist
    fi    
    if [ "\${UPDATE}" = 'TRUE' ]; then
        printf "%s"   "Do you wish to update the system now? This will update the web server as well. [Y/n]? "
        read TMP_YN
        if [[ ! "\${TMP_YN}" =~ ^(n|N) ]]; then
            echoG "Update Starting..." 
            if [ "\${OSNAME}" = 'ubuntu' ]; then 
                aptgetupgrade
            else
                yumupgrade
            fi    
            echoG "\nUpdate complete" 
            echoG 'Your system is up to date'
        fi    
    else
        echoG 'Your system is up to date'
    fi        
}

main(){
    check_os
    main_domain_setup
    main_cert_setup
    main_upgrade
    endsetup
}
main
#rm -- "\$0"
exit 0          

EOM
    chmod +x ${CMDFD}/domainsetup.sh
    add_profile "sudo ${CMDFD}/domainsetup.sh"
}

rm_dummy(){
    remove_file /etc/update-motd.d/00-header
    remove_file /etc/update-motd.d/10-help-text
    remove_file /etc/update-motd.d/50-landscape-sysinfo
    remove_file /etc/update-motd.d/50-motd-news
    remove_file /etc/update-motd.d/51-cloudguest
    backup_old /etc/legal
}

set_banner(){
    echoG 'Set Banner'
    rm_dummy
    if [ ! -e ${BANNERDST} ]; then
        curl -s https://raw.githubusercontent.com/litespeedtech/ls-cloud-image/master/Banner/${BANNERNAME} \
        -o ${BANNERDST}
        if [ ${?} != 0 ];  then
            curl -s https://cloud.litespeed.sh/Banner/${BANNERNAME} -o ${BANNERDST}
        fi
        chmod +x ${BANNERDST}
    fi
}

filepermission_update(){
    chmod 600 ${HMPATH}/.db_password
    chmod 600 ${HMPATH}/.litespeed_password
}

renew_wpsalt(){
    for KEY in "'AUTH_KEY'" "'SECURE_AUTH_KEY'" "'LOGGED_IN_KEY'" "'NONCE_KEY'" "'AUTH_SALT'" "'SECURE_AUTH_SALT'" "'LOGGED_IN_SALT'" "'NONCE_SALT'"
    do
        gen_salt
        LINENUM=$(grep -n "${KEY}" ${WPCFPATH} | cut -d: -f 1)
        sed -i "${LINENUM}d" ${WPCFPATH}
        NEWSALT="define(${KEY}, '${GEN_SALT}');"
        sed -i "${LINENUM}i${NEWSALT}" ${WPCFPATH}
    done
}

renew_blowfish(){
    gen_salt
    LINENUM=$(grep -n "'blowfish_secret'" ${PHPMYCONF} | cut -d: -f 1)
    sed -i "${LINENUM}d" ${PHPMYCONF}
    NEW_SALT="\$cfg['blowfish_secret'] = '${GEN_SALT}';"
    sed -i "${LINENUM}i${NEW_SALT}" ${PHPMYCONF}
}

config_wp_main(){
    config_htaccess
    config_wp
    config_lscache
}

more_secure(){
    echoG "Update key"
    filepermission_update
    renew_wpsalt
    renew_blowfish
}

init_check(){
    check_os
    path_update
    provider_ck
    os_hm_path
}

init_setup(){
    gen_password
    gen_pass_file
    update_pass_file
    create_doc_fd
}

ubuntu_pkg_main(){
    ubuntu_pkg_basic
    ubuntu_pkg_postfix
    ubuntu_pkg_memcached
    ubuntu_pkg_redis
    ubuntu_pkg_phpmyadmin
    ubuntu_pkg_certbot
    ubuntu_pkg_system
    ubuntu_pkg_mariadb
}

ubuntu_main_install(){
    ubuntu_sysupdate
    ubuntu_pkg_main
    ubuntu_install_lsws
    ubuntu_install_php
    ubuntu_firewall_add
}

ubuntu_main_config(){
    setup_lsws
    cpu_process
    install_wordpress
    config_wp_main
    config_php
    ubuntu_config_memcached
    ubuntu_config_redis
    restart_lsws
    change_owner ${DOCROOT}
}

centos_pkg_main(){
    centos_pkg_basic
    centos_pkg_postfix
    centos_pkg_memcached
    centos_pkg_redis
    centos_pkg_phpmyadmin
    centos_pkg_certbot
    centos_pkg_system
    centos_pkg_mariadb
}

centos_main_install(){
    centos_sysupdate
    centos_pkg_main
    centos_install_lsws
    centos_install_php
    centos_firewall_add
}

centos_main_config(){
    setup_lsws
    cpu_process
    install_wordpress
    config_wp_main
    config_php
    centos_config_memcached
    centos_config_redis
    restart_lsws
    change_owner ${DOCROOT}
}

main(){
    init_check
    init_setup
    if [ ${OSNAME} = 'centos' ]; then
        centos_main_install
        centos_main_config
    else
        ubuntu_main_install
        ubuntu_main_config
    fi
    more_secure
    set_banner
}
main


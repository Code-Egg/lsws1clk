#!/bin/bash
# /***************************************************************
# LiteSpeed Latest
# WordPress Latest 
# Magento stable
# LSCache Latest 
# Memcached stable
# Redis stable
# PHPMyAdmin Latest
# ****************************************************************/
### Author: Cold Egg
 
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
LSUSER=''
LSPASS=''
LSGROUP=''
THEME='twentytwenty'
MARIAVER='10.9'
DF_PHPVER='83'
PHPVER='83'
PHP_M='8'
PHP_S='3'
FIREWALLLIST="22 80 443 7080 9200"
PHP_MEMORY='1999'
PHP_BIN="${LSDIR}/lsphp${PHPVER}/bin/php"
PHPINICONF=""
WPCFPATH="${DOCROOT}/wp-config.php"
REPOPATH=''
WP_CLI='/usr/local/bin/wp'
MA_COMPOSER='/usr/local/bin/composer'
LS_VER='6.3.1'
MA_VER='2.4.7'
#OC_VER='4.0.2.3'
OC_VER='3.0.4.0'
PS_VER='8.2'
COMPOSER_VER='2.4.2'
EMAIL='test@example.com'
APP_ACCT=''
APP_PASS=''
MA_BACK_URL=''
OC_BACK_URL='admin'
PS_BACK_URL='admin'
MEMCACHECONF=''
REDISSERVICE=''
REDISCONF=''
WPCONSTCONF="${DOCROOT}/wp-content/plugins/litespeed-cache/data/const.default.ini"
PLUGIN='litespeed-cache.zip'
BANNERNAME='litespeed'
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
BANNERDST=''
SKIP_WP=0
SKIP_REDIS=0
SKIP_MEMCA=0
app_skip=0
SAMPLE='false'
LICENSE='TRIAL'
UNINSTALL_ALL=''
OSNAMEVER=''
OSNAME=''
OSVER=''
DRUSHVER=12
APP='wordpress'
EPACE='        '
FPACE='    '

silent() {
  if [[ $debug ]] ; then
    "$@"
  else
    "$@" >/dev/null 2>&1
  fi
}

check_input(){
    if [ -z "${1}" ];then
        help_message 2
        exit 1
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
echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    case ${1} in
    "1")
        echoY 'Installation finished, please reopen the ssh console to see the banner.'
        if [ "${APP}" = 'opencart' ]; then
            echo "Follow https://docs.litespeedtech.com/lscache/lscoc/installation/ to seutp the cache."
        fi    
    ;;
    "2")
        echo 'This script is for testing porpuse, so we just use www-data as the user.'
        echo -e "\033[1mOPTIONS\033[0m"
        echow '-W, --wordpress'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh -W. If no input, script will still install wordpress by default"
        echow '-M, --magento'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh -M"
        echow '-M, --magento -S, --sample'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh -M -S, to install sample data"
        echow '-O, --opencart'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh -O"
        echow '-P, --prestashop'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh -P"
        echow '--mautic'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh -D"
        echow '-D, --drupal'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh --mautic"        
        echow '-L, --license'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh -L, to use specified LSWS serial number."        
        echow '--pure'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh --pure. It will install pure LSWS + PHP only."
        echow '--uninstall'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh --uninstall. It will uninstall pure LSWS + PHP only."      
        echow '--uninstall-all'
        echo "${EPACE}${EPACE}Example: lsws1clk.sh --uninstall-all. It will uninstall LSWS + PHP + all packages and document."          
        echow '-H, --help'
        echo "${EPACE}${EPACE}Display help and exit." 
        exit 0
    ;;    
    esac
}

uninstall_msg(){
    if [ ${UNINSTALL_ALL} = 'True' ]; then
        printf '\033[31mUninstall LSWS, PHP, MariaDB, Postfix, Certbot and Document Folder, do you still want to continue?[y/N]\033[0m '
    else
        printf '\033[31mUninstall LSWS and PHP, do you still want to continue?[y/N]\033[0m '
    fi    
    read answer
    echo

    if [ "$answer" != "Y" ] && [ "$answer" != "y" ] ; then
        echoG "OK, exit script!"
        exit 0
    else
        echoG "Ok, will start uninstall process .."
        sleep 5
    fi
}

get_ip(){
    MYIP=$(curl -s http://checkip.amazonaws.com || printf "0.0.0.0")
}

function fst_match_line
{
    FIRST_LINE_NUM=$(grep -n -m 1 "${1}" ${2} | awk -F ':' '{print $1}')
}
function fst_match_after
{
    FIRST_NUM_AFTER=$(tail -n +${1} ${2} | grep -n -m 1 ${3} | awk -F ':' '{print $1}')
}
function lst_match_line
{
    fst_match_after ${1} ${2} ${3}
    LAST_LINE_NUM=$((${FIRST_LINE_NUM}+${FIRST_NUM_AFTER}-1))
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
        OSVER=$(cat /etc/redhat-release | tr -dc '0-9.'|cut -d \. -f1)
        if [ ${?} = 0 ] ; then
            OSNAMEVER=CENTOS${OSVER}
            OSNAME=centos
            sudo wget -q -O - https://repo.litespeed.sh | sudo bash >/dev/null 2>&1
        fi
    elif [ -f /etc/lsb-release ] ; then
        OSNAME=ubuntu
        sudo wget -q -O - https://repo.litespeed.sh | sudo bash >/dev/null 2>&1
        UBUNTU_V=$(grep 'DISTRIB_RELEASE' /etc/lsb-release | awk -F '=' '{print substr($2,1,2)}')
        if [ ${UBUNTU_V} = 18 ] ; then
            OSNAMEVER=UBUNTU18
            OSVER=bionic
            MARIADBCPUARCH="arch=amd64"
        elif [ ${UBUNTU_V} = 20 ] ; then
            OSNAMEVER=UBUNTU20
            OSVER=focal
            MARIADBCPUARCH="arch=amd64"
        elif [ ${UBUNTU_V} = 22 ] ; then
            OSNAMEVER=UBUNTU22
            OSVER=jammy
            MARIADBCPUARCH="arch=amd64"
        elif [ ${UBUNTU_V} = 24 ] ; then
            OSNAMEVER=UBUNTU24
            OSVER=noble
            MARIADBCPUARCH="arch=amd64"            
        fi        
    elif [ -f /etc/debian_version ] ; then
        OSNAME=debian
        wget -O - http://rpms.litespeedtech.com/debian/enable_lst_debain_repo.sh | bash >/dev/null 2>&1
        DEBIAN_V=$(awk -F '.' '{print $1}' /etc/debian_version)
        if [ ${DEBIAN_V} = 9 ] ; then
            OSNAMEVER=DEBIAN9
            OSVER=stretch
            MARIADBCPUARCH="arch=amd64,i386"
        elif [ ${DEBIAN_V} = 10 ] ; then
            OSNAMEVER=DEBIAN10
            OSVER=buster
        elif [ ${DEBIAN_V} = 11 ] ; then
            OSNAMEVER=DEBIAN11
            OSVER=bullseye       
        elif [ ${DEBIAN_V} = 12 ] ; then
            OSNAMEVER=DEBIAN12
            OSVER=bookworm  	    
        fi
    fi
    if [ "${OSNAMEVER}" = "" ] ; then
        echoR "Sorry, currently one click installation only supports Centos(6-9), Debian(9-11) and Ubuntu(18,20,22,24)."
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
        PHPINICONF="${LSDIR}/lsphp${PHPVER}/etc/php.ini"
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
    if [ "${LSUSER}" = "" ]; then
        LSUSER="${USER}"
        LSGROUP="${GROUP}"
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

phpver_ck(){
    if [ "${APP}" = 'prestashop' ]; then
        echoG 'Current Prestashop support PHP 81 only, update to 81!'
        PHPVER='81'
        PHP_M='8'
        PHP_S='1'
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

var_update(){
    if [ "${APP}" = 'magento' ]; then 
        echoG Update MariaDB version to '10.6' for Magento. 
        MARIAVER='10.6'
    fi
}

ubuntu_var_update(){
    var_update
}

centos_var_update(){
    var_update
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
        APP_STR=$(shuf -i 100-999 -n1)
        APP_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')
        APP_ACCT="admin${APP_STR}"
        MA_BACK_URL="admin_${APP_STR}"
        LSPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')
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
    if [ "${APP}" = 'wordpress' ]; then
        cat >> ${ADMIN_PASS_PATH} <<EOM
admin_pass="${ADMIN_PASS}"
EOM
    elif [ "${APP}" = 'magento' ]; then
        cat >> ${ADMIN_PASS_PATH} <<EOM
admin_pass="${ADMIN_PASS}"
Magento_admin_url="${MA_BACK_URL}"
MagentO_admin="${APP_ACCT}"
Magento_passd="${APP_PASS}${APP_STR}"
doc_user_name="${LSUSER}"
doc_user_pass="${LSPASS}"
EOM
    elif [ "${APP}" = 'opencart' ]; then
        cat >> ${ADMIN_PASS_PATH} <<EOM
admin_pass="${ADMIN_PASS}"
opencart_admin_url="${OC_BACK_URL}"
opencart_admin="${APP_ACCT}"
opencart_passd="${APP_PASS}"
EOM
    elif [ "${APP}" = 'prestashop' ]; then
        cat >> ${ADMIN_PASS_PATH} <<EOM
admin_pass="${ADMIN_PASS}"
prestashop_admin_url="${PS_BACK_URL}"
prestashop_admin="${EMAIL}"
prestashop_passd="${APP_PASS}"
EOM
    elif [ "${APP}" = 'mautic' ]; then
        cat >> ${ADMIN_PASS_PATH} <<EOM
admin_pass="${ADMIN_PASS}"
EOM
    elif [ "${APP}" = 'drupal' ]; then
        cat >> ${ADMIN_PASS_PATH} <<EOM
admin_pass="${ADMIN_PASS}"
EOM
    fi
    if [ "${APP}" = 'wordpress' ]; then
        cat >> ${DB_PASS_PATH} <<EOM
root_mysql_pass="${MYSQL_ROOT_PASS}"
APP_DB_NAME="${APP}"
APP_DB_USER_NAME="${APP}"
APP_DB_pass="${MYSQL_USER_PASS}"
EOM
    elif [ "${APP}" = 'magento' ]; then
        cat >> ${DB_PASS_PATH} <<EOM
root_mysql_pass="${MYSQL_ROOT_PASS}"
APP_DB_NAME="${APP}"
APP_DB_USER_NAME="${APP}"
APP_DB_pass="${MYSQL_USER_PASS}"
EOM
    elif [ "${APP}" = 'opencart' ]; then
        cat >> ${DB_PASS_PATH} <<EOM
root_mysql_pass="${MYSQL_ROOT_PASS}"
APP_DB_NAME="${APP}"
APP_DB_USER_NAME="${APP}"
APP_DB_pass="${MYSQL_USER_PASS}"
EOM
    elif [ "${APP}" = 'prestashop' ]; then
        cat >> ${DB_PASS_PATH} <<EOM
root_mysql_pass="${MYSQL_ROOT_PASS}"
APP_DB_NAME="${APP}"
APP_DB_USER_NAME="${APP}"
APP_DB_pass="${MYSQL_USER_PASS}"
EOM
    elif [ "${APP}" = 'mautic' ]; then
        cat >> ${DB_PASS_PATH} <<EOM
root_mysql_pass="${MYSQL_ROOT_PASS}"
APP_DB_NAME="${APP}"
APP_DB_USER_NAME="${APP}"
APP_DB_pass="${MYSQL_USER_PASS}"
EOM
elif [ "${APP}" = 'drupal' ]; then
        cat >> ${DB_PASS_PATH} <<EOM
root_mysql_pass="${MYSQL_ROOT_PASS}"
APP_DB_NAME="${APP}"
APP_DB_USER_NAME="${APP}"
APP_DB_pass="${MYSQL_USER_PASS}"
EOM
    fi
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

test_page(){
    local URL=$1
    local KEYWORD=$2
    local PAGENAME=$3

    rm -rf tmp.tmp
    wget --no-check-certificate -O tmp.tmp  $URL >/dev/null 2>&1
    grep "$KEYWORD" tmp.tmp  >/dev/null 2>&1

    if [ $? != 0 ] ; then
        echoR "Error: $PAGENAME failed."
        TESTGETERROR=yes
    else
        echoG "OK: $PAGENAME passed."
    fi
    rm tmp.tmp
}

test_ols_admin(){
    test_page https://localhost:7080/ "LiteSpeed WebAdmin" "test webAdmin page"
}

test_wp_page(){
    test_page http://localhost:80/  'data-continue' "test WordPress HTTP page"
    test_page https://localhost:443/  'data-continue' "test WordPress HTTPS page"
}

test_magento_page(){
    test_page http://localhost:80/  'Magento, Inc' "test Magento HTTP page"
    test_page https://localhost:443/  'Magento, Inc' "test Magento HTTPS page"
    cd ${DOCROOT}; rm -rf var/cache/* var/page_cache/* var/generation/*
}
test_opencart_page(){
    test_page http://localhost:80/  'OpenCart' "test OpenCart HTTP page"
    #test_page https://localhost:443/  'Opencart' "test Opencart HTTPS page"
}
test_prestashop_page(){
    test_page http://localhost:80/  'PrestaShop' "test PrestaShop HTTP page"
    test_page https://localhost:443/  'PrestaShop' "test PrestaShop HTTPS page"
}
test_mautic_page(){
    test_page http://localhost:80/  'mautic' "test Mautic HTTP page"
    test_page https://localhost:443/  'mautic' "test Mautic HTTPS page"
}

ubuntu_pkg_basic(){
    echoG 'Install basic packages'
    silent apt-get install lsb-release -y
    silent apt-get install curl wget unzip -y
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
    if [ ${?} != 0 ]; then
        echoR 'Memcache install failed, please  check!'
        SKIP_MEMCA=1
    else    
        systemctl start memcached > /dev/null 2>&1
        systemctl enable memcached > /dev/null 2>&1
    fi    
}

ubuntu_pkg_redis(){
    echoG 'Install Redis'
    apt-get -y install redis > /dev/null 2>&1
    if [ ${?} != 0 ]; then
        echoR 'Redis install failed, please check!'
        SKIP_REDIS=1
    else    
        systemctl start redis > /dev/null 2>&1
    fi
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

ubuntu_pkg_ufw(){
    if [ ! -f /usr/sbin/ufw ]; then
        echoG 'Install ufw'
        apt-get install ufw -y > /dev/null 2>&1
    fi    
}

ubuntu_pkg_certbot(){
    echoG "Install CertBot"
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
    apt list --installed 2>/dev/null | grep mariadb-server >/dev/null 2>&1
    if [ ${?} = 0 ]; then
        echoG "Mariadb ${MARIAVER} already installed"
    else
        
        if [ "$OSNAMEVER" = "DEBIAN8" ]; then
            silent ${APT} -y -f install software-properties-common
        elif [ "$OSNAME" = "debian" ]; then
            silent ${APT} -y -f install software-properties-common gnupg
        elif [ "$OSNAME" = "ubuntu" ]; then
            silent ${APT} -y -f install software-properties-common
        fi
        MARIADB_KEY='/usr/share/keyrings/mariadb.gpg'
        wget -q -O- https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor > "${MARIADB_KEY}"
        if [ ! -e "${MARIADB_KEY}" ]; then 
            echoR "${MARIADB_KEY} does not exist, please check the key, exit!"
            exit 1
        fi    

        echoG "${FPACE} - Add MariaDB repo"
        if [ -e /etc/apt/sources.list.d/mariadb.list ]; then  
            grep -Fq  "mirror.mariadb.org" /etc/apt/sources.list.d/mariadb.list >/dev/null 2>&1
            if [ $? != 0 ] ; then
                echo "deb [$MARIADBCPUARCH signed-by=${MARIADB_KEY}] http://mirror.mariadb.org/repo/$MARIAVER/$OSNAME $OSVER main"  > /etc/apt/sources.list.d/mariadb.list
            fi
        else 
            echo "deb [$MARIADBCPUARCH signed-by=${MARIADB_KEY}] http://mirror.mariadb.org/repo/$MARIAVER/$OSNAME $OSVER main"  > /etc/apt/sources.list.d/mariadb.list
        fi
        echoG "${FPACE} - Update packages"
        apt-get update > /dev/null 2>&1
        echoG "${FPACE} - Install MariaDB"
        silent apt-get -y -f install mariadb-server
        if [ $? != 0 ] ; then
            echoR "An error occured during installation of MariaDB. Please fix this error and try again."
            echoR "You may want to manually run the command 'apt-get -y -f --allow-unauthenticated install mariadb-server' to check. Aborting installation!"
            exit 1
        fi
        echoG "${FPACE} - Start MariaDB"
        service mysql start    
    fi    
}

centos_pkg_basic(){
    echoG 'Install basic packages'
    silent yum install epel-release -y
    silent yum update -y
    silent yum install curl yum-utils wget unzip libnsl -y
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
    if [ ${?} != 0 ]; then
        echoR 'Memcache install failed, please  check!'
        SKIP_MEMCA=1
    else        
        systemctl start memcached > /dev/null 2>&1
        systemctl enable memcached > /dev/null 2>&1
    fi    
}

centos_pkg_redis(){
    echoG 'Install Redis'
    yum -y install redis > /dev/null 2>&1
    if [ ${?} != 0 ]; then
        echoR 'Redis install failed, please check!'
        SKIP_REDIS=1
    else    
        systemctl start redis > /dev/null 2>&1
    fi    
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
        if [ "$OSTYPE" != "x86_64" ] ; then
            CENTOSVER=centos$OSVER-x86
        else
            CENTOSVER=centos$OSVER-amd64
        fi
        if [ "$OSNAMEVER" = "CENTOS8" ] || [ "$OSNAMEVER" = "CENTOS9" ]; then
            rpm --quiet --import https://downloads.mariadb.com/MariaDB/MariaDB-Server-GPG-KEY
            cat > ${REPOPATH}/MariaDB.repo <<END
[mariadb]
name = MariaDB
baseurl = https://downloads.mariadb.com/MariaDB/mariadb-$MARIAVER/yum/rhel/\$releasever/\$basearch
gpgkey = file:///etc/pki/rpm-gpg/MariaDB-Server-GPG-KEY
gpgcheck=1
enabled = 1
module_hotfixes = 1
END
        else
            cat > ${REPOPATH}/MariaDB.repo <<END
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/$MARIAVER/$CENTOSVER
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
END
        fi 
        fi
        echoG "${FPACE} - Install MariaDB"
        if [ "$OSNAMEVER" = "CENTOS8" ] || [ "$OSNAMEVER" = "CENTOS9" ]; then
            silent yum install -y boost-program-options
            silent yum --disablerepo=AppStream install -y MariaDB-server MariaDB-client
        else
            silent yum -y install MariaDB-server MariaDB-client
        fi
        if [ $? != 0 ] ; then
            echoR "An error occured during installation of MariaDB. Please fix this error and try again."
            echoR "You may want to manually run the command 'yum -y install MariaDB-server MariaDB-client' to check. Aborting installation!"
            exit 1
        fi
        echoG "${FPACE} - Start MariaDB"
        if [ "$OSNAMEVER" = "CENTOS9" ] || [ "$OSNAMEVER" = "CENTOS8" ] || [ "$OSNAMEVER" = "CENTOS7" ] ; then
            silent systemctl enable mariadb
            silent systemctl start  mariadb
        else
            service mysql start
        fi    
}

set_mariadb_root(){
    SQLVER=$(mysql -u root -e 'status' | grep 'Server version')
    SQLVER_1=$(echo ${SQLVER} | awk '{print substr ($3,1,2)}')
    SQLVER_2=$(echo ${SQLVER} | awk -F '.' '{print $2}')
    if (( ${SQLVER_1} >=11 )); then
        mysql -u root -e "ALTER USER root@localhost IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASS}');"
    elif (( ${SQLVER_1} ==10 )) && (( ${SQLVER_2} >=4 && ${SQLVER_2}<=9 )); then
        mysql -u root -e "ALTER USER root@localhost IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASS}');"
    elif (( ${SQLVER_1} ==10 )) && (( ${SQLVER_2} ==3 )); then
        mysql -u root -e "UPDATE mysql.user SET authentication_string = '' WHERE user = 'root';"
        mysql -u root -e "UPDATE mysql.user SET plugin = '' WHERE user = 'root';"  
    elif (( ${SQLVER_1} == 10 )) && (( ${SQLVER_2} == 2 )); then
        mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MYSQL_ROOT_PASS}');"
    else
        echo 'Please check DB version!'
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
    wget -q --no-check-certificate https://www.litespeedtech.com/packages/6.0/lsws-${LS_VER}-ent-x86_64-linux.tar.gz -P ${CMDFD}/
    silent tar -zxvf lsws-*-ent-x86_64-linux.tar.gz
    rm -f lsws-*.tar.gz
    cd lsws-*
    if [ "${LICENSE}" == 'TRIAL' ]; then 
        wget -q --no-check-certificate http://license.litespeedtech.com/reseller/trial.key
    else 
        echo "${LICENSE}" > serial.no
    fi    
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

uninstall_lsws(){
    echoG 'Uninstall LiteSpeed Web Server'
    if [ -d ${LSDIR} ]; then
        silent systemctl stop lsws
        rm -rf ${LSDIR}
    fi    

}

ubuntu_uninstall_lsws(){
    uninstall_lsws
}

centos_uninstall_lsws(){
    uninstall_lsws
}

ubuntu_install_php(){
    echoG 'Install PHP & Packages for LSWS'
    ubuntu_reinstall "lsphp${PHPVER}"
    for PKG in '' -common -curl -gd -json -mysql -imagick -imap -memcached -msgpack -redis -mcrypt -opcache -intl; do
        /usr/bin/apt ${OPTIONAL} install -y lsphp${PHPVER}${PKG} >/dev/null 2>&1
    done
    rm -f /usr/bin/php
}

centos_install_php(){
    echoG 'Install PHP & Packages'
    for PKG in '' -common -gd -pdo -imap -mbstring -imagick -mysqlnd -bcmath -soap -memcached -mcrypt -process -opcache -redis -json -xml -xmlrpc -intl; do
        /usr/bin/yum install lsphp${PHPVER}${PKG} -y >/dev/null 2>&1
    done
    rm -f /usr/bin/php
}

ubuntu_uninstall_php(){
    echoG 'Uninstall LSPHP'
    apt-get purge --auto-remove lsphp* -y >/dev/null 2>&1
}

centos_uninstall_php(){
    echoG 'Uninstall LSPHP'
    yum remove lsphp* -y >/dev/null 2>&1
}


ubuntu_uninstall_pkg(){
    echoG 'Uninstall packages'
    apt-get purge --auto-remove mariadb-server certbot postfix -y >/dev/null 2>&1
    rm -rf /var/lib/mysql/ /etc/mysql/
}

centos_uninstall_pkg(){
    echoG 'Uninstall packages'
    yum remove MariaDB-server MariaDB-client certbot postfix -y >/dev/null 2>&1
    rm -rf /var/lib/mysql/ /etc/mysql/
}

ubuntu_uninstall_doc(){
    echoG 'Uninstall document'
    rm -rf ${WWWFD}
    rm -f ${HMPATH}/.db_password
    rm -f ${HMPATH}/.litespeed_password
}

centos_uninstall_doc(){
    echoG 'Uninstall document'
    rm -rf ${WWWFD}
    rm -f ${HMPATH}/.db_password
    rm -f ${HMPATH}/.litespeed_password    
}

set_mariadb_user(){
    mysql -u root -p${MYSQL_ROOT_PASS} -e "DELETE FROM mysql.user WHERE User = '${WP_USER}';"
    mysql -u root -p${MYSQL_ROOT_PASS} -e "CREATE DATABASE IF NOT EXISTS ${WP_NAME};"
    if [ ${?} = 0 ]; then
        mysql -u root -p${MYSQL_ROOT_PASS} -e "grant all privileges on ${WP_NAME}.* to '${WP_USER}'@'localhost' identified by '${WP_PASS}';"
        mysql -u ${WP_USER} -p${WP_PASS} -e 'status' | grep 'Server version' >/dev/null
        if [ ${?} != 0 ]; then
            echoR "Failed to create DB user, please check. Skip script!"
            exit 1
        fi
    else
        echoR "Failed to create database ${WP_NAME}. It may already exist. Skip WordPress setup!"
        SKIP_WP=1
    fi
}

user_for_magento(){
    grep "${LSUSER}" /etc/passwd >/dev/null
    if [ ${?} = 0 ]; then
        if [ "${OSNAME}" = "centos" ]; then
            LINENUM=$(grep -n -m1 nobody /etc/passwd | awk -F ':' '{print $1}')
            sed -i "${LINENUM}s|sbin/nologin|/bin/bash|" /etc/passwd   
        elif [ "${OSNAME}" = 'ubuntu' ] || [ "${OSNAME}" = 'debian' ]; then
            LINENUM=$(grep -n -m1 www-data /etc/passwd | awk -F ':' '{print $1}')
            sed -i "${LINENUM}s|/usr/sbin/nologin|/bin/bash|" /etc/passwd    
        fi
    else
        useradd "${LSUSER}"
        echo -e "${LSPASS}\n${LSPASS}" | passwd "${LSUSER}"
        usermod -aG "${LSGROUP}" "${USER}"
        usermod -aG "${GROUP}" "${USER}"
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

install_composer(){
    if [ -e ${MA_COMPOSER} ]; then
        echoG 'Composer already exist'
    else
        wget -qO composer-setup.php https://getcomposer.org/installer
        php composer-setup.php --version ${COMPOSER_VER}
        mv composer.phar ${MA_COMPOSER}
        export COMPOSER_ALLOW_SUPERUSER=1
        silent composer --version
        if [ ${?} != 0 ]; then
            echoR 'Issue with composer, Please check!'
            exit 1
        fi        
    fi    
}

install_drush(){
    echoG 'Install Drush'
    composer global require drush/drush:^${DRUSHVER} --with-all-dependencies -W -q
    wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar -q
    chmod +x drush.phar
    if [ ! -e /usr/local/bin/drush ]; then 
        mv drush.phar /usr/local/bin/drush
    fi
    if [ ! -e /usr/bin/drush ]; then 
        ln -s /usr/local/bin/drush /usr/bin/drush
    fi     
    #drush --version
}

ck_svr_elk_ram(){
    echoG 'Check if memory size is enough.'
    PHYMEM=$(LANG=C free|awk '/^Mem:/{print $2}')
    if [ ${PHYMEM} -lt 3800000 ]; then 
        echoR "With Elasticsearch service, memory size ${PHYMEM} is too small"
        printf "%s"  "Do you still want to continue. [y/N] "
        read TMP_YN
        if [[ "${TMP_YN}" =~ ^(y|Y) ]]; then
            echo ''
        else
            exit 1    
        fi
    fi
}

ubuntu_pkg_elasticsearch(){
    if [ "${APP}" = 'magento' ]; then
        echoG 'Install elasticsearch'
        ck_svr_elk_ram
        if [ ! -e /etc/elasticsearch ]; then    
            curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add - >/dev/null 2>&1
            echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list >/dev/null 2>&1
            apt update >/dev/null 2>&1
            apt install elasticsearch -y >/dev/null 2>&1
            echoG 'Start elasticsearch service'
            systemctl start elasticsearch.service >/dev/null 2>&1
            if [ ${?} != 0 ]; then
                echoR 'Issue with elasticsearch package, Please check!'
                exit 1
            fi
            systemctl enable elasticsearch >/dev/null 2>&1
        else
            echoG 'Elasticsearch already exist, skip!'
        fi     
        echoG 'Install elasticsearch finished'
    fi
}

centos_pkg_elasticsearch(){
    if [ "${APP}" = 'magento' ]; then
        ck_svr_elk_ram
        echoG 'Install elasticsearch' 
        if [ ! -e /etc/elasticsearch ]; then 
            rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch >/dev/null 2>&1
            cat << EOM > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOM
            yum install elasticsearch -y >/dev/null 2>&1
            systemctl start elasticsearch.service >/dev/null 2>&1
            if [ ${?} != 0 ]; then
                echoR 'Issue with elasticsearch package, Please check!'
                exit 1
            fi
            systemctl enable elasticsearch.service >/dev/null 2>&1 
        else
            echoG 'Elasticsearch already exist, skip!'
        fi
        echoG 'Install elasticsearch finished'
    fi    
}    

set_db_user(){
    silent mysql -u root -e 'status'
    if [ ${?} = 0 ]; then
        set_mariadb_root
        WP_NAME="${APP}"
        WP_USER="${APP}"      
        WP_PASS="${MYSQL_USER_PASS}"
        cd ${DOCROOT}
        set_mariadb_user
    else
        echoR 'DB access failed, skip app setup!'
        app_skip=1
    fi    
}

install_wordpress(){
    if [ -e ${WPCFPATH} ]; then
        echoY 'WordPress already exist, skip WordPress setup !'
    else
        install_WP_CLI
        set_db_user
        if [ ${app_skip} = 0 ]; then
             echoG 'Install WordPress...'
            if [ ${SKIP_WP} = 0 ]; then
                wget -q --no-check-certificate https://wordpress.org/latest.zip
                unzip -q latest.zip
                mv wordpress/* ${DOCROOT}
                rm -rf latest.zip wordpress
            fi
        fi
    fi
}

install_magento(){
    if [ -e ${DOCROOT}/index.php ]; then
        echoR "${DOCROOT}/index.php exist, skip."
    else
        install_composer
        rm -f ${MA_VER}.tar.gz
        wget -q --no-check-certificate https://github.com/magento/magento2/archive/${MA_VER}.tar.gz
        if [ ${?} != 0 ]; then
            echoR "Download ${MA_VER}.tar.gz failed, abort!"
            exit 1
        fi    
        tar -zxf ${MA_VER}.tar.gz
        mv magento2-${MA_VER}/* ${DOCROOT}
        mv magento2-${MA_VER}/.editorconfig ${DOCROOT}
        mv magento2-${MA_VER}/.htaccess ${DOCROOT}
        mv magento2-${MA_VER}/.php-cs-fixer.dist.php ${DOCROOT}
        mv magento2-${MA_VER}/.user.ini ${DOCROOT}
        rm -rf ${MA_VER}.tar.gz magento2-${MA_VER}
        echoG 'Finished Composer install'
        user_for_magento
        set_db_user
        if [ ${app_skip} = 0 ]; then
            echoG 'Run Composer install'
            echo -ne '\n' | composer install
            echoG 'Composer install finished'
            if [ ! -e ${DOCROOT}/vendor/autoload.php ]; then
                echoR "/vendor/autoload.php not found, need to check"
                sleep 10
                ls ${DOCROOT}/vendor/
            fi    
            echoG 'Install Magento...'
            ./bin/magento setup:install \
                --db-name=${WP_NAME} \
                --db-user=${WP_USER} \
                --db-password=${WP_PASS} \
                --admin-user=${APP_ACCT} \
                --admin-password=${APP_PASS}${APP_STR} \
                --admin-email=${EMAIL} \
                --admin-firstname=test \
                --admin-lastname=account \
                --language=en_US \
                --currency=USD \
                --timezone=America/Chicago \
                --use-rewrites=1 \
                --backend-frontname=${MA_BACK_URL}
            if [ ${?} = 0 ]; then
                echoG 'Magento install finished'
            else
                echoR 'Not working properly!'    
            fi 
            change_owner ${DOCROOT}
        fi    
    fi
}

tmp_fix_serialize(){
    SERIALIZE_JSON="${DOCROOT}/lib/internal/Magento/Framework/Serialize/Serializer/Json.php"
    if [ -f ${SERIALIZE_JSON} ]; then
        echoG "Back up ${SERIALIZE_JSON}"
        cp ${SERIALIZE_JSON} ${SERIALIZE_JSON}.bk
        grep '(json_last_error' ${SERIALIZE_JSON} >/dev/null 2>&1
        if [ ${?} -eq 0 ] ; then
            echo 'Remove json_last_error condition'
            fst_match_line '(json_last_error' ${SERIALIZE_JSON}
            lst_match_line ${FIRST_LINE_NUM} ${SERIALIZE_JSON} '}'
            sed -i "${FIRST_LINE_NUM},${LAST_LINE_NUM}d" ${SERIALIZE_JSON}
        else
            echo 'Already disabled for json_last_error'
        fi
    fi
}

install_ma_sample(){
    if [ "${SAMPLE}" = 'true' ]; then
        echoG 'Start installing Magento 2 sample data'
        tmp_fix_serialize
        git clone https://github.com/magento/magento2-sample-data.git
        cd magento2-sample-data
        php -f dev/tools/build-sample-data.php -- --ce-source="${DOCROOT}"
        echoG 'Update permission'
        change_owner ${DOCROOT}; cd ${DOCROOT}
        find . -type d -exec chmod g+ws {} +
        rm -rf var/cache/* var/page_cache/* var/generation/*
        echoG 'Upgrade'
        su ${LSUSER} -c 'php bin/magento setup:upgrade'
        echoG 'Deploy static content'
        su ${LSUSER} -c 'php bin/magento setup:static-content:deploy'
        echoG 'End installing Magento 2 sample data'
    fi
}

install_opencart(){
    set_db_user
    if [ ${app_skip} = 0 ]; then
        echoG 'Install OpenCart...'
        get_ip    
        wget -q https://github.com/opencart/opencart/releases/download/${OC_VER}/opencart-${OC_VER}.zip
        unzip -q opencart-${OC_VER}.zip
        mv opencart-${OC_VER}/upload .
        cp upload/config-dist.php upload/config.php
        cp upload/admin/config-dist.php upload/admin/config.php
        php upload/install/cli_install.php install \
            --db_hostname localhost \
            --db_username ${WP_USER} \
            --db_password ${WP_PASS} \
            --db_database ${WP_NAME} \
            --username ${APP_ACCT} \
            --password ${APP_PASS} \
            --email ${EMAIL} \
            --http_server http://${MYIP}:80/
        cp -iR ${DOCROOT}/upload/* ${DOCROOT}
    fi
}    

install_prestashop(){
    set_db_user
    if [ ${app_skip} = 0 ]; then
        echoG 'Install Prestashop...'
        get_ip
        wget -q https://github.com/PrestaShop/PrestaShop/releases/download/${PS_VER}/prestashop_${PS_VER}.zip
        unzip -q prestashop_${PS_VER}.zip; mv index.php /tmp/
        unzip -q prestashop.zip
        php install/index_cli.php \
            --domain="${MYIP}" \
            --db_server=127.0.0.1 \
            --db_name=${WP_NAME} \
            --db_user=${WP_USER} \
            --db_password=${WP_PASS} \
            --email=${EMAIL} \
            --password=${APP_PASS};
    fi
    mv install install.bk
}  



install_mautic(){
    install_composer
    set_db_user
    echoG 'Install Mautic...'
    git clone https://github.com/mautic/mautic.git .
    if [ ${app_skip} = 0 ]; then
        echoG 'Run Composer install'
        composer install
        echoG 'Composer install finished'
        echoG 'No CLI for the installation, please visit and finish the Mautic installation from the browser!'
    fi
}

dl_drupal_cache(){
    echoG 'Download Drupal Cache Plugin'
    if [ -d "${DOCROOT}/web/modules" ] && [ ! -d "${DOCROOT}/web/modules/lscache-drupal-master" ]; then 
        cd ${DOCROOT}/web/modules
        wget https://github.com/litespeedtech/lscache-drupal/archive/master.zip -O master.zip -q 
        unzip -qq master.zip
        rm -f master.zip
    else
        echo 'Skip cache plugin download!'    
    fi
}

install_drupal(){
    install_composer
    install_drush
    set_db_user
    echoG 'Install Drupal...'
    echoG 'Download Drupal CMS'
    if [ ! -d "${DOCROOT}/sites" ]; then
        composer create-project --no-interaction drupal/recommended-project ${DOCROOT} >/dev/null 2>&1
        cd ${DOCROOT} && composer require drush/drush -q
    else
        echo 'Drupal already exist, abort!'
        exit 1
    fi
    dl_drupal_cache
    cd ${DOCROOT}
    export COMPOSER_ALLOW_SUPERUSER=1
    echo '############# Auto-Installation (one time only) ###############'
    sudo vendor/bin/drush -y site-install standard --db-url=mysql://drupal:${app_mysql_pass}@127.0.0.1/drupal --account-name=admin --account-pass=${ADMIN_PASS}
    sudo vendor/bin/drush -y config-set system.performance css.preprocess 0 -q
    sudo vendor/bin/drush -y config-set system.performance js.preprocess 0 -q
    sudo vendor/bin/drush cache-rebuild -q
    sudo sed -i 's|<docRoot>/var/www/html/</docRoot>|<docRoot>/var/www/html/web/</docRoot>|g' ${LSVCONF} >/dev/null
    sudo vendor/bin/drush pm:enable lite_speed_cache
    sudo chmod 777 ${DOCROOT}/web/sites/default/files
}

fix_opencart_image(){
    if [ "${APP}" = 'opencart' ]; then
        cp -r ${DOCROOT}/upload/image/cache/* ${DOCROOT}/image/cache/
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

config_wp_htaccess(){
    echoG 'Setting WordPress htaccess'
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

config_ma_htaccess(){
    echoG 'Setting Magento htaccess'
    if [ ! -f ${DOCROOT}/.htaccess ]; then
        echoR "${DOCROOT}/.htaccess not exist, skip"
    else
        sed -i '1i\<IfModule LiteSpeed>LiteMage on</IfModule>\' ${DOCROOT}/.htaccess
    fi
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

get_theme_name(){
    THEME_NAME=$(grep WP_DEFAULT_THEME ${DOCROOT}/wp-includes/default-constants.php | grep -v '!' | awk -F "'" '{print $4}')
    echo "${THEME_NAME}" | grep 'twenty' >/dev/null 2>&1
    if [ ${?} = 0 ]; then
        THEME="${THEME_NAME}"
    fi
}

install_lscache(){
    cd ${SCRIPTPATH}
    backup_old ${WPCONSTCONF}
    cp conf/const.default.ini ${DOCROOT}/wp-content/plugins/litespeed-cache/data/

    THEME_PATH="${DOCROOT}/wp-content/themes/${THEME}"
    if [ ! -f ${THEME_PATH}/functions.php ]; then
        cat >> "${THEME_PATH}/functions.php" <<END
<?php
require_once( WP_CONTENT_DIR.'/../wp-admin/includes/plugin.php' );
\$path = 'litespeed-cache/litespeed-cache.php' ;
if (!is_plugin_active( \$path )) {
    activate_plugin( \$path ) ;
    rename( __FILE__ . '.bk', __FILE__ );
}
END
    elif [ ! -f ${THEME_PATH}/functions.php.bk ]; then
        cp ${THEME_PATH}/functions.php ${THEME_PATH}/functions.php.bk
        cked
        ed ${THEME_PATH}/functions.php << END >>/dev/null 2>&1
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

clean_magento_cache(){
    cd ${DOCROOT}
    su ${LSUSER} -c "php bin/magento cache:flush" >/dev/null 2>&1
    su ${LSUSER} -c "php bin/magento cache:clean" >/dev/null 2>&1
    change_owner ${DOCROOT}
}

install_litemage(){
    echoG '[Start] Install LiteMage'
    echo -ne '\n' | composer require litespeed/module-litemage
    check_els_service
    su ${LSUSER} -c "php bin/magento deploy:mode:set developer;"
    su ${LSUSER} -c "php bin/magento module:enable Litespeed_Litemage;"
    su ${LSUSER} -c "php bin/magento setup:upgrade;"
    su ${LSUSER} -c "php bin/magento setup:di:compile;"
    check_els_service 
    su ${LSUSER} -c "php bin/magento deploy:mode:set production;"
    check_els_service
    echoG '[End] LiteMage install'
    clean_magento_cache
}

config_litemage(){
    echoG 'Set full_page_cache to Litemage'
    bin/magento config:set --scope=default --scope-code=0 system/full_page_cache/caching_application 168
    echoG 'Flush cache'
    bin/magento cache:flush >/dev/null 2>&1
}

install_ps_cache(){
    echoG '[Start] Install PrestaShop LSCache'
    cd ${DOCROOT}
    wget -q https://www.litespeedtech.com/packages/prestashop/bk/litespeedcache.zip
    ./bin/console prestashop:module install litespeedcache.zip
    echoG '[End] PrestaShop LSCach install'
}    


check_els_service(){
    if [ "${OSNAMEVER}" = 'UBUNTU20' ]; then
        echoG 'Check elasticsearch service:'
        service elasticsearch status | grep running
        if [ ${?} = 0 ]; then 
            echoG 'elasticsearch is running'
        else
            echoR 'elasticsearch is not running, start it!'
            service elasticsearch start
        fi
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
    if [ "${APP}" = 'magento' ]; then 
        chown -R ${LSUSER}:${LSGROUP} ${1}
    else 
        chown -R ${USER}:${GROUP} ${1}
    fi     
}

setup_lsws(){
    echoG 'Setting LSWS Config'
    cd ${SCRIPTPATH}
    backup_old ${LSCONF}
    backup_old ${LSVCONF}
    cp conf/httpd_config.xml ${LSDIR}/conf/
    if [ "${APP}" = 'opencart' ]; then
        cp conf/ocvhconf.xml ${LSDIR}/DEFAULT/conf/vhconf.xml
    else
        cp conf/vhconf.xml ${LSDIR}/DEFAULT/conf/
    fi        
     if [ "${OSNAME}" = 'centos' ]; then
        sed -i "s/www-data/${USER}/g" ${LSCONF}
        sed -i "s|/usr/local/lsws/lsphp${PHP_P}${PHP_S}/bin/lsphp|/usr/bin/lsphp|g" ${LSCONF}
    fi
    if [ "${DF_PHPVER}" != "${PHPVER}" ]; then
        sed -i "s/${DF_PHPVER}/${PHPVER}/g" ${LSCONF}
    fi
    if [ "${APP}" != 'magento' ]; then
        sed -i 's/<litemage>1/<litemage>0/g' ${LSVCONF}
    fi
    gen_selfsigned_cert
}

setup_pure_lsws(){
    echoG 'Setting LSWS Config'
    cd ${SCRIPTPATH}
    backup_old ${LSCONF}
    backup_old ${LSVCONF}
    cp conf/httpd_config.xml ${LSDIR}/conf/
    cp conf/pure/vhconf.xml ${LSDIR}/DEFAULT/conf/
     if [ "${OSNAME}" = 'centos' ]; then
        sed -i "s/www-data/${USER}/g" ${LSCONF}
        sed -i "s|/usr/local/lsws/lsphp${PHP_P}${PHP_S}/bin/lsphp|/usr/bin/lsphp|g" ${LSCONF}
    fi
    if [ "${DF_PHPVER}" != "${PHPVER}" ]; then
        sed -i "s/${DF_PHPVER}/${PHPVER}/g" ${LSCONF}
    fi
    if [ "${APP}" != 'magento' ]; then
        sed -i 's/<litemage>1/<litemage>0/g' ${LSVCONF}
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
    NEWKEY="memory_limit = ${PHP_MEMORY}M"
    linechange 'memory_limit' ${PHPINICONF} "${NEWKEY}"
    ln -s /usr/local/lsws/lsphp${PHPVER}/bin/php /usr/bin/php
    killall lsphp >/dev/null 2>&1 
    echoG 'Finish PHP Paremeter'
}

ubuntu_config_memcached(){
    if [ ${SKIP_MEMCA} = 0 ]; then
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
    else
        echo 'Skip Memcached config!'
    fi        
}

ubuntu_config_redis(){
    if [ ${SKIP_REDIS} = 0 ]; then
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
    else
        echo 'Skip Redis config!'    
    fi    
}

centos_config_memcached(){
    if [ ${SKIP_MEMCA} = 0 ]; then
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
        semanage permissive -a memcached_t > /dev/null 2>&1
        setsebool -P httpd_can_network_memcache 1 > /dev/null 2>&1
        systemctl daemon-reload > /dev/null 2>&1

        change_owner ${WWWFD}
        service memcached start > /dev/null 2>&1
    else
        echo 'Skip Memcached setup!'
    fi        
}

centos_config_redis(){
    if [ ${SKIP_REDIS} = 0 ]; then
        service redis stop > /dev/null 2>&1
        NEWKEY="Group=${GROUP}"
        linechange 'Group=' ${REDISSERVICE} "${NEWKEY}"
        cat >> "${REDISCONF}" <<END
unixsocket /var/run/redis/redis-server.sock
unixsocketperm 775
END
        systemctl daemon-reload > /dev/null 2>&1
        service redis start > /dev/null 2>&1
    else
        echo 'Skip Redis config!'
    fi    
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
    cd ${SCRIPTPATH}
    backup_old ${CMDFD}/domainsetup.sh
    cp tools/domainsetup.sh ${CMDFD}/
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
	setup_domain
    help_message 1
}

filepermission_update(){
    chmod 600 ${HMPATH}/.db_password
    chmod 600 ${HMPATH}/.litespeed_password
}

renew_wpsalt(){
    if [ "${APP}" = 'wordpress' ]; then
        for KEY in "'AUTH_KEY'" "'SECURE_AUTH_KEY'" "'LOGGED_IN_KEY'" "'NONCE_KEY'" "'AUTH_SALT'" "'SECURE_AUTH_SALT'" "'LOGGED_IN_SALT'" "'NONCE_SALT'"
        do
            gen_salt
            LINENUM=$(grep -n "${KEY}" ${WPCFPATH} | cut -d: -f 1)
            sed -i "${LINENUM}d" ${WPCFPATH}
            NEWSALT="define(${KEY}, '${GEN_SALT}');"
            sed -i "${LINENUM}i${NEWSALT}" ${WPCFPATH}
        done
    fi
}

renew_blowfish(){
    if [ "${APP}" = 'wordpress' ]; then
        gen_salt
        LINENUM=$(grep -n "'blowfish_secret'" ${PHPMYCONF} | cut -d: -f 1)
        sed -i "${LINENUM}d" ${PHPMYCONF}
        NEW_SALT="\$cfg['blowfish_secret'] = '${GEN_SALT}';"
        sed -i "${LINENUM}i${NEW_SALT}" ${PHPMYCONF}
    fi
}

show_access(){
    if [ "${APP}" = 'magento' ]; then
        echo "Account: ${APP_ACCT}"
        echo "Password: ${APP_PASS}${APP_STR}"
        echo "Admin_URL: ${MA_BACK_URL}"
    elif [ "${APP}" = 'opencart' ]; then
        echo "Account: ${APP_ACCT}"
        echo "Password: ${APP_PASS}"
        echo "Admin_URL: ${OC_BACK_URL}"
    elif [ "${APP}" = 'prestashop' ]; then
        echo "Account: ${EMAIL}"
        echo "Password: ${APP_PASS}"
        echo "Admin_URL: ${PS_BACK_URL}"  
    else 
        echo 'Finish the rest installation on browser!'           
    fi    
}

start_message(){
    START_TIME="$(date -u +%s)"
}

end_message(){
    END_TIME="$(date -u +%s)"
    ELAPSED="$((${END_TIME}-${START_TIME}))"
    echoY "***Total of ${ELAPSED} seconds to finish process***"
}

config_ma_main(){
    install_litemage
    config_ma_htaccess
    config_litemage
}

config_wp_main(){
    config_wp_htaccess
    config_wp
    get_theme_name
    install_lscache
}

more_secure(){
    echoG "Update key"
    filepermission_update
    renew_wpsalt
    renew_blowfish
}

init_check(){
    check_os
    phpver_ck
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
    ubuntu_var_update
    ubuntu_pkg_basic
    if [ "${APP}" = 'wordpress' ]; then 
        ubuntu_pkg_postfix
        ubuntu_pkg_memcached
        ubuntu_pkg_redis
    fi    
    ubuntu_pkg_ufw
    ubuntu_pkg_phpmyadmin
    ubuntu_pkg_certbot
    ubuntu_pkg_system
    ubuntu_pkg_elasticsearch
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
    config_php
    if [ "${APP}" = 'wordpress' ]; then
        install_wordpress
        config_wp_main
        ubuntu_config_memcached
        ubuntu_config_redis        
    elif [ "${APP}" = 'magento' ]; then
        install_magento
        config_ma_main
        install_ma_sample
    elif [ "${APP}" = 'opencart' ]; then        
        install_opencart
    elif [ "${APP}" = 'prestashop' ]; then
            install_prestashop
            #install_ps_cache   
    elif [ "${APP}" = 'mautic' ]; then        
        install_mautic      
    elif [ "${APP}" = 'drupal' ]; then            
        install_drupal
    fi    
    restart_lsws
    change_owner ${DOCROOT}
}

ubuntu_main_uninstall(){
    ubuntu_uninstall_lsws
    ubuntu_uninstall_php
    if [ ${UNINSTALL_ALL} = 'True' ]; then
        ubuntu_uninstall_pkg
        ubuntu_uninstall_doc
    fi
    exit 0
}

centos_pkg_main(){
    centos_var_update
    centos_pkg_basic
    if [ "${APP}" = 'wordpress' ]; then     
        centos_pkg_postfix
        centos_pkg_memcached
        centos_pkg_redis
    fi
    centos_pkg_phpmyadmin
    centos_pkg_certbot
    centos_pkg_system
    centos_pkg_elasticsearch
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
    config_php
    if [ "${APP}" = 'wordpress' ]; then
        install_wordpress
        config_wp_main
        centos_config_memcached
        centos_config_redis
    elif [ "${APP}" = 'magento' ]; then
        install_magento
        config_ma_main
        install_ma_sample
    elif [ "${APP}" = 'opencart' ]; then        
        install_opencart
    elif [ "${APP}" = 'prestashop' ]; then        
        install_prestashop  
        #install_ps_cache
    elif [ "${APP}" = 'mautic' ]; then        
        install_mautic          
    fi
    restart_lsws
    change_owner ${DOCROOT}
}

centos_main_uninstall(){
    centos_uninstall_lsws
    centos_uninstall_php
    if [ ${UNINSTALL_ALL} = 'True' ]; then
        centos_uninstall_pkg
        centos_uninstall_doc
    fi
    exit 0
}

verify_installation(){
    echoG 'Start validate settings'
    test_ols_admin
    if [ "${APP}" = 'wordpress' ]; then
        test_wp_page
    elif [ "${APP}" = 'magento' ]; then
        test_magento_page
    elif [ "${APP}" = 'opencart' ]; then
        test_opencart_page
    elif [ "${APP}" = 'prestashop' ]; then
        test_prestashop_page    
    elif [ "${APP}" = 'mautic' ]; then
        test_mautic_page                     
    fi
    echoG 'End validate settings'
    echoG 'Cleanup cache.'
    fix_opencart_image
    clean_magento_cache
}

pure_main(){
    init_check
    start_message
    init_setup
    if [ ${OSNAME} = 'centos' ]; then
        centos_sysupdate
        centos_pkg_basic
        install_lsws
        centos_install_php
    else
        ubuntu_sysupdate
        ubuntu_pkg_basic
        install_lsws
        ubuntu_install_php
    fi
    setup_pure_lsws
    config_php 
    restart_lsws
    change_owner ${DOCROOT}
    rm -f "${DB_PASS_PATH}"
    exit 0
}

main(){
    init_check
    start_message
    init_setup
    if [ ${OSNAME} = 'centos' ]; then
        centos_main_install
        centos_main_config
    else
        ubuntu_main_install
        ubuntu_main_config
    fi
    more_secure
    verify_installation
    set_banner
    show_access 
    end_message
}

main_uninstall(){
    init_check
    start_message
    uninstall_msg
    if [ ${OSNAME} = 'centos' ]; then
        centos_main_uninstall
    else
        ubuntu_main_uninstall
    fi
    end_message
}

while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message 2
            ;;
        -[wW] | --wordpress)
            APP='wordpress'
            ;;
        -[mM] | --magento)
            APP='magento'
            ;;
        -[oO] | --opencart)
            APP='opencart'
            ;;
        -[pP] | --prestashop)
            APP='prestashop'
            ;;     
        --mautic)
            APP='mautic'
            ;;           
        -[dD] | --drupal)
            APP='drupal'
            ;;                                   
        -[sS] | --sample)
            SAMPLE='true'
            ;;
        -[lL] | --license)
            shift
            check_input "${1}"
            LICENSE="${1}"
            ;;            
        --pure)
            pure_main
            ;;
        --uninstall)
            ACTION=UNINSTALL
            main_uninstall
            ;;
        --uninstall-all)
            ACTION=UNINSTALL
            UNINSTALL_ALL='True'
            main_uninstall
            ;;
        *) 
            help_message 2
            ;;              
    esac
    shift
done
main

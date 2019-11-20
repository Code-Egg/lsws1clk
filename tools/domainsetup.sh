#!/bin/bash
MY_DOMAIN=''
MY_DOMAIN2=''
DOCHM='/var/www/html'
LSDIR='/usr/local/lsws'
WEBCF="${LSDIR}/DEFAULT/conf/vhconf.xml"
UPDATELIST='/var/lib/update-notifier/updates-available'
BOTCRON='/etc/cron.d/certbot'
WWW='FALSE'
UPDATE='TRUE'
OSNAME=''

echoY() {
    echo -e "\033[38;5;148m${1}\033[39m"
}
echoG() {
    echo -e "\033[38;5;71m${1}\033[39m"
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
    if [ -z "${MY_DOMAIN}" ] ; then
    echo -e "\nPlease input a valid domain\n"
    exit
    fi
    echo -e "The domain you put is: \e[31m${MY_DOMAIN}\e[39m"
    printf "%s"  "Please verify it is correct. [y/N] "
}

duplicateck(){
    grep "${1}" ${2} >/dev/null 2>&1
}

domainadd(){
    CHECK_WWW=$(echo ${MY_DOMAIN} | cut -c1-4)
    if [[ ${CHECK_WWW} == www. ]] ; then
        WWW='TRUE'
        #check if domain starts with www.
        MY_DOMAIN2=$(echo ${MY_DOMAIN} | cut -c 5-)

    fi
}

domainverify(){
    curl -Is http://${MY_DOMAIN}/ | grep -i LiteSpeed > /dev/null 2>&1
    if [ ${?} = 0 ]; then
        echoG "${MY_DOMAIN} check PASS"
    else
        echo "${MY_DOMAIN} inaccessible, please verify."; exit 1    
    fi
    if [ ${WWW} = 'TRUE' ]; then
        curl -Is http://${MY_DOMAIN2}/ | grep -i LiteSpeed > /dev/null 2>&1
        if [ $? = 0 ]; then 
            echoG "${MY_DOMAIN2} check PASS"   
        else
            echo "${MY_DOMAIN2} inaccessible, please verify."; exit 1    
        fi    
    fi
}

main_domain_setup(){
    domainhelp
    while true; do
        domaininput
        read TMP_YN
        if [[ "${TMP_YN}" =~ ^(y|Y) ]]; then
            domainadd
            break
        fi
    done    
}
emailinput(){
    CKREG="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
    printf "%s" "Please enter your E-mail: "
    read EMAIL
    if [[ ${EMAIL} =~ ${CKREG} ]] ; then
      echo -e "The E-mail you entered is: \e[31m${EMAIL}\e[39m"
      printf "%s"  "Please verify it is correct: [y/N] "
    else
      echo -e "\nPlease enter a valid E-mail, exit setup\n"; exit 1
    fi  
}

certbothook(){
    sed -i 's/0.*/&  --deploy-hook "\/usr\/local\/lsws\/bin\/lswsctrl restart"/g' ${BOTCRON}
    grep 'restart' ${BOTCRON} > /dev/null 2>&1
    if [ $? = 0 ]; then 
        echoG 'Certbot hook update success'
    else 
        echoY 'Please check certbot crond'
    fi        
}

lecertapply(){
    if [ ${WWW} = 'TRUE' ]; then
        certbot certonly --non-interactive --agree-tos -m ${EMAIL} --webroot -w ${DOCHM} -d ${MY_DOMAIN} -d ${MY_DOMAIN2}
    else
        certbot certonly --non-interactive --agree-tos -m ${EMAIL} --webroot -w ${DOCHM} -d ${MY_DOMAIN}
    fi    
    if [ ${?} -eq 0 ]; then
        ed ${WEBCF} << END >>/dev/null 2>&1
-0i
<vhssl>
<keyFile>/etc/letsencrypt/live/${MY_DOMAIN}/privkey.pem</keyFile>
<certFile>/etc/letsencrypt/live/${MY_DOMAIN}/fullchain.pem</certFile>
<certChain>1</certChain>
</vhssl>
.
w
q
END
        echoG "\ncertificate has been successfully installed..."
    else
        echo "Oops, something went wrong..."
        exit 1
    fi
}

force_https() {
    duplicateck "RewriteCond %{HTTPS} on" "${DOCHM}/.htaccess"
    if [ ${?} = 1 ]; then 
        echo "$(echo '
### Forcing HTTPS rule start       
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
### Forcing HTTPS rule end
            ' | cat - ${DOCHM}/.htaccess)" > ${DOCHM}/.htaccess
    fi
    echoG "Force HTTPS rules has been added..."
}

endsetup(){
    sed -i '/domainsetup.sh/d' /etc/profile
}

aptupgradelist() {
    PACKAGE=$(cat ${UPDATELIST} | awk '{print $1}' | sed -n 2p)
    SECURITY=$(cat ${UPDATELIST} | awk '{print $1}' | sed -n 3p)
    if [ "${PACKAGE}" = '0' ] && [ "${SECURITY}" = '0' ]; then 
        UPDATE='FALSE'    
    fi    
}

yumupgradelist(){
    PACKAGE=$(yum check-update | grep -v '*\|Load*\|excluded' | wc -l)
    if [ "${PACKAGE}" = '0' ]; then 
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
    if [[ "${TMP_YN}" =~ ^(y|Y) ]]; then
    #in case www domain , check both root domain and www domain accessibility.
        domainverify
        while true; do 
            emailinput
            read TMP_YN
            if [[ "${TMP_YN}" =~ ^(y|Y) ]]; then
                lecertapply
                break
            fi
        done   
        echoG 'Update certbot cronjob hook'
        certbothook 
        printf "%s"   "Do you wish to force HTTPS rewrite rule for this domain? [y/N]"
        read TMP_YN
        if [[ "${TMP_YN}" =~ ^(y|Y) ]]; then
            force_https
        fi
        restart_lsws
    fi        
}

main_upgrade(){
    if [ "${OSNAME}" = 'ubuntu' ]; then 
        aptupgradelist
    else
        yumupgradelist
    fi    
    if [ "${UPDATE}" = 'TRUE' ]; then
        printf "%s"   "Do you wish to update the system now? This will update the web server as well. [Y/n]? "
        read TMP_YN
        if [[ ! "${TMP_YN}" =~ ^(n|N) ]]; then
            echoG "Update Starting..." 
            if [ "${OSNAME}" = 'ubuntu' ]; then 
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
rm -- "$0"
exit 0

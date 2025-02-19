#!/bin/bash

# Atualiza os pacotes e instala dependências

IP_BANCO=$1
SENHA=$2
DB_NAME=$3
USER=$4
IP_SERVIDOR=$(hostname -I | awk '{print $1}')

echo 
echo
echo =====================================================
echo '**************** INSTALL ASTERISK 22 ****************'
echo =====================================================
echo 
echo 

sudo apt update && sudo apt upgrade -y

sudo apt install build-essential libncurses5-dev libssl-dev libxml2-dev libsqlite3-dev uuid-dev libjansson-dev libxslt1-dev libcurl4-openssl-dev libedit-dev libopus-dev -y
sudo apt install unixodbc unixodbc-dev odbcinst odbc-mariadb -y
apt install -y libedit-dev libspeex-dev libopus-dev \
  libsrtp2-dev libspandsp-dev libcurl4-openssl-dev \
  liblua5.2-dev libgmime-3.0-dev

sudo apt install pkg-config

cd /usr/src/
wget https://raw.githubusercontent.com/LucaoBrabo/projeto-billing/refs/heads/main/asterisk-22.0.0.tar.gz
tar -xvzf asterisk-22.0.0.tar.gz
cd asterisk-22.0.0

./configure --with-unixodbc=PATH 
sudo make install
sudo make samples
sudo make config

sudo systemctl start asterisk
sudo systemctl enable asterisk

echo 
echo
echo =====================================================
echo '**************** FINISHI ASTERISK 22 ****************'
echo =====================================================
echo 
echo 
sleep 3

echo =====================================================
echo '****************   INSTALL SNGREP   *****************'
echo =====================================================
echo 
echo 
sleep 3

apt-get -y install sngrep

echo 
echo 
echo =====================================================
echo '****************   FINISHI SNGREP   *****************'
echo =====================================================
echo 
echo 
sleep 3

echo =====================================================
echo '************* START CONFIGURE ASTERISK **************'
echo =====================================================
echo 
echo 
sleep 3

cd /etc/asterisk

echo =====================================================
echo '**************** CONFIGURE ari.conf *****************'
echo =====================================================
echo 
echo 
cat <<EOL > ari.conf
[general]
enabled = yes       ; When set to no, ARI support is disabled.
pretty = yes
allowed_origins = http://$IP_BANCO

[asterisk]
type = user
read_only = no
password = $SENHA

[my-app]
type = user
read_only = no
password = $SENHA
EOL

echo =====================================================
echo '************* CONFIGURE asterisk.conf ***************'
echo =====================================================
echo 
echo 

cat <<EOL > asterisk.conf
[directories](!)
astcachedir => /var/cache/asterisk
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk
astsbindir => /usr/sbin

[options]
documentation_language = en_US
EOL

echo =====================================================
echo '*************** CONFIGURE cdr.conf ******************'
echo =====================================================
echo 
echo 

cat <<EOL > cdr.conf
[general]
enable=yes
EOL

echo =====================================================
echo '********* CONFIGURE cdr_adaptive_odbc.conf **********'
echo =====================================================
echo 
echo 

cat <<EOL > cdr_adaptive_odbc.conf
[asterisk]
connection=asterisk
hostname=$IP_BANCO
port=3306
dbname=$DB_NAME
password=$SENHA
user=$USER
table=cdr
schema=public
newcdrcolumns=no
alias end => enddate
EOL

echo =====================================================
echo '************** CONFIGURE cel_odbc.conf **************'
echo =====================================================
echo 
echo 

cat <<EOL > cel_odbc.conf
[general]
show_user_defined=yes
[asterisk]
connection=asterisk
table=cel
EOL

echo =====================================================
echo '************* CONFIGURE extconfig.conf **************'
echo =====================================================
echo 
echo 

cat <<EOL > extconfig.conf
[settings]
ps_endpoints => odbc,asterisk
ps_auths => odbc,asterisk
ps_aors => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
ps_contacts => odbc,asterisk
ps_registrations => odbc,asterisk
queues => odbc,asterisk
queue_members => odbc,asterisk
queue_rules => odbc,asterisk
queue_log => odbc,asterisk
EOL

echo =====================================================
echo '************* CONFIGURE extensions.conf *************'
echo =====================================================
echo 
echo 

cat <<EOL > extensions.conf
[general]
static=yes
writeprotect=no
clearglobalvars=no

[from-internal]
exten => _55XXXXXXXXXXX,1,NoOp(Chamada para ${EXTEN} via ARI) ;celular
 same => n,Stasis(my-app)   ; Chama a aplicação ARI
 same => n,Hangup()

exten => _55XXXXXXXXXX,1,NoOp(Chamada para ${EXTEN} via ARI) ;fixo
 same => n,Stasis(my-app)   ; Chama a aplicação ARI
 same => n,Hangup()

exten => _XXX!,1,Dial(PJSIP/${EXTEN},20)
same => n,Hangup()
EOL

echo =====================================================
echo '**************** CONFIGURE http.conf ****************'
echo =====================================================
echo 
echo 

cat <<EOL > http.conf
[general]
servername=Asterisk
enabled=yes
bindaddr=0.0.0.0
bindport=8088
EOL

echo =====================================================
echo '************** CONFIGURE modules.conf ***************'
echo =====================================================
echo 
echo 

cat <<EOL > modules.conf
[modules]
autoload=yes
noload = chan_alsa.so
noload = chan_console.so
noload = res_hep.so
noload = res_hep_pjsip.so
noload = res_hep_rtcp.so
noload = chan_sip.so
;noload = app_voicemail.so
noload = app_voicemail_imap.so
noload = app_voicemail_odbc.so
noload = codec_opus.so
noload = res_phoneprov.so
noload = res_adsi.so
noload = app_adsiprog.so
noload = app_getcpeid.so
noload = res_config_pgsql.so
noload = cdr_pgsql.so
noload = app_forkcdr.so
noload = cdr_custom.so
;noload = cdr_manager
noload = cdr_odbc.so
noload = pbx_lua.so
noload = pbx_ael.so
noload = pbx_dundi.so
noload = cel_custom.so
noload = chan_unistim.so
noload = app_minivm.so
noload = res_pjsip_phoneprov_provider.so
EOL

echo =====================================================
echo '*************** CONFIGURE pjsip.conf ****************'
echo =====================================================
echo 
echo 

cat <<EOL > pjsip.conf
[global]
user_agent=callphone
keep_alive_interval=90
;endpoint_identifier_order=ip,username,anonymous,header,auth_username

[acl]
type=acl
permit=0.0.0.0/0.0.0.0

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0
;codec_prefs = ulaw, alaw, g729

[transport-ws]
type = transport
protocol = wss
bind = 0.0.0.0
external_media_address=$IP_SERVIDOR
external_signaling_address=$IP_SERVIDOR
EOL

echo =====================================================
echo '************* CONFIGURE res_odbc.conf ***************'
echo =====================================================
echo 
echo 

cat <<EOL > res_odbc.conf
[asterisk]
enabled => yes
dsn => $DB_NAME
username => $USER
password => $SENHA
pre-connect => yes
EOL

echo =====================================================
echo '**************** CONFIGURE rtp.conf *****************'
echo =====================================================
echo 
echo 

cat <<EOL > rtp.conf
[general]
rtpstart=10000
rtpend=20000
EOL

echo =====================================================
echo '************** CONFIGURE sorcery.conf ***************'
echo =====================================================
echo 
echo 

cat <<EOL > sorcery.conf
[res_pjsip]
endpoint=realtime,ps_endpoints
auth=realtime,ps_auths
aor=realtime,ps_aors
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips

[res_pjsip_outbound_registration]
registration=realtime,ps_registrations

[app_queue]
queues=realtime,queues
members=realtime,queue_members
rules=realtime,queue_rules
EOL

cd /etc/

echo =====================================================
echo '**************** CONFIGURE odbc.ini *****************'
echo =====================================================
echo 
echo 

cat <<EOL > odbc.ini
[asterisk]
Description = MySQL Asterisk
Driver = MariaDB Unicode
Database = $DB_NAME
Server = $IP_BANCO
User = $USER
Password = $SENHA
Port = 3306
EOL


echo =====================================================
echo '************** CONFIGURE odbcinst.ini ***************'
echo =====================================================
echo 
echo 

cat <<EOL > odbcinst.ini
[MariaDB Unicode]
Driver=/usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
Description=MariaDB Connector/ODBC(Unicode)
Threading=0
UsageCount=1
EOL


echo 
echo 
echo =====================================================
echo ************ FINISHI CONFIGURE ASTERISK *************
echo =====================================================
echo 
echo 
sleep 3

reboot

#!/bin/bash
# ============================================================
# ZTE ZXHN H168A V2.0 - Root Erişimi Açma Scripti
# Orijinal: LeMandark/H298A-V9 (H298A için X_TT prefix)
# Uyarlama: H168A V2.0 için (prefix keşfetme + uygulama)
#
# ÖNEMLİ: Bu script Ubuntu VM içinde sudo ile çalıştırılmalı:
#   sudo bash h168a_v20_root.sh
# ============================================================

GRN='\033[0;32m'
CYA='\033[0;36m'
YEL='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo "============================================================"
echo "  ZTE ZXHN H168A V2.0 — Root Erişimi Açma Scripti"
echo "============================================================"
echo ""
printf "!!! ${RED}Bu scripti VM (Ubuntu) içinde çalıştırın${NC} !!!\n"
printf "!!! ${RED}Internet bağlantısı gerekli (paket kurulumu için)${NC} !!!\n\n"
printf "Devam etmek için ${CYA}Enter${NC}'a basın..."
read ileri

# ============================================================
# ADIM 1: Şifre Belirleme
# ============================================================
clear
echo "============================================================"
echo "  ADIM 1: Şifre Belirleme"
echo "============================================================"
echo ""
printf "Modem ${GRN}WEB${NC} arayüzü root şifresi ne olsun?\n"
printf "(En az 8 karakter, ${CYA}1 büyük, 1 küçük, 1 rakam${NC})\n"
printf "Örn: ${YEL}Sifre123${NC} / ${YEL}Arabada5${NC}: "
read webroot

clear
printf "Modem ${GRN}SSH${NC} root şifresi ne olsun?\n"
printf "(En az 8 karakter, ${CYA}1 büyük, 1 küçük, 1 rakam${NC})\n"
printf "Örn: ${YEL}Sifre123${NC}: "
read sshroot

clear
printf "Modem ${GRN}SHELL${NC} root şifresi ne olsun?\n"
printf "(En az 8 karakter, ${CYA}1 büyük, 1 küçük, 1 rakam${NC})\n"
printf "Örn: ${YEL}Sifre123${NC}: "
read shellroot

# ============================================================
# ADIM 2: TR-069 Parametre Ön Eki Seçimi
# ============================================================
clear
echo "============================================================"
echo "  ADIM 2: TR-069 Parametre Ön Eki Seçimi"
echo "============================================================"
echo ""
printf "H168A V2.0 modeminizin parametre ön eki hangisi?\n\n"
printf "  ${YEL}1${NC} - X_TT        (bazı eski TTNet modemleri)\n"
printf "  ${YEL}2${NC} - X_TTNET     (çoğu TTNet/Türk Telekom modemi)\n"
printf "  ${YEL}3${NC} - X_TURKTELEKOM\n"
printf "  ${YEL}4${NC} - X_ZTE\n"
printf "  ${YEL}5${NC} - Özel prefix gir\n\n"
printf "${CYA}Not:${NC} V2.1'de X_TTNET kullanılıyor. V2.0 için de ${YEL}X_TTNET${NC} deneyin.\n"
printf "Seçiminiz (1-5): "
read prefix_choice

case $prefix_choice in
    1) PREFIX="X_TT" ;;
    2) PREFIX="X_TTNET" ;;
    3) PREFIX="X_TURKTELEKOM" ;;
    4) PREFIX="X_ZTE" ;;
    5)
        printf "Özel prefix girin (örn: X_MYISP): "
        read PREFIX
        ;;
    *) PREFIX="X_TTNET" ;;
esac

printf "\n${GRN}Seçilen prefix: ${YEL}${PREFIX}${NC}\n"
printf "Devam etmek için ${CYA}Enter${NC}'a basın..."
read ileri

# ============================================================
# ADIM 3: Gerekli Paketlerin Kurulumu
# ============================================================
clear
echo "============================================================"
echo "  ADIM 3: Paket Kurulumu"
echo "============================================================"
echo ""

apt update
apt install -y isc-dhcp-server lighttpd wireshark

# ============================================================
# ADIM 4: DHCP Sunucusu Yapılandırması
# ============================================================
clear
echo "============================================================"
echo "  ADIM 4: DHCP Yapılandırması"
echo "============================================================"
echo ""

# VM'in ağ arayüzünü tespit et
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$IFACE" ]; then
    IFACE=$(ip link show | grep "state UP" | head -1 | awk -F: '{print $2}' | tr -d ' ')
fi
if [ -z "$IFACE" ]; then
    printf "${RED}Ağ arayüzü tespit edilemedi!${NC}\n"
    printf "Lütfen ağ arayüzü adını girin (örn: enp0s3, eth0): "
    read IFACE
fi
printf "Kullanılacak ağ arayüzü: ${YEL}${IFACE}${NC}\n"

# DHCP interface ayarı
if [ -f /etc/default/isc-dhcp-server ]; then
    sed -i "s/INTERFACESv4=\"\"/INTERFACESv4=\"${IFACE}\"/" /etc/default/isc-dhcp-server
    # Eğer sed değişiklik yapmadıysa, elle ekle
    grep -q "INTERFACESv4=\"${IFACE}\"" /etc/default/isc-dhcp-server || \
        echo "INTERFACESv4=\"${IFACE}\"" >> /etc/default/isc-dhcp-server
fi

# Network arayüzüne sabit IP ata
printf "\n${YEL}Ağ arayüzüne sabit IP atanıyor (10.116.13.21/24)...${NC}\n"
ip addr flush dev $IFACE
ip addr add 10.116.13.21/24 dev $IFACE
ip link set $IFACE up

# DHCP config oluştur
cat > /etc/dhcp/dhcpd.conf << 'DHCPEOF'
option domain-name "example.org";

default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;

option subnet-mask 255.255.255.0;
option broadcast-address 10.116.13.255;
option routers 10.116.13.1;
option domain-name-servers 8.8.8.8;

option space zte;
option zte.adr code 1 = text;
option local-encapsulation code 43 = encapsulate zte;
option zte.adr "http://10.116.13.21/cwmpWeb/WGCPEMgt";

subnet 10.116.13.0 netmask 255.255.255.0 {
range 10.116.13.10 10.116.13.100;
}
DHCPEOF

printf "${GRN}DHCP yapılandırması tamamlandı.${NC}\n"

# ============================================================
# ADIM 5: Lighttpd (Web Sunucusu / Sahte ACS) Yapılandırması
# ============================================================
echo ""
echo "============================================================"
echo "  ADIM 5: Sahte ACS Sunucusu Yapılandırması"
echo "============================================================"
echo ""

# CGI modülü aktifle
ln -sf /etc/lighttpd/conf-available/10-accesslog.conf /etc/lighttpd/conf-enabled/
ln -sf /etc/lighttpd/conf-available/10-cgi.conf /etc/lighttpd/conf-enabled/

# CGI config
cat > /etc/lighttpd/conf-enabled/10-cgi.conf << 'CGIEOF'
server.modules += ( "mod_cgi" )

$HTTP["url"] =~ "^/.*" {
        cgi.assign = ( "/simula" => "" )
        alias.url = ( "" => "/etc/lighttpd/simula")
}
CGIEOF

# Simula script (Sahte ACS motoru)
cat > /etc/lighttpd/simula << 'SIMULAEOF'
#!/bin/bash

eval $HTTP_COOKIE
if [ -z $session ] ; then
   session=$(date +'%F-%T')
   mkdir -p /tmp/acs/$session
fi

if [ -f /tmp/acs/${session}/status ] ; then
  status=$(cat /tmp/acs/${session}/status)
else
  status=1
fi

if [ ! -f /etc/lighttpd/resp${status} ] ; then
  exit
fi

echo "Content-Type: text/xml"
[ -n "$session" ] && echo "Set-Cookie: session=$session"
echo ""
cat /dev/stdin > /tmp/acs/${session}/req${status}
cat /etc/lighttpd/resp${status}

status=$(($status+1))
echo $status > /tmp/acs/${session}/status
SIMULAEOF
chmod +x /etc/lighttpd/simula

# ============================================================
# ADIM 6: SOAP Yanıt Dosyalarını Oluştur
# ============================================================
echo ""
echo "============================================================"
echo "  ADIM 6: SOAP Yanıtları Oluşturuluyor"
echo "============================================================"
echo ""
printf "Prefix: ${YEL}${PREFIX}${NC}\n\n"

# RESP1: InformResponse (modem bağlandığında ilk yanıt)
cat > /etc/lighttpd/resp1 << 'RESP1EOF'
<SOAP-ENV:Envelope xmlns:SOAP="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:cwmp="urn:dslforum-org:cwmp-1-0" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<SOAP-ENV:Header>
<cwmp:ID SOAP:mustUnderstand="1">1</cwmp:ID>
<cwmp:NoMoreRequest>0</cwmp:NoMoreRequest>
</SOAP-ENV:Header>
<SOAP-ENV:Body>
<cwmp:InformResponse><MaxEnvelopes>1</MaxEnvelopes></cwmp:InformResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
RESP1EOF

# RESP2: SetParameterValues (root erişimini açan komutlar)
cat > /etc/lighttpd/resp2 << RESP2EOF
<SOAP-ENV:Envelope xmlns:SOAP="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:cwmp="urn:dslforum-org:cwmp-1-0" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<SOAP-ENV:Header>
<cwmp:ID SOAP:mustUnderstand="1">1</cwmp:ID>
<cwmp:NoMoreRequest>0</cwmp:NoMoreRequest>
</SOAP-ENV:Header>
<SOAP-ENV:Body>
<cwmp:SetParameterValues>
<ParameterList>
<ParameterValueStruct><Name>InternetGatewayDevice.${PREFIX}.Configuration.Shell.Enable</Name><Value xsi:type="xsd:boolean">1</Value></ParameterValueStruct>
<ParameterValueStruct><Name>InternetGatewayDevice.${PREFIX}.Configuration.Shell.Password</Name><Value xsi:type="xsd:string">${shellroot}</Value></ParameterValueStruct>
<ParameterValueStruct><Name>InternetGatewayDevice.X_ZTE-COM_SSH.Enable</Name><Value xsi:type="xsd:boolean">1</Value></ParameterValueStruct>
<ParameterValueStruct><Name>InternetGatewayDevice.X_ZTE-COM_SSH.UserName</Name><Value xsi:type="xsd:string">root</Value></ParameterValueStruct>
<ParameterValueStruct><Name>InternetGatewayDevice.X_ZTE-COM_SSH.Password</Name><Value xsi:type="xsd:string">${sshroot}</Value></ParameterValueStruct>
<ParameterValueStruct><Name>InternetGatewayDevice.${PREFIX}.Users.User.2.Enable</Name><Value xsi:type="xsd:boolean">1</Value></ParameterValueStruct>
<ParameterValueStruct><Name>InternetGatewayDevice.${PREFIX}.Users.User.2.Username</Name><Value xsi:type="xsd:string">root</Value></ParameterValueStruct>
<ParameterValueStruct><Name>InternetGatewayDevice.${PREFIX}.Users.User.2.Password</Name><Value xsi:type="xsd:string">${webroot}</Value></ParameterValueStruct>
</ParameterList>
<ParameterKey/>
</cwmp:SetParameterValues>
</SOAP-ENV:Body>
</SOAP-ENV:Envelope>
RESP2EOF

# RESP3: Boş (oturum sonu)
touch /etc/lighttpd/resp3

# ACS temp dizini
mkdir -p /tmp/acs
chown www-data /tmp/acs

printf "${GRN}SOAP yanıt dosyaları oluşturuldu.${NC}\n\n"
printf "Ayarlanacak parametreler:\n"
printf "  - InternetGatewayDevice.${YEL}${PREFIX}${NC}.Configuration.Shell.Enable = ${GRN}1${NC}\n"
printf "  - InternetGatewayDevice.${YEL}${PREFIX}${NC}.Configuration.Shell.Password = ${GRN}***${NC}\n"
printf "  - InternetGatewayDevice.X_ZTE-COM_SSH.Enable = ${GRN}1${NC}\n"
printf "  - InternetGatewayDevice.X_ZTE-COM_SSH.UserName = ${GRN}root${NC}\n"
printf "  - InternetGatewayDevice.X_ZTE-COM_SSH.Password = ${GRN}***${NC}\n"
printf "  - InternetGatewayDevice.${YEL}${PREFIX}${NC}.Users.User.2.Enable = ${GRN}1${NC}\n"
printf "  - InternetGatewayDevice.${YEL}${PREFIX}${NC}.Users.User.2.Username = ${GRN}root${NC}\n"
printf "  - InternetGatewayDevice.${YEL}${PREFIX}${NC}.Users.User.2.Password = ${GRN}***${NC}\n"

printf "\nDevam etmek için ${CYA}Enter${NC}'a basın..."
read ileri

# ============================================================
# ADIM 7: Wireshark'ı Başlat (İzleme)
# ============================================================
clear
echo "============================================================"
echo "  ADIM 7: Wireshark Başlatılıyor"
echo "============================================================"
echo ""

wireshark &
sleep 3
clear

printf "\n${YEL}Wireshark açıldı!${NC}\n\n"
printf "1 - Wireshark'ta ağ arayüzünüzü (${YEL}${IFACE}${NC}) çift tıklayın\n"
printf "2 - Filtre kısmına: ${YEL}dhcp or xml${NC} yazıp ${CYA}Enter${NC}'a basın\n"
printf "3 - Bu ekrana geri dönüp ${CYA}Enter${NC}'a basın\n"
read ileri

# ============================================================
# ADIM 8: Fiziksel Bağlantı
# ============================================================
clear
echo "============================================================"
echo "  ADIM 8: Fiziksel Bağlantı"
echo "============================================================"
echo ""
printf "${YEL}Sırasıyla şunları yapın:${NC}\n\n"
printf "  1 - Modemin ${YEL}WAN${NC} kablosunu (telefon/fiber kablosu) ${RED}ÇIKARIN${NC}\n"
printf "  2 - Modemi web arayüzünden ${RED}FABRİKA AYARLARINA${NC} döndürün\n"
printf "     (İşlem başladığı anda hemen 3. adıma geçin!)\n"
printf "  3 - Bilgisayarı/VM'i modemin ${YEL}WAN${NC} portuna Ethernet kablosuyla bağlayın\n"
printf "     ${RED}(LAN değil, WAN portuna!)${NC}\n\n"
printf "Hazır olduğunuzda ${CYA}Enter${NC}'a basın..."
read ileri

# ============================================================
# ADIM 9: Servisler Başlatılıyor & Bekleme
# ============================================================
clear
echo "============================================================"
echo "  ADIM 9: Modem Bekleniyor"
echo "============================================================"
echo ""

printf "Modemin fabrika ayarlarına dönmesi bekleniyor (60 saniye)...\n\n"
for i in $(seq 60 -1 0); do
    printf "\r  Kalan: ${YEL}%02d${NC} saniye" $i
    sleep 1
done
echo ""
echo ""

# Servisleri yeniden başlat
printf "${YEL}DHCP ve ACS sunucuları başlatılıyor...${NC}\n"
systemctl restart isc-dhcp-server 2>/dev/null || /etc/init.d/isc-dhcp-server restart
systemctl restart lighttpd 2>/dev/null || /etc/init.d/lighttpd restart

printf "\n${GRN}Servisler başlatıldı!${NC}\n"
printf "DHCP ve ACS'nin hazır olması bekleniyor (30 saniye)...\n\n"
for i in $(seq 30 -1 0); do
    printf "\r  Kalan: ${YEL}%02d${NC} saniye" $i
    sleep 1
done
echo ""
echo ""

# ============================================================
# ADIM 10: Sonuç Kontrolü
# ============================================================
clear
echo "============================================================"
echo "  ADIM 10: Sonuç Kontrolü"
echo "============================================================"
echo ""
printf "${YEL}Wireshark'ı kontrol edin:${NC}\n\n"
printf "  - ${GRN}DHCP Discover/Offer/Request/ACK${NC} mesajları görüyor musunuz?\n"
printf "    (Modem IP aldı demektir)\n\n"
printf "  - ${GRN}HTTP/XML${NC} mesajları görüyor musunuz?\n"
printf "    (TR-069 iletişimi başladı demektir)\n\n"
printf "Her ikisi de görünüyorsa ${GRN}BAŞARILI!${NC} 🎉\n\n"

echo "============================================================"
printf "${RED}SORUN GİDERME:${NC}\n"
echo "============================================================"
printf "  DHCP çalışmıyorsa: ${YEL}sudo systemctl restart isc-dhcp-server${NC}\n"
printf "  ACS çalışmıyorsa:  ${YEL}sudo systemctl restart lighttpd${NC}\n"
printf "  Hiçbiri olmazsa:   Modemi yeniden başlatın\n"
printf "  Yine olmazsa:      Prefix yanlış olabilir, ${YEL}farklı prefix${NC} deneyin\n\n"

echo "============================================================"
printf "${GRN}BAŞARILI OLDUYSA:${NC}\n"
echo "============================================================"
printf "  1 - WAN kablosunu çıkarın\n"
printf "  2 - Modemi yeniden başlatın\n"
printf "  3 - LAN portundan modemin web arayüzüne girin (192.168.1.1)\n"
printf "  4 - root / ${YEL}${webroot}${NC} ile giriş yapın\n"
printf "  5 - Giriş başarılıysa, WAN kablosunu geri takın\n\n"
printf "${YEL}ÖNEMLİ:${NC} Giriş yaptıktan sonra modem arayüzünden ${GRN}yedeğinizi alın!${NC}\n"
printf "ISP şifrenizi resetlerse yedekten geri dönebilirsiniz.\n\n"

echo "============================================================"
echo "  İşlem tamamlandı. GL:HF"
echo "============================================================"

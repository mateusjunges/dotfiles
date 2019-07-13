apt-get install openvpn
mkdir -p /etc/openvpn
wget http://repositorios.uepg.br/outros/openvpn/ca.crt -O /etc/openvpn/ca.crt
wget http://repositorios.uepg.br/outros/openvpn/uepg.ovpn -O /etc/openvpn/uepg.ovpn
openvpn --config /etc/openvpn/uepg.ovpn

# ansible-easy-vpn
![CI](https://github.com/notthebee/ansible-easy-vpn/actions/workflows/ci.yml/badge.svg)

Um script interativo simples que configura um servidor VPN Wireguard com Adguard, Unbound e DNSCrypt-Proxy em seu VPS de escolha, e permite que você gerencie os arquivos de configuração usando uma WebUI simples protegida por autenticação de dois fatores.

**Tem uma pergunta ou um problema? Leia primeiro o [FAQ](FAQ.md) primeiro!**

## Usage
```
wget https://notthebe.ee/vpn -O bootstrap.sh && bash bootstrap.sh
```

## Recursos
* Wireguard WebUI (via wg-easy)
* Autenticação de dois fatores para o WebUI (Authelia)
* Servidor web reforçado (Bunkerweb)
* Resolução DNS criptografada com funcionalidade opcional de bloqueio de anúncios (Adguard Home, DNSCrypt e Unbound)
* Firewall IPTables com padrões sensatos e Fail2Ban
* Atualizações automatizadas e desassistidas
* Reforço de SSH e geração de par de chaves públicas (opcional, você também pode usar suas próprias chaves)
* Notificações por e-mail (usando um servidor SMTP externo, por exemplo, GMail)

## Requisitos
* Um VPS baseado em KVM (ou uma instância AWS EC2) com um endereço IPv4 dedicado
* Uma das distribuições Linux suportadas:
* Ubuntu Server 22.04
* Ubuntu Server 20.04
* Debian 11
* Debian 12

## Problemas conhecidos com provedores de VPS
Normalmente, o script deve funcionar em qualquer VPS baseado em KVM.

No entanto, alguns provedores de VPS usam versões não padrão das imagens do sistema operacional Ubuntu/Debian, o que pode levar a problemas com o script.

Além disso, alguns provedores exigem configuração adicional de firewall no painel de controle do servidor para desbloquear a porta do Wireguard.

AlexHost – executa apt-get dist-upgrade após a provisão do VPS, o que resulta em um bloqueio dpkg
IONOS – inclui um firewall com regras padrão, que bloqueia o tráfego do Wireguard. O usuário precisa abrir a porta do Wireguard (51820/udp) no painel de controle para que a VPN funcione.

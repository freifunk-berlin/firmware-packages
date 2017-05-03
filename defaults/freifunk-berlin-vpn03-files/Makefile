# $Id: Makefile 2010-02-04 23:25:21Z pg $
#
# renamed from freifunk-berlin-openvpn-files to freifunk-berlin-vpn03-files
# when separating out VPN03-configs

include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-vpn03-files
PKG_VERSION:=0.0.4
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-vpn03-files/default
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+= +freifunk-berlin-lib-guard
  PKGARCH:=all
endef

define Package/freifunk-berlin-vpn03-files/description
  Freifunk Berlin VPN03 files
endef

define Package/freifunk-berlin-vpn03-openvpn-files
  $(call Package/freifunk-berlin-vpn03-files/default)
  TITLE:=Freifunk Berlin VPN03 files (OpenVPN)
  DEPENDS+= +openvpn-crypto +freifunk-berlin-openvpn-files
endef

define Package/freifunk-berlin-vpn03-openvpn-files/description
  Freifunk Berlin openVPN files
endef

define Package/freifunk-berlin-vpn03-ipsec-files
  $(call Package/freifunk-berlin-vpn03-files/default)
  TITLE:=Freifunk Berlin VPN03 files (IpSec)
  DEPENDS:=+strongswan-minimal +strongswan-mod-pem +strongswan-mod-openssl +vtiv4 +vti
endef

define Package/freifunk-berlin-vpn03-ipsec-files/description
  Freifunk VPN03 files for IpSec-tunnels
endef

define Package/freifunk-berlin-vpn03-ipsec-files/conffiles
/etc/ipsec.conf
/etc/ipsec.d/ipsec.vpn03.conf
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-vpn03-openvpn-files/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/openvpn
	$(CP) ./openvpn/freifunk-ca.crt $(1)/etc/openvpn
endef

define Package/freifunk-berlin-vpn03-ipsec-files/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/freifunk-berlin-vpn03-ipsec $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/ipsec.d
	$(CP) ./ipsec/vpn03-ipsec.conf $(1)/etc/ipsec.d/ipsec.vpn03.conf
	$(INSTALL_DIR) $(1)/lib/freifunk
	$(CP) ./ipsec/vti.sh $(1)/lib/freifunk/ffvpn-ipsec-vti.sh
	$(INSTALL_DIR) $(1)/etc/ipsec.d/cacerts
	$(CP) ./files/freifunk-ca.crt $(1)/etc/ipsec.d/cacerts/
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(CP) ./ipsec/60-vpn03_ipsec $(1)/etc/hotplug.d/iface
	$(INSTALL_DIR) $(1)/etc/strongswan.d
	$(CP) ./ipsec/vpn03-strongswan.conf $(1)/etc/strongswan.d/
endef

# add vpn03-config to main ipsec.conf
define Package/freifunk-berlin-vpn03-ipsec-files/postinst
#!/bin/sh
grep -q "include /etc/ipsec.d/ipsec.vpn03.conf" /etc/ipsec.conf || \
  echo "include /etc/ipsec.d/ipsec.vpn03.conf" >>/etc/ipsec.conf
endef

$(eval $(call BuildPackage,freifunk-berlin-vpn03-openvpn-files))
$(eval $(call BuildPackage,freifunk-berlin-vpn03-ipsec-files))

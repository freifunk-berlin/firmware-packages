
include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-uplink-tunnelberlin-files

include ../../freifunk-berlin-generic.mk

define Package/freifunk-berlin-uplink-tunnelberlin-files/Default
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin Networktunnel files
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS:=+freifunk-berlin-lib-guard
  PROVIDES:=freifunk-berlin-uplink
  PKGARCH:=all
endef

define Package/freifunk-berlin-uplink-tunnelberlin-openvpn
$(call Package/freifunk-berlin-uplink-tunnelberlin-files/Default)
  TITLE+= (OpenVPN)
  VARIANT:=openvpn
  DEPENDS+= +openvpn-crypto +freifunk-berlin-openvpn-files
endef

define Package/freifunk-berlin-uplink-tunnelberlin-tunneldigger
$(call Package/freifunk-berlin-uplink-tunnelberlin-files/Default)
  TITLE+= (Tunneldigger)
  VARIANT:=tunneldigger
  DEPENDS+= +freifunk-berlin-tunneldigger +freifunk-berlin-network-defaults
endef

define Package/freifunk-berlin-uplink-tunnelberlin-files/description
  Freifunk Berlin files to setup a tunnel to route all
  upstream traffic to these community-internet-gateways
endef

define Package/freifunk-berlin-uplink-tunnelberlin-tunneldigger/description
$(call Package/freifunk-berlin-uplink-tunnelberlin-files/description)
  This variant uses the tunneldigger-protocol.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-uplink-tunnelberlin-openvpn/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/freifunk-berlin-z95_tunnelberlin-openvpn $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/openvpn
	$(CP) ./openvpn/tunnel-berlin-*.crt $(1)/etc/openvpn
endef

define Package/freifunk-berlin-uplink-tunnelberlin-tunneldigger/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/freifunk-berlin-z95_tunnelberlin-tunneldigger $(1)/etc/uci-defaults
endef

$(eval $(call BuildPackage,freifunk-berlin-uplink-tunnelberlin-openvpn))
$(eval $(call BuildPackage,freifunk-berlin-uplink-tunnelberlin-tunneldigger))

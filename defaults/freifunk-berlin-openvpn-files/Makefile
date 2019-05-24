# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-openvpn-files

include ../../freifunk-berlin-generic.mk

define Package/freifunk-berlin-openvpn-files
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin openVPN files (commmon)
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+= +openvpn +freifunk-berlin-lib-guard +freifunk-berlin-network-defaults
  PKGARCH:=all
endef

define Package/freifunk-berlin-openvpn-files/description
  Freifunk Berlin openVPN files
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-openvpn-files/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/lib/freifunk
	$(CP) ./openvpn/ffvpn-up.sh $(1)/lib/freifunk
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(CP) ./openvpn/60-ffopenvpn $(1)/etc/hotplug.d/iface
endef

$(eval $(call BuildPackage,freifunk-berlin-openvpn-files))

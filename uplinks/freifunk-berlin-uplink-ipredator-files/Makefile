
include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-uplink-ipredator-files
PKG_VERSION:=0.0.2
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-uplink-ipredator-files
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=IPredator Networktunnel files
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+= +openvpn-crypto +freifunk-berlin-openvpn-files +freifunk-berlin-lib-guard
  PROVIDES:=freifunk-berlin-uplink
  PKGARCH:=all
endef

define Package/freifunk-berlin-uplink-ipredator-files/description
  Freifunk Berlin files to setup a tunnel to route all
  upstream traffic via the IPredator.se service
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-uplink-ipredator-files/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/openvpn
	$(CP) ./openvpn/IPredator.se.* $(1)/etc/openvpn
endef

$(eval $(call BuildPackage,freifunk-berlin-uplink-ipredator-files))

# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-openvpn-files
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-openvpn-files
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Freifunk Berlin openVPN files
  URL:=http://pberg.freifunk.net
  DEPENDS+= +openvpn-polarssl
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

define Package/luci-app-ffwizard-pberg/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/openvpn
	$(CP) ./openvpn/* $(1)/etc/openvpn
endef

$(eval $(call BuildPackage,freifunk-berlin-openvpn-files))

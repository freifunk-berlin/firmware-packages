# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ffwizard-pberg
PKG_VERSION:=0.0.2
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-ffwizard-pberg
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=Applications
  TITLE:=Freifunk Prenzlauerberg configuration wizard
  URL:=http://pberg.freifunk.net
  DEPENDS+= +luci-lib-web +luci-mod-freifunk
endef

define Package/luci-app-ffwizard-pberg/description
  Freifunk Wizard for pberg
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./luasrc $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/luasrc
endef

define Package/luci-app-ffwizard-pberg/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/www/luci-static
	$(CP) ./luci-static/* $(1)/www/luci-static
endef

$(eval $(call BuildPackage,luci-app-ffwizard-pberg))

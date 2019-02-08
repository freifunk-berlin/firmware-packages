#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
# Modified 2015 by Freifunk Berlin
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-mod-freifunk-ui
PKG_VERSION:=0.0.4
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-mod-freifunk-ui
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=2. Modules
  TITLE:=Freifunk Public and Admin LuCI UI
  DEPENDS:=+luci-mod-admin-full +luci-lib-json +community-profiles
  PKGARCH:=all
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./luasrc $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
#	$(MAKE) -C $(PKG_BUILD_DIR)/luasrc
endef

define Package/luci-mod-freifunk-ui/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view
	$(CP) $(PKG_BUILD_DIR)/luasrc/controller/* $(1)/usr/lib/lua/luci/controller
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/* $(1)/usr/lib/lua/luci/model
	$(CP) $(PKG_BUILD_DIR)/luasrc/view/* $(1)/usr/lib/lua/luci/view
	$(INSTALL_DIR) $(1)/www
	$(CP) ./htdocs/* $(1)/www
endef

$(eval $(call BuildPackage,luci-mod-freifunk-ui))

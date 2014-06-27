# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ffwizard-pberg
PKG_VERSION:=0.0.3
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-ffwizard-pberg
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Freifunk Prenzlauerberg configuration wizard
  URL:=http://pberg.freifunk.net
  DEPENDS+= +luci-base +luci-mod-freifunk +luci-mod-admin-full
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
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/tools
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view
	$(CP) $(PKG_BUILD_DIR)/luasrc/controller/* $(1)/usr/lib/lua/luci/controller
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/* $(1)/usr/lib/lua/luci/model
	$(CP) $(PKG_BUILD_DIR)/luasrc/tools/* $(1)/usr/lib/lua/luci/tools
	$(CP) $(PKG_BUILD_DIR)/luasrc/view/* $(1)/usr/lib/lua/luci/view
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/rc.local.d
	$(CP) ./rc.local.d/* $(1)/etc/rc.local.d/
	$(INSTALL_DIR) $(1)/etc/openvpn
	$(CP) ./openvpn/* $(1)/etc/openvpn
	$(INSTALL_DIR) $(1)/etc/hotplug.d/net
	$(CP) ./hotplug.d/net/* $(1)/etc/hotplug.d/net/
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(CP) ./lib-upgrade/* $(1)/lib/upgrade/keep.d/
endef

$(eval $(call BuildPackage,luci-app-ffwizard-pberg))

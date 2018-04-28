# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ffwizard-berlin
PKG_VERSION:=0.0.13
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-ffwizard-berlin
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Freifunk Berlin configuration wizard
  URL:=http://berlin.freifunk.net
  DEPENDS+= +luci-base +luci-mod-admin-full +freifunk-policyrouting
  PKGARCH:=all
endef

define Package/luci-app-ffwizard-berlin/description
  Freifunk Wizard for Berlin
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

define Package/luci-app-ffwizard-berlin/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/tools
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view
	$(CP) $(PKG_BUILD_DIR)/luasrc/controller/* $(1)/usr/lib/lua/luci/controller
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/* $(1)/usr/lib/lua/luci/model
	$(CP) $(PKG_BUILD_DIR)/luasrc/tools/* $(1)/usr/lib/lua/luci/tools
	$(CP) $(PKG_BUILD_DIR)/luasrc/view/* $(1)/usr/lib/lua/luci/view
	$(INSTALL_DIR) $(1)/www
	$(CP) ./htdocs/* $(1)/www
	$(INSTALL_DIR) $(1)/etc
	$(CP) ./root/etc/* $(1)/etc
	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(CP) ./root/www/cgi-bin/* $(1)/www/cgi-bin/
endef

$(eval $(call BuildPackage,luci-app-ffwizard-berlin))

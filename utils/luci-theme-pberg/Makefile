# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-pberg
PKG_VERSION:=0.0.2
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-theme-pberg
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=Themes
  TITLE:=Pberg Freifunk Theme
  DEPENDS+=+luci-theme-base
endef

define Package/luci-theme-pberg/description
   Freifunk-Berlin-Prenzlauer-Berg Theme
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-theme-pberg/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(CP) ./luasrc/* $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/www/luci-static
	$(CP) ./luci-static/* $(1)/www/luci-static
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
endef

$(eval $(call BuildPackage,luci-theme-pberg))

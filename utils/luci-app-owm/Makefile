include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-owm
PKG_RELEASE:=0.0.1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-owm
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Luci JSON Export for Open Wireless Map
  DEPENDS:=+luci-lib-web +luci-lib-json +luci-mod-freifunk
endef

define Package/luci-app-owm/description
  Luci JSON Export for Open Wireless Map
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

define Package/luci-app-owm/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(CP) $(PKG_BUILD_DIR)/luasrc/controller/* $(1)/usr/lib/lua/luci/controller
endef

$(eval $(call BuildPackage,luci-app-owm))

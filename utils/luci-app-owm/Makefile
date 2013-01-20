include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-owm
PKG_RELEASE:=0.0.3

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-owm
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Luci JSON Export for Open Wireless Map
  DEPENDS:=+luci-lib-web +luci-lib-json +luci-mod-freifunk +olsrd-mod-jsoninfo
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

define Package/luci-app-owm/postinst
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
	( . /etc/uci-defaults/owm ) && rm -f /etc/uci-defaults/owm
	rm -f /tmp/luci-indexcache
	exit 0
}
endef

define Package/luci-app-owm/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(CP) $(PKG_BUILD_DIR)/luasrc/controller/* $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view
	$(CP) $(PKG_BUILD_DIR)/luasrc/view/* $(1)/usr/lib/lua/luci/view
	$(INSTALL_DIR) $(1)/usr/sbin/
	$(CP) files/owm.lua $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) files/owm-defaults $(1)/etc/uci-defaults/owm
endef

$(eval $(call BuildPackage,luci-app-owm))

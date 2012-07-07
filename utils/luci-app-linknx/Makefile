# $Id: Makefile 1146 2005-06-05 13:32:28Z nbd $

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-linknx
PKG_VERSION:=0.1
PKG_RELEASE:=4

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-linknx
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Eib KNX deamon
  URL:=http://www.auto.tuwien.ac.at/~mkoegler/index.php/eibd
  DEPENDS:=+linknx +luci-lib-web +luci-lib-json +luci-app-statistics +ws-mirror-server +libubox +ubusd +luci-app-eibd
endef

define Package/luci-app-linknx/description
  http://sourceforge.net/apps/mediawiki/linknx
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./luasrc $(PKG_BUILD_DIR)/
		mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

#define Build/Configure
#endef

#define Build/Compile
#	$(MAKE) -C $(PKG_BUILD_DIR)/luasrc
#	$(MAKE) -C $(PKG_BUILD_DIR)/src
#endef

define Package/luci-app-linknx/install
	$(CP) -a ./ipkg/* $(1)/CONTROL/ 2>/dev/null || true
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(CP) $(PKG_BUILD_DIR)/luasrc/controller/linknx.lua $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/linknx
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/cbi/statusjson.lua $(1)/usr/lib/lua/luci/model/cbi
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/cbi/writejson.lua $(1)/usr/lib/lua/luci/model/cbi
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/cbi/linknx/groups.lua $(1)/usr/lib/lua/luci/model/cbi/linknx
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/cbi/linknx/linknx.lua $(1)/usr/lib/lua/luci/model/cbi/linknx
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/cbi/linknx/public_status.lua $(1)/usr/lib/lua/luci/model/cbi/linknx
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/cbi/linknx/rules.lua $(1)/usr/lib/lua/luci/model/cbi/linknx
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/cbi/linknx/types.lua $(1)/usr/lib/lua/luci/model/cbi/linknx
	$(CP) $(PKG_BUILD_DIR)/luasrc/model/cbi/linknx/varlist.lua $(1)/usr/lib/lua/luci/model/cbi/linknx
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/linknx
	$(CP) $(PKG_BUILD_DIR)/luasrc/view/linknx/index.htm $(1)/usr/lib/lua/luci/view/linknx
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./files/etc/uci-defaults/luci-app-linknx $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/ws-mirror-server-linknx $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/ubus-linknx $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ubus-linknx $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/linknx-uci-event.sh $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/ubus-linknx.lua $(1)/usr/bin
	$(INSTALL_DIR) $(1)/www
	$(CP) ./files/www/* $(1)/www
endef

$(eval $(call BuildPackage,luci-app-linknx))

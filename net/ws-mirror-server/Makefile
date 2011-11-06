# $Id$

include $(TOPDIR)/rules.mk

PKG_NAME:=ws-mirror-server
PKG_VERSION:=0.5
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_BUILD_DEPENDS := libwebsockets

include $(INCLUDE_DIR)/package.mk

define Package/ws-mirror-server
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=ws-mirror-server - Websocket Mirror Server for js chat
endef

define Package/ws-mirror-server/description
 ws-mirror-server Websocket Mirror Server for js chat
 use libwebsockets http://git.warmcat.com/cgi-bin/cgit/libwebsockets
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

#define Build/Compile
#	$(MAKE) -C $(PKG_BUILD_DIR)
#endef

#$(call Build/Compile/Default)


define Package/ws-mirror-server/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ws-mirror-server $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,ws-mirror-server))


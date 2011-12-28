# $Id$

include $(TOPDIR)/rules.mk

PKG_NAME:=ws-mirror-server
PKG_VERSION:=0.5
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/ws-mirror-server/default
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=ws-mirror-server - Websocket Mirror Server for js chat
  DEPENDS:=libwebsockets
endef

define Package/ws-mirror-server
  $(Package/ws-mirror-server/default)
  MENU:=1
endef

define Package/ws-mirror-server/description
 ws-mirror-server Websocket Mirror Server for js chat
 use libwebsockets http://git.warmcat.com/cgi-bin/cgit/libwebsockets
endef

define Package/ws-mirror-server-cmd
  $(Package/ws-mirror-server/default)
  TITLE:=ws-mirror-server-cmd - Commandline tool for Websocket Mirror Server
endef

define Package/ws-mirror-server-cmd/description
 ws-mirror-server-cmd Commandline tool for Websocket Mirror Server
 use libwebsockets http://git.warmcat.com/cgi-bin/cgit/libwebsockets
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/ws-mirror-server/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ws-mirror-server.init $(1)/etc/init.d/ws-mirror-server
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ws-mirror-server $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/www
#	$(INSTALL_DATA) ./files/chat.html $(1)/www/chat.html
endef

define Package/ws-mirror-server-cmd/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ws-mirror-server-cmd $(1)/usr/bin/
endef

$(eval $(call BuildPackage,ws-mirror-server))
$(eval $(call BuildPackage,ws-mirror-server-cmd))

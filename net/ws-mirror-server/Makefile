#
# Copyright (C) 2012-2013 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ws-mirror-server
PKG_VERSION:=0.7
PKG_RELEASE:=4

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/ws-mirror-server/default
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=ws-mirror-server - Websocket Mirror Server for js chat
  DEPENDS:=+libwebsockets +zlib \
    +libubox +libubus +ubusd +libblobmsg-json
#    +PACKAGE_libwebsockets_openssl:libopenssl \
#    +PACKAGE_libwebsockets_cyassl:cyassl
endef

define Package/ws-mirror-server
  $(Package/ws-mirror-server/default)
  MENU:=1
endef

define Package/ws-mirror-server/description
 ws-mirror-server Websocket Mirror Server for js chat
 use libwebsockets http://git.warmcat.com/cgi-bin/cgit/libwebsockets
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/ws-mirror-server/postinst
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
	/etc/init.d/ws-mirror-server enable
	/etc/init.d/ws-mirror-server start
	exit 0
}
endef

define Package/ws-mirror-server/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ws-mirror-server.init $(1)/etc/init.d/ws-mirror-server
	$(INSTALL_DATA) ./files/ws-server.key.pem $(1)/etc/ws-server.key.pem
	$(INSTALL_DATA) ./files/ws-server.pem $(1)/etc/ws-server.pem
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ws-mirror-server $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ws-mirror-server-ubus $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/www
	$(INSTALL_DATA) ./files/ws-server.html $(1)/www
endef

$(eval $(call BuildPackage,ws-mirror-server))

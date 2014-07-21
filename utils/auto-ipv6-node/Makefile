# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

PKG_NAME:=auto-ipv6-node
PKG_VERSION:=0.0.7
PKG_RELEASE:=4

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/auto-ipv6-node
  SECTION:=ipv6
  CATEGORY:=IPv6
  TITLE:=Auto IPv6 configuration via olrs Hna6
  URL:=http://pberg.freifunk.net
  DEPENDS:=+PACKAGE_odhcpd:odhcpd +PACKAGE_6relayd:6relayd +olsrd-mod-jsoninfo\
  +luci-base +luci-lib-json
endef

define Package/auto-ipv6-node/description
  Auto IPv6 configuration via olrs Hna6
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/auto-ipv6-node/postinst
#!/bin/sh
if [ -z $${IPKG_INSTROOT} ] ; then
	( . /etc/uci-defaults/zz-auto_ipv6_node ) && rm /etc/uci-defaults/zz-auto_ipv6_node
fi
endef


define Package/auto-ipv6-node/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./src/auto_ipv6_node.lua $(1)/usr/bin
	$(LN) auto_ipv6_node.lua $(1)/usr/bin/auto_ipv6_node
	$(INSTALL_BIN) ./src/auto_ipv6_node_wifi.lua $(1)/usr/bin
	$(LN) auto_ipv6_node_wifi.lua $(1)/usr/bin/auto_ipv6_node_wifi
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./src/auto_ipv6_node.defaults $(1)/etc/uci-defaults/zz-auto_ipv6_node
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./src/auto_ipv6_node.config $(1)/etc/config/auto_ipv6_node
endef

$(eval $(call BuildPackage,auto-ipv6-node))

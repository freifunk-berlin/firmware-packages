# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

PKG_NAME:=auto-ipv6
PKG_VERSION:=0.0.6
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/auto-ipv6
  SECTION:=ipv6
  CATEGORY:=IPv6
  TITLE:=Auto IPv6 Tunnel to 192.88.99.1
  URL:=http://pberg.freifunk.net
  DEPENDS+= \
   +kmod-sit
endef

define Package/auto-ipv6/description
  Auto IPv6 Tunnel to 192.88.99.1 with olsrd and radvd integration
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/auto-ipv6/install
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./src/30-auto-ipv6 $(1)/etc/hotplug.d/iface/30-auto-ipv6
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./src/autoipv6.init $(1)/etc/init.d/autoipv6
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./src/auto-ipv6 $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./src/auto-ipv6.defaults $(1)/etc/uci-defaults/auto-ipv6
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./src/autoipv6.config $(1)/etc/config/autoipv6
endef

$(eval $(call BuildPackage,auto-ipv6))

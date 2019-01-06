include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-network-defaults
PKG_VERSION:=0.1.1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-network-defaults
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin network default configuration
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+= +freifunk-berlin-lib-guard +iwinfo
  PKGARCH:=all
endef

define Package/freifunk-berlin-network-defaults/description
  Freifunk Berlin configuration files for network
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-network-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(CP) ./hotplug.d/iface/* $(1)/etc/hotplug.d/iface/
	$(INSTALL_DIR) $(1)/lib/functions
	$(CP) ./lib/functions/* $(1)/lib/functions/
endef

$(eval $(call BuildPackage,freifunk-berlin-network-defaults))

include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-dhcp-defaults

include ../../freifunk-berlin-generic.mk

define Package/freifunk-berlin-dhcp-defaults
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin dhcp default configuration
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+= +dnsmasq +freifunk-berlin-lib-guard
  PKGARCH:=all
endef

define Package/freifunk-berlin-dhcp-defaults/description
  Freifunk Berlin configuration files for dhcp
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-dhcp-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,freifunk-berlin-dhcp-defaults))


include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-uhttpd-defaults
PKG_SOURCE_DATE:=2019-05-25
PKG_VERSION:=1

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-uhttpd-defaults
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin uhttpd default configuration
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+= +uhttpd +freifunk-berlin-lib-guard
  PKGARCH:=all
endef

define Package/freifunk-berlin-uhttpd-defaults/description
  Freifunk Berlin configuration files for uhttpd
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-uhttpd-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
endef

$(eval $(call BuildPackage,freifunk-berlin-uhttpd-defaults))

include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-olsrd-defaults
PKG_VERSION:=0.0.5
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-olsrd-defaults
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin olsrd default configuration
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+= +olsrd +freifunk-berlin-lib-guard
  PKGARCH:=all
endef

define Package/freifunk-berlin-olsrd-defaults/description
  Freifunk Berlin configuration files for olsrd and olsrd6
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-olsrd-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
endef

$(eval $(call BuildPackage,freifunk-berlin-olsrd-defaults))

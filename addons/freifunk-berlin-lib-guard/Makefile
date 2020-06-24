include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-lib-guard
PKG_SOURCE_DATE:=2019-05-25
PKG_VERSION:=1
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-lib-guard
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin guard function
  URL:=http://github.com/freifunk-berlin/packages_berlin
  PKGARCH:=all
endef

define Package/freifunk-berlin-lib-guard/description
  Freifunk Berlin guard function
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-lib-guard/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,freifunk-berlin-lib-guard))

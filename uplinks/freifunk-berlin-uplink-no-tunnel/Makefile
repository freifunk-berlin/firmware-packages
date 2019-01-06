
include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-uplink-notunnel-files
PKG_VERSION:=0.2.1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin no tunnel files
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+=+freifunk-berlin-lib-guard +kmod-veth +freifunk-berlin-network-defaults
  PROVIDES:=freifunk-berlin-uplink
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  Freifunk Berlin files to setup a uplink without any
  tunnel.
  upstream traffic will be directly routed via your network
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
endef

$(eval $(call BuildPackage,$(PKG_NAME)))


include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-uplink-tunnelberlin-tunneldigger-files
PKG_VERSION:=0.2.1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-uplink-tunnelberlin-tunneldigger-files
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin Networktunnel files
  URL:=http://github.com/freifunk-berlin/firmware-packages
  DEPENDS+= +freifunk-berlin-lib-guard +freifunk-berlin-tunneldigger +freifunk-berlin-network-defaults
  PROVIDES:=freifunk-berlin-uplink
  PKGARCH:=all
endef

define Package/freifunk-berlin-uplink-tunnelberlin-tunneldigger-files/description
  Freifunk Berlin files to setup a tunneldigger tunnel to route all
  upstream traffic to the community-internet-gateways
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-uplink-tunnelberlin-tunneldigger-files/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/* $(1)/etc/uci-defaults
endef

$(eval $(call BuildPackage,freifunk-berlin-uplink-tunnelberlin-tunneldigger-files))

include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-tunneldigger
PKG_RELEASE:=3

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/wlanslovenija/tunneldigger.git
PKG_SOURCE_DATE:=2017-12-13
PKG_SOURCE_VERSION:=d7db350011076d6a83855d412885a29a7d142b6e

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/freifunk-berlin-tunneldigger
  SECTION:=net
  CATEGORY:=Network
  DEPENDS:=+libnl-tiny +kmod-l2tp +kmod-l2tp-eth +librt +libpthread
  TITLE:=L2TPv3 tunnel broker client
  PROVIDES:=tunneldigger
endef

TARGET_CFLAGS += \
	-I$(STAGING_DIR)/usr/include/libnl-tiny \
	-I$(STAGING_DIR)/usr/include \
	-DLIBNL_TINY

define Build/Prepare
	$(call Build/Prepare/Default)
	$(CP) $(PKG_BUILD_DIR)/client/* $(PKG_BUILD_DIR)
endef

define Package/freifunk-berlin-tunneldigger/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/tunneldigger $(1)/usr/bin/tunneldigger
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/tunneldigger.init $(1)/etc/init.d/tunneldigger
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/tunneldigger.hotplug $(1)/etc/hotplug.d/iface/60-tunneldigger
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/config.default $(1)/etc/config/tunneldigger
endef

define Package/freifunk-berlin-tunneldigger/conffiles
/etc/config/tunneldigger
endef

$(eval $(call BuildPackage,freifunk-berlin-tunneldigger))

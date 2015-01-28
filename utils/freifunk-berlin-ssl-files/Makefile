include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-ssl-files
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-ssl-files
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin SSL/HTTPS files
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+= +libustream-polarssl
endef

define Package/freifunk-berlin-ssl-files/description
  Freifunk Berlin SSL/HTTPS files
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-ssl-files/install
	$(INSTALL_DIR) $(1)/etc/ssl/certs
	$(CP) ./files/* $(1)/etc/ssl/certs
endef

$(eval $(call BuildPackage,freifunk-berlin-ssl-files))

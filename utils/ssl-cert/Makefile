# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

PKG_NAME:=ssl-cert
PKG_VERSION:=0.0.1
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/ssl-cert
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=Applications
  TITLE:=SSL Cert for uhttpd/https
  URL:=http://pberg.freifunk.net
  DEPENDS+= +uhttpd
endef

define Package/ssl-cert/description
  SSL Cert for uhttpd/https
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/ssl-cert/install
	$(CP) ./root/* $(1)/
endef

$(eval $(call BuildPackage,ssl-cert))

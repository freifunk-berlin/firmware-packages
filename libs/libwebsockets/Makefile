include $(TOPDIR)/rules.mk

PKG_NAME:=libwebsockets
PKG_VERSION:=2013-03-16
PKG_RELEASE=$(PKG_SOURCE_VERSION)

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=git://git.warmcat.com/libwebsockets
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=b55451c6d20dd64c62594a91af3297a8934b0ec4
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/libwebsockets
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=libwebsockets
  DEPENDS:= +zlib +libopenssl
endef

define Package/libwebsockets/description
 libwebsockets
endef

TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include

define Package/libwebsockets/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/lib/libwebsockets.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libwebsockets))


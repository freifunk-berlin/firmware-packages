include $(TOPDIR)/rules.mk

PKG_NAME:=libwebsockets
PKG_VERSION:=2013-03-16
PKG_RELEASE=$(PKG_SOURCE_VERSION)

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=git://git.warmcat.com/libwebsockets
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=b55451c6d20dd64c62594a91af3297a8934b0ec4
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
PKG_BUILD_PARALLEL:=0
CMAKE_INSTALL:=0

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/libwebsockets/default
  SECTION:=libs
  CATEGORY:=Libraries
  URL:=http://libwebsockets.org/trac/wiki
endef

define Package/libwebsockets
$(Package/libwebsockets/default)
  DEPENDS:=+zlib +PACKAGE_libwebsockets-cyassl:libcyassl +PACKAGE_libwebsockets-openssl:libopenssl
  TITLE:=libwebsockets
endef

define Package/libwebsockets/description
 HTTP libwebsockets.
endef

define Package/libwebsockets/config
	config PACKAGE_libwebsockets-cyassl
		depends on PACKAGE_libwebsockets
		bool "Build with CyaSSL"
		default n
	config PACKAGE_libwebsockets-openssl
		depends on PACKAGE_libwebsockets
		bool "Build with OpenSSL"
		default n
endef



TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include

ifndef CONFIG_PACKAGE_libwebsockets-openssl
CMAKE_OPTIONS += \
        -DWITH_SSL=OFF
endif
ifdef CONFIG_PACKAGE_libwebsockets-cyassl
CMAKE_OPTIONS += \
        -DWITH_CYASSL=1
endif

define Package/libwebsockets/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/lib/libwebsockets.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libwebsockets))

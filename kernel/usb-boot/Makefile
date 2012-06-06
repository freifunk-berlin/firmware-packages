# 
# Copyright (C) 2006-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk
include $(TOPDIR)/package/kernel/modules/usb.mk

PKG_NAME:=usb-boot
PKG_FLAGS:=hold

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/packages

include $(INCLUDE_DIR)/package.mk
ifeq ($(DUMP),)
  -include $(LINUX_DIR)/.config
endif

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define KernelPackage/usb-boot
  SUBMENU:=$(USB_MENU)
  TITLE:=USB Boot support
  KCONFIG:=\
  	CONFIG_NLS=y\
  	CONFIG_USB=y\
  	CONFIG_USB_DEVICEFS=y\
  	CONFIG_USB_EHCI_HCD=y\
  	CONFIG_USB_OHCI_HCD=y\
  	CONFIG_USB_STORAGE=y\
  	CONFIG_USB_UHCI_HCD=y
  DEPENDS:=@USB_SUPPORT @LINUX_2_6 @TARGET_x86
endef

define KernelPackage/usb-boot/description
 USB Boot support.
endef

define KernelPackage/usb-boot/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) ./uci-defaults/usb-boot $(1)/etc/uci-defaults
endef

$(eval $(call KernelPackage,usb-boot))


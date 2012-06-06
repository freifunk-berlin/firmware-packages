# 
# Copyright (C) 2006-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk
include $(TOPDIR)/package/kernel/modules/netdevices.mk

PKG_NAME:=vmxnet3
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

define KernelPackage/vmxnet3
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=VMware VMXNET3 ethernet driver
  DEPENDS:=@PCI_SUPPORT @TARGET_x86
  KCONFIG:=CONFIG_VMXNET3
  FILES:=$(LINUX_DIR)/drivers/net/vmxnet3/vmxnet3.$(LINUX_KMOD_SUFFIX)
  AUTOLOAD:=$(call AutoLoad,50,vmxnet3)
endef

define KernelPackage/vmxnet3/description
 This driver supports VMware's vmxnet3 virtual ethernet NIC.
endef

$(eval $(call KernelPackage,vmxnet3))


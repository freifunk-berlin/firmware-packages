# 
# Copyright (C) 2006-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk
include $(TOPDIR)/package/kernel/modules/netdevices.mk

PKG_NAME:=forcedeth
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

define KernelPackage/forcedeth
  TITLE:=nForce Ethernet support
  FILES:=$(LINUX_DIR)/drivers/net/forcedeth.$(LINUX_KMOD_SUFFIX)
  KCONFIG:=CONFIG_FORCEDETH CONFIG_FORCEDETH_NAPI=y
  DEPENDS:=@LINUX_2_6
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  AUTOLOAD:=$(call AutoLoad,50,forcedeth)
endef


define KernelPackage/forcedeth/description
 Kernel modules for nForce Ethernet.
endef

$(eval $(call KernelPackage,forcedeth))



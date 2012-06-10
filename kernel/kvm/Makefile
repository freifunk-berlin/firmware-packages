# 
# Copyright (C) 2006-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=kvm
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

define KernelPackage/kvm
  SUBMENU:=KVM
  TITLE:=KVM Boot support
  KCONFIG:=\
  	CONFIG_HVC_DRIVER=y\
  	CONFIG_KVM=y\
  	CONFIG_KVM_INTEL=y\
  	CONFIG_KVM_AMD=y\
  	CONFIG_LGUEST=y\
  	CONFIG_KVM_CLOCK=y\
  	CONFIG_KVM_GUEST=y\
  	CONFIG_LGUEST_GUEST=y\
  	CONFIG_PARAVIRT=y\
  	CONFIG_PARAVIRT_CLOCK=y\
  	CONFIG_PARAVIRT_GUEST=y\
  	CONFIG_VMI=y\
  	CONFIG_HW_RANDOM_VIRTIO=y\
  	CONFIG_VIRTIO=y\
  	CONFIG_VIRTIO_BALLOON=y\
  	CONFIG_VIRTIO_BLK=y\
  	CONFIG_VIRTIO_CONSOLE=y\
  	CONFIG_VIRTIO_NET=y\
  	CONFIG_VIRTIO_PCI=y\
  	CONFIG_VIRTIO_RING=y\
  	CONFIG_VIRTUALIZATION=y
  DEPENDS:=@TARGET_x86 @LINUX_2_6
endef

define KernelPackage/kvm/description
 KVM LGUEST PARAVIRT VIRTIO support.
endef

$(eval $(call KernelPackage,kvm))


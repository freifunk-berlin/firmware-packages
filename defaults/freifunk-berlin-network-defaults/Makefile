include $(TOPDIR)/rules.mk

LUCI_TITLE:=Freifunk Berlin network default configuration
LUCI_DEPENDS:= +freifunk-berlin-lib-guard +iwinfo +pingcheck
LUCI_DESCRIPTION:=Freifunk Berlin configuration files for network

define Package/freifunk-berlin-network-defaults/postinst
# noop
endef

include ../../freifunk-berlin-generic.mk

# call BuildPackage - is done via freifunk-berlin-generic.mk --> luci.mk

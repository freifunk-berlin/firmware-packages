#
# Copyright (C) 2016 Freifunk Berlin
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=collectd-snmp-templates
PKG_VERSION:=0.0.1
PKG_RELEASE:=4

UBIQUITI_MIBS_REL=ubnt-mibs_20160803.zip

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/collectd-snmp-templates
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Templates to gather statistics from different SNMP-nodes
  URL:=http://github.com/freifunk-berlin/packages_berlin
  DEPENDS+= +collectd-mod-snmp +snmp-mibs
  PKGARCH:=all
endef

define Package/collectd-snmp-templates/description
  Freifunk Berlin configuration files for statistics
endef

define Download/ubnt_mibs
	URL_FILE:=UBNT-MIBs.zip
	URL:=https://help.ubnt.com/hc/en-us/article_attachments/203306028/
	MD5SUM:=92087a11d75a94c7cfdb81f730642614
	FILE:=$(UBIQUITI_MIBS_REL)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	mkdir -p $(PKG_BUILD_DIR)/ubnt-mibs
	unzip -j $(DL_DIR)/$(UBIQUITI_MIBS_REL) -d $(PKG_BUILD_DIR)/ubnt-mibs
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/collectd-snmp-templates/install
	$(INSTALL_DIR) $(1)/usr/share/snmp/mibs
	$(CP) $(PKG_BUILD_DIR)/ubnt-mibs/* $(1)/usr/share/snmp/mibs
	$(INSTALL_DIR) $(1)/etc/collectd/conf.d
	$(INSTALL_DIR) $(1)/etc/collectd/conf.d-templates
	$(CP) ./files/collectd/* $(1)/etc/collectd/conf.d-templates
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	echo  >$(1)/lib/upgrade/keep.d/collectd-snmp "# by $(PKG_NAME)"
	echo >>$(1)/lib/upgrade/keep.d/collectd-snmp "/etc/collectd/conf.d"
endef

$(eval $(call Download,ubnt_mibs))
$(eval $(call BuildPackage,collectd-snmp-templates))

/*
LuCI - Lua Configuration Interface

Copyright 2012 Patrick Grimm <patrick@lunatiki.de>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id$
*/

Ext.ns(
	'sink',
	'Rooms',
	'Ext.ux'
);

var room = '';
var stage = '';
sink.Structure = [];

Ext.ux.UniversalUI = Ext.extend(Ext.Panel, {
	id: 'ext-panel',
	fullscreen: true,
	layout: 'card',
	itemCls: 'cardCLs',
	items: [{
		id: 'launchscreen',
		cls: 'launchscreen',
		html: '<div><img src="/images/linknx/logo.png" width="154" height="33" /><h1>Welcome to Linknx-Control</h1></div>'
	}],
	backText: 'Back',
	useTitleAsBackText: true,
	initComponent: function() {
		//Statusleiste CButton
		this.CButton = new Ext.Button({
			id: 'CButton',
			text: 'Connect',
			ui: 'dark',
			dock: 'top',
			title: 'C O N N E C T',
			handler: this.onCButton,
			//hidden: false,
			scope: this
		});
		// Alarmliste
		Ext.regModel('Alertlist', {
				fields: ['varName', 'value', 'group', 'commentName', 'onTime', 'onTime_l', 'offTime', 'offTime_l', 'ackTime', 'ackTime_l', 'lastTime', 'lastTime_l', 'ack']
		});
		var groupingBase = {
			itemTpl: '<div class="x-message-alert{ack}">{varName} comment:{commentName} onTime:{onTime_l} offTime:{offTime_l} ackTime:{ackTime_l} lastTime:{lastTime_l} ack:{ack}</div>',
			selModel: {
				mode: 'SINGLE',
				allowDeselect: true
			},
			grouped: true,
			indexBar: true,
			
			onItemDisclosure: {
				handler: function(record, btn, index) {
					varName = record.data.varName;
					group = record.data.group;
					value = record.data.value;
					commentName = record.data.commentName;
					onTime = record.data.onTime;
					offTime = record.data.offTime;
					ackTime = record.data.ackTime;
					lastTime = record.data.lastTime;
					ack = record.data.ack;
					if (ack == 'ack' ) {
						record.data.ack = 'unack';
						var store = Ext.getCmp('alertList');
						refreshcbuttono(store.store,'CButton');
						store.refreshNode(index);
					} else {
						record.data.ack='ack';
						var now = new Date();
						record.data.ackTime=now.getTime();
						var store = Ext.getCmp('alertList');
						store.refreshNode(index);
						if (record.data.offTime > 0) {
							store.store.removeAt(index);
						}
						refreshcbuttono(store.store,'CButton');
					}
					ack = record.data.ack;
					ackTime = record.data.ackTime;
					post_to_url_alm(varName, value, group, ackTime, ack)
				}
			},
	
			store: new Ext.data.Store({
				id: 'AlertListStore',
				model: 'Alertlist',
				sorters: 'varName',
				listeners: {
					add: function(store) {
						refreshcbuttono(store,'CButton');
					},
					load: function(store) {
						refreshcbuttono(store,'CButton');
					},
				},
				getGroupString: function(record) {
					return record.get('varName')[0];
				},
				proxy: {
					type: 'ajax',
					url: '/cgi-bin/luci/linknx/statusjson/almlist/',
				},
				autoLoad: true
			})
		};

		this.alertList = new Ext.List(Ext.apply(groupingBase, {
			id: 'alertList',
			sortable: true,
			floating: true,
			fullscreen: true,
			hideOnMaskTap: true,
			listeners: {
				containertap: function(obj) {
					obj.hide();
				},
				itemtap: function(obj,index) {
					record = obj.store.getAt(index)
					varName = record.data.varName;
					value = record.data.value;
					group = record.data.group;
					commentName = record.data.commentName;
					onTime = record.data.onTime;
					offTime = record.data.offTime;
					ackTime = record.data.ackTime;
					lastTime = record.data.lastTime;
					ack = record.data.ack;
					if (ack == 'ack' ) {
						record.data.ack = 'unack';
						var store = Ext.getCmp('alertList');
						refreshcbuttono(store.store,'CButton');
						store.refreshNode(index);
					} else {
						record.data.ack='ack';
						var now = new Date();
						record.data.ackTime=now.getTime();
						var store = Ext.getCmp('alertList');
						store.refreshNode(index);
						if (record.data.offTime > 0) {
							store.store.removeAt(index);
						}
						refreshcbuttono(store.store,'CButton');
					}
					ack = record.data.ack;
					ackTime = record.data.ackTime;
					post_to_url_alm(varName, value, group, ackTime, ack)
				}
			}
		}))

		this.navigationButton = new Ext.Button({
			id: 'navigationButton',
			hidden: Ext.is.Phone || Ext.Viewport.orientation == 'landscape',
			text: 'Navigation',
			handler: this.onNavButtonTap,
			scope: this
		});

		this.backButton = new Ext.Button({
			text: this.backText,
			ui: 'back',
			handler: this.onUiBack,
			hidden: false,
			scope: this
		});
		var btns = [this.navigationButton];
		if (Ext.is.Phone) {
			btns.unshift(this.backButton);
		}
		this.navigationBar = new Ext.Toolbar({
			ui: 'dark',
			dock: 'top',
			title: this.title,
			items: btns.concat(this.buttons || [])
		});

		this.navigationPanel = new Ext.NestedList({
			store: sink.StructureStore,
			useToolbar: Ext.is.Phone ? false : true,
			updateTitleText: false,
			dock: 'left',
			hidden: !Ext.is.Phone && Ext.Viewport.orientation == 'portrait',
			toolbar: Ext.is.Phone ? this.navigationBar : null,
			listeners: {
				itemtap: this.onNavPanelItemTap,
				scope: this
			}
		});

		this.navigationPanel.on('back', this.onNavBack, this);
		
		if (!Ext.is.Phone) {
			this.navigationPanel.setWidth(250);
		}
		
		this.dockedItems = this.dockedItems || [];
		this.dockedItems.unshift(this.navigationBar);
		this.dockedItems.unshift(this.CButton);

		if (!Ext.is.Phone && Ext.Viewport.orientation == 'landscape') {
			this.dockedItems.unshift(this.navigationPanel);
		}
		else if (Ext.is.Phone) {
			this.items = this.items || [];
			this.items.unshift(this.navigationPanel);
		}

		this.addEvents('navigate');


		Ext.ux.UniversalUI.superclass.initComponent.call(this);
	},

	toggleUiBackButton: function() {
		var navPnl   = this.navigationPanel;
		if (Ext.is.Phone) {
			if (this.getActiveItem() === navPnl) {
				var currList      = navPnl.getActiveItem(),
				currIdx       = navPnl.items.indexOf(currList),
				recordNode    = currList.recordNode,
				title         = navPnl.renderTitleText(recordNode),
				parentNode    = recordNode ? recordNode.parentNode : null,
				backTxt       = (parentNode && !parentNode.isRoot) ? navPnl.renderTitleText(parentNode) : this.title || '',
				activeItem;
				
				if (currIdx <= 0) {
					this.navigationBar.setTitle(this.title || '');
					this.backButton.hide();
				} else {
					this.navigationBar.setTitle(title);
					if (this.useTitleAsBackText) {
						this.backButton.setText(backTxt);
					}
				
					this.backButton.show();
				}
				// on a demo
			} else {
				activeItem = navPnl.getActiveItem();
				recordNode = activeItem.recordNode;
				backTxt    = (recordNode && !recordNode.isRoot) ? navPnl.renderTitleText(recordNode) : this.title || '';
				
				if (this.useTitleAsBackText) {
					this.backButton.setText(backTxt);
				}
				this.backButton.show();
			}
			this.navigationBar.doLayout();
		}

	},

	onCButton: function() {
		// if we already in the nested list
		var activeitem = this.getActiveItem()
		if (activeitem.id == 'alertList') {
			if (Rooms.currentRoom) {
				var card = Rooms.currentRoom.get('card');
				this.setActiveItem(card, 'slide');
			} else {
				this.setActiveItem('launchscreen', 'slide');
			}
			// we were on a demo, slide back into
			// navigation
		} else {
			this.alertList.show();
			//this.alertList.doLayout();
		}
	},

	onUiBack: function() {
		var navPnl = this.navigationPanel;
		
		// if we already in the nested list
		if (this.getActiveItem() === navPnl) {
			navPnl.onBackTap();
			// we were on a demo, slide back into
			// navigation
		} else {
			this.setActiveItem(navPnl, {
				type: 'slide',
				reverse: true
			});
		}
		this.toggleUiBackButton();
		// this.fireEvent('navigate', this, 'launchscreen');
		this.fireEvent('navigate', this, {});
	},

	onNavPanelItemTap: function(subList, subIdx, el, e) {
		var store      = subList.getStore(),
		record     = store.getAt(subIdx),
		recordNode = record.node,
		nestedList = this.navigationPanel,
		title      = nestedList.renderTitleText(recordNode),
		card, preventHide, anim, img, room, stage;
		
		if (record) {
			card        = record.get('card');
			anim        = record.get('cardSwitchAnimation');
			preventHide = record.get('preventHide');
			img         = record.get('img');
			room        = record.get('room');
			stage        = record.get('stage');
		}
		
		if (Ext.Viewport.orientation == 'portrait' && !Ext.is.Phone && !recordNode.childNodes.length && !preventHide) {
			this.navigationPanel.hide();
		}
		
		if (card) {
			if (room) {
				Rooms.currentRoom = record;
				if (img) {
					var Room_Panel_Image
					for (x in card.items.items) {
						if (card.items.items[x].id=='Rooms_Panel_Image') {
							Room_Panel_Image=true;
						}
					}
					if (!Room_Panel_Image) {
						//console.log(img)
						//refresh_stats(img, "1hour", room, stage)
						//refresh_stats(img, "1day", room, stage)
						//refresh_stats(img, "1week", room, stage)
						//refresh_stats(img, "1month", room, stage)
						card.add(img);
					}
				}
				this.setActiveItem(card, 'slide');
				this.currentCard = card;
				this.doComponentLayout();
			} else {
				if (stage) {
					this.setActiveItem(card, 'slide');
					this.currentCard = card;
				}
			}
		}
		
		if (title) {
			this.navigationBar.setTitle(title);
		}
		this.toggleUiBackButton();
		this.fireEvent('navigate', this, record);
	},

	onNavButtonTap: function() {
		this.navigationPanel.showBy(this.navigationButton, 'fade');
	},

	layoutOrientation: function(orientation, w, h) {
		if (!Ext.is.Phone) {
			if (orientation == 'portrait') {
				this.navigationPanel.hide(false);
				this.removeDocked(this.navigationPanel, false);
				if (this.navigationPanel.rendered) {
					this.navigationPanel.el.appendTo(document.body);
				}
				this.navigationPanel.setFloating(true);
				this.navigationPanel.setHeight(400);
				this.navigationButton.show(false);
				//this.insertDocked(0, this.CButton);
			} else {
				this.navigationPanel.setFloating(false);
				this.navigationPanel.show(false);
				this.navigationButton.hide(false);
				this.insertDocked(0, this.navigationPanel);
				//this.insertDocked(0, this.CButton);
			}
			this.navigationBar.doComponentLayout();
		}
		
		Ext.ux.UniversalUI.superclass.layoutOrientation.call(this, orientation, w, h);
	}
});

//refreshcbutton('alertList','CButton');
function refreshcbuttono(store,button) {
			storel = store.data.length;
			cbutton = Ext.getCmp(button);
			if (storel <= 0) {
				cbutton.setText('Recv Message');
				cbutton.removeCls('x-cbutton-disconnect');
				cbutton.removeCls('x-cbutton-connect');
				cbutton.addCls('x-cbutton-message');
			} else {
				var aindex = store.find('ack','unack');
				var unack
				if (aindex == '-1') {
					aindex = store.find('ack','ack');
					cbutton.addCls('x-cbutton-message');
					cbutton.removeCls('x-cbutton-connect');
					cbutton.removeCls('x-cbutton-disconnect');
				} else {
					cbutton.removeCls('x-cbutton-message');
					cbutton.removeCls('x-cbutton-connect');
					cbutton.addCls('x-cbutton-disconnect');
				}
				var aobj=store.getAt(aindex);
				var avarname = aobj.data.varName
				cbutton.setText('Alarm: '+avarname);
				store.each(function(record) {
					times = ['onTime','offTime','ackTime','lastTime']
					for (var i = 0; i < times.length; ++i) {
						name=times[i];
						ontime=record.get(name);
						if (ontime) {
							ontime_d=new Date(parseInt(ontime));
							ontime_l=ontime_d.getFullYear();
							ontime_l=ontime_l+'-'+ontime_d.getMonth();
							ontime_l=ontime_l+'-'+ontime_d.getDay();
							ontime_l=ontime_l+' '+ontime_d.getHours();
							ontime_l=ontime_l+':'+ontime_d.getMinutes();
							ontime_l=ontime_l+':'+ontime_d.getSeconds();
							record.set(name+'_l',ontime_l);
						}
					}
				});
			}
}

function addobj(form,type,clima_req,clima_obj,sortmax) {
	for (r in clima_req) {
		if (clima_req[r]==type) {
			clima_req.splice(r,1);
		}
	}
	if (!clima_req[0]) {
		for (var i = 0; i <= sortmax; i++) {
			for (x in clima_obj) {
				if (clima_obj[x].sortindex <= i) {
					form.add(clima_obj[x]);
					clima_obj.splice(x,1);
				}
			}
		form.doLayout();
		form.doComponentLayout();
		}
	}
}

function recvjsonobjclima1(record,comp) {
	if (record.data.room) {
    		room = record.data.room;
    		stage = record.data.stage;
    		var sortmax = 20;
    		comp.removeAll();
    		comp.doComponentLayout();
///////////////////////////////////////////////CLIMA FORM1//////////////////////
		var clima_obj = [];
		var clima_req = [];
    		var vartype = '_y_';
    		clima_req.push('_y_');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=5
				for (x in obj) {
					if (obj[x].label) {
						obj[x].startValue=-4;
						obj[x].sortindex=6;
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'_y_',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'ezr_t_soll';
    		clima_req.push('ezr_t_soll');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=1
				for (x in obj) {
					if (obj[x].label) {
						obj[x].startValue=-4;
						obj[x].sortindex=1;
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'ezr_t_soll',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = '_bz_soll';
    		clima_req.push('_bz_soll');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=3
				for (x in obj) {
					if (obj[x].label) {
						obj[x].startValue=-4;
						obj[x].sortindex=3;
						obj[x].xtype='selectfield';
						obj[x].options=[
							{text: 'comfort',  value: 'comfort'},
							{text: 'standby', value: 'standby'},
							{text: 'frost',  value: 'frost'}
						]
						if (obj[x].value == "0") {
							obj[x].value="comfort";
						};
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'_bz_soll',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = '_stat_dw_';
    		clima_req.push('_stat_dw_');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=3
				for (x in obj) {
					if (obj[x].label) {
						obj[x].startValue=-4;
						obj[x].sortindex=4;
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'_stat_dw_',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = '_t_ist';
    		clima_req.push('_t_ist');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=2
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=2;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'_t_ist',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'hz_t';
    		clima_req.push('hz_t');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=6;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'hz_t',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'ku_t';
    		clima_req.push('ku_t');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=7;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'ku_t',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'hlk_fk';
    		clima_req.push('hlk_fk');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].xtype='togglefield';
					obj[x].sortindex=8;
					obj[x].inputCls='x-slider-yellow x-slider';
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'hlk_fk',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'hlk_tp';
    		clima_req.push('hlk_tp');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
						obj[x].xtype='togglefield';
						obj[x].sortindex=9;
						obj[x].inputCls='x-slider-red x-slider';
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'hlk_tp',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'bsk';
    		clima_req.push('bsk');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
						obj[x].xtype='togglefield';
						obj[x].sortindex=10;
						obj[x].inputCls='x-slider-red x-slider';
						clima_obj.push(obj[x]);
					}
				};				
				addobj(comp,'bsk',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'sys';
    		clima_req.push('sys');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
						obj[x].xtype='togglefield';
						obj[x].sortindex=10;
						obj[x].inputCls='x-slider-red x-slider';
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'sys',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = '_b_sw_';
    		clima_req.push('_b_sw_');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
						obj[x].startValue=-4;
						obj[x].sortindex=0;
						obj[x].xtype='spinnerfield';
						obj[x].minValue=6;
						obj[x].maxValue=26;
						if (obj[x].value == "0") {
							obj[x].value="23";
						};
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'_b_sw_',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'glob_t_soll_';
    		clima_req.push('glob_t_soll_');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
						obj[x].startValue=-4;
						obj[x].sortindex=0;
						obj[x].xtype='spinnerfield';
						obj[x].minValue=6;
						obj[x].maxValue=26;
						if (obj[x].value == "0" ) {
							obj[x].value="23";
						};
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'glob_t_soll_',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
	};
}

function recvjsonobjclima2(record,comp) {
	if (record.data.room) {
    		room = record.data.room;
    		stage = record.data.stage;
    		var sortmax = 20;
    		comp.removeAll();
    		comp.doComponentLayout();
///////////////////////////////////////////////CLIMA FORM1//////////////////////
		var clima_obj = [];
		var clima_req = [];
    		var vartype = 'LE_';
    		clima_req.push('LE_');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=6
				for (x in obj) {
					if (obj[x].label) {
						obj[x].startValue=-4;
						obj[x].sortindex=6;
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'LE_',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'LK_';
    		clima_req.push('LK_');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=7
				for (x in obj) {
					if (obj[x].label) {
						obj[x].startValue=-4;
						obj[x].sortindex=7;
						clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'LK_',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'ezr_t_soll';
    		clima_req.push('ezr_t_soll');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=1
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=1;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'ezr_t_soll',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = '_bz_soll';
    		clima_req.push('_bz_soll');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=3
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=3;
					obj[x].xtype='selectfield';
					obj[x].options=[
						{text: 'comfort',  value: 'comfort'},
						{text: 'standby', value: 'standby'},
						{text: 'frost',  value: 'frost'}
        				]
					if (obj[x].value == "0") {
						obj[x].value="comfort";
					};
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'_bz_soll',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = '_stat_dw_';
    		clima_req.push('_stat_dw_');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=3
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=4;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'_stat_dw_',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = '_t_ist';
    		clima_req.push('_t_ist');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				var sortindex=2
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=2;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'_t_ist',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'hz_t';
    		clima_req.push('hz_t');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=6;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'hz_t',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'ku_t';
    		clima_req.push('ku_t');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=7;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'ku_t',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'hlk_fk';
    		clima_req.push('hlk_fk');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].xtype='togglefield';
					obj[x].sortindex=8;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'hlk_fk',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'hlk_tp';
    		clima_req.push('hlk_tp');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].xtype='togglefield';
					obj[x].sortindex=9;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'hlk_tp',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'bsk';
    		clima_req.push('bsk');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].xtype='togglefield';
					obj[x].sortindex=10;
					clima_obj.push(obj[x]);
					}
				};				
				addobj(comp,'bsk',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'sys';
    		clima_req.push('sys');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].xtype='togglefield';
					obj[x].sortindex=10;
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'sys',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = '_b_sw_';
    		clima_req.push('_b_sw_');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=0;
					obj[x].xtype='spinnerfield';
					obj[x].minValue=6;
					obj[x].maxValue=26;
					if (obj[x].value == "0") {
						obj[x].value="23";
					};
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'_b_sw_',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'glob_t_soll_';
    		clima_req.push('glob_t_soll_');
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				for (x in obj) {
					if (obj[x].label) {
					obj[x].startValue=-4;
					obj[x].sortindex=0;
					obj[x].xtype='spinnerfield';
					obj[x].minValue=6;
					obj[x].maxValue=26;
					if (obj[x].value == "0" ) {
						obj[x].value="23";
					};
					clima_obj.push(obj[x]);
					}
				};
				addobj(comp,'glob_t_soll_',clima_req,clima_obj,sortmax);
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
	};
}


function recvjsonobjlight1(record,comp) {
	if (record.data.room) {
    		room = record.data.room;
    		stage = record.data.stage;
    		var sortmax = 20;
    		comp.removeAll();
    		comp.doComponentLayout();
///////////////////////////////////////////////LIGHT FORM1//////////////////////
    		var vartype = 'hw';
    		var varclass = 'bel';
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+varclass+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				comp.add(obj);
				comp.doLayout();
				comp.doComponentLayout();
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
    		var vartype = 'snd';
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				comp.add(obj);
				comp.doLayout();
				comp.doComponentLayout();
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
	};
}

function recvjsonobjlight2(record,comp) {
	if (record.data.room) {
    		room = record.data.room;
    		stage = record.data.stage;
    		var sortmax = 20;
    		comp.removeAll();
    		comp.doLayout();
///////////////////////////////////////////////LIGHT FORM2//////////////////////
    		var vartype = 'e_a';
    		var varclass = 'bel';
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+varclass+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				comp.add(obj);
				comp.doLayout();
				comp.doComponentLayout();
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
//	};
	};
}

function recvjsonobjsun1(record,comp) {
	if (record.data.room) {
    		room = record.data.room;
    		stage = record.data.stage;
    		var sortmax = 20;
    		comp.removeAll();
    		comp.doLayout();
////////////////////////////////////////////SUNBLIND FORM1//////////////////////
    		var vartype = 'auf_ab';
		Ext.Ajax.request({
			url: '/cgi-bin/luci/linknx/statusjson/'+room+'/'+vartype+'/',
			success: function(response, opts) {
				var obj = Ext.decode(response.responseText);
				comp.add(obj);
				comp.doLayout();
				comp.doComponentLayout();
			},
			failure: function(response, opts) {
				console.log('server-side failure with status code ' + response.status);
			}
		});
//	};
	};
}


sink.Main = {
    init: function() {
        this.ui = new Ext.ux.UniversalUI({
            title: Ext.is.Phone ? 'Linknx' : 'Linknx Control',
            useTitleAsBackText: false,
            navigationItems: sink.StructureStore,
            listeners: {
                navigate: this.onNavigate,
                scope: this
            }
        });
    },

    onNavigate: function(ui, record) {
    	    if (record.data) {
    	    if (record.data.room) {
    	       var card        = record.get('card');
               var anim        = record.get('cardSwitchAnimation');
               var preventHide = record.get('preventHide');
               Rooms.currentRoom = record;
    	       FormUpdate_address = '/cgi-bin/luci/linknx/statusjson/'+record.data.room+'/';
    	       if ( 0 == record.data.room.search(/RLT.+/)) {
           	   	var comp_form1=Ext.getCmp('Clima_form1');
           	   	if (comp_form1) {
           	   		recvjsonobjclima2(Rooms.currentRoom,comp_form1);
           	   	}
               } else {
           	   	var comp_form1=Ext.getCmp('Clima_form1');
           	   	if (comp_form1) {
           	   		recvjsonobjclima1(Rooms.currentRoom,comp_form1);
           	   	}
           	   	var comp_form2=Ext.getCmp('Light_form1');
           	   	if (comp_form2) {
           	   		recvjsonobjlight1(Rooms.currentRoom,comp_form2);
           	   	}
           	   	var comp_form3=Ext.getCmp('Light_form2');
           	   	if (comp_form3) {
           	   		recvjsonobjlight2(Rooms.currentRoom,comp_form3);
           	   	}
           	   	var comp_form4=Ext.getCmp('Sunblind_form1');
           	   	if (comp_form4) {
           	   		recvjsonobjsun1(Rooms.currentRoom,comp_form4);
           	   	}
               }
    	       ui.setActiveItem(card, 'slide');
               ui.currentCard = card;
    	    }
    	    }
    },
};

Rooms.Panel = new Ext.TabPanel({
	id: 'Rooms_Panel',
	fullscreen: true,
	cardSwitchAnimation: 'slide',
	sortable: true,
	activeItem: 'clima',
	bodyBorder: '0',
	margin: '0',
	padding: '0',
	layout: 'hbox',
	items: [{
		title: 'Clima',
		xtype: 'form',
		id: 'clima',
		scroll: 'vertical',
		fullscreen: true,
		bodyBorder: '0',
		margin: '0',
		padding: '0',
		items: [{
			id: 'Room_Clima1_fieldset',
			bodyPadding: '0',
			xtype: 'fieldset',
			items: {
				id: 'Clima_form1',
				xtype: 'fieldset',
				margin: '0',
				padding: '0',
				bodyPadding: '0',
				defaults: {
					margin: '0',
					padding: '0',
					xtype: 'textfield',
					labelAlign: 'left',
					labelWidth: '60%',
					listeners:{
						change:	function (sliderfield,thumb,oldValue,newValue) {
							change_event(sliderfield,thumb,oldValue,newValue);
						},
						spin:	function (slider, newValue, updown) {
							change_number_event(slider, newValue, '0');
						},
						focus: function (slider) {
							focus_event(slider);
						},
						blur: function (slider) {
							blur_event(slider);
						},
					}
				}
			}
		}]
	},{
		title: 'Light',
		xtype: 'form',
		id: 'light',
		scroll: 'vertical',
		padding: '0',
		items: [{
			id: 'Room_Light1_fieldset',
			xtype: 'fieldset',
			bodyPadding: '0',
			items: {
				id: 'Light_form1',
				bodyPadding: '0',
				defaults: {
					xtype: 'sliderfield',
					labelAlign: 'top', 
					labelWidth: '100%',
					listeners:{
						change:	function (sliderfield,thumb,oldValue,newValue) {
							change_event(sliderfield,thumb,oldValue,newValue);
							}
					}
				}
			}
		},{
			id: 'Room_Light2_fieldset',
			xtype: 'fieldset',
			bodyPadding: '0',
			items: {
				id: 'Light_form2',
				bodyPadding: '0',
				defaults: {
					xtype: 'togglefield',
					labelAlign: 'left', 
					labelWidth: '60%',
					listeners:{
						change:	function (sliderfield,thumb,oldValue,newValue) {
							change_event(sliderfield,thumb,oldValue,newValue);
						}
					}
				}
			}
		}]
	},{
		title: 'Sunblind',
		xtype: 'form',
		id: 'sunblind',
		scroll: 'vertical',
		padding: '0',
		items: [{
			id: 'Room_Sunblind1_fieldset',
			xtype: 'fieldset',
			bodyPadding: '0',
			items: {
				id: 'Sunblind_form1',
				bodyPadding: '0',
				defaults: {
					xtype: 'togglefield',
					labelAlign: 'left', 
					labelWidth: '60%',
				}
			}
		}]
	}]
})

/////////////////////////RAUM MODEL/////////////////////////////////////////////
Ext.regModel('RoomModel', {
    fields: [
        {name: 'text',        type: 'string'},
        {name: 'stage',       type: 'string'},
        {name: 'room',        type: 'string'},
        {name: 'preventHide', type: 'boolean'},
        {name: 'cardSwitchAnimation'},
        {name: 'card'},
        {name: 'img'}
    ]
});

Ext.Ajax.request({
	url: '/cgi-bin/luci/linknx/statusjson/structure/',
	success: function(jsonstage, opts) {
		var jsonstageobj = Ext.decode(jsonstage.responseText);
		var jsonroomsobj = [];
		var jsonstagename;
		var jsonstagecomment;
		for (x in jsonstageobj) {
			if (jsonstageobj[x].stage) {
				if (jsonroomsobj[0]) {
					for (z in jsonroomsobj) {
						if (jsonroomsobj[z].room) {
							jsonroomsobj[z].card=Rooms.Panel;
							jsonroomsobj[z].leaf=true;
						};
					};
					sink.Structure.push({
						id: stagename,
						text: stagecomment,
						stage: stagename,
						card: new Ext.Component({
							xtype: 'fieldset',
							id: 'Stage_Panel_Image',
							title: 'Image',
							html: '<img src="/images/cbid.linknx_group.'+stagename+'.img" />'
                				}),
						items: jsonroomsobj
					});
					jsonroomsobj = [];
					stagename='';
					stagecomment='';
				}
			} else {
				stagename=jsonstageobj[x].name;
				stagecomment=jsonstageobj[x].comment;
				for (y in jsonstageobj) {
					if (jsonstageobj[y].stage == stagename) {
						var statlist = jsonstageobj[y].statlist;
						for (z in statlist) {
							statlist[z].html = '<img src="'+statlist[z].html+'" width="700" height="200" />';
						}
						jsonstageobj[y].img = new Ext.form.FormPanel({
							xtype: 'form',
							id: 'Rooms_Panel_Image',
							title: 'Image',
							scroll: 'vertical',
							padding: '0',
							items: {
								id: 'Rooms_Panel_Image_fieldset',
								xtype: 'fieldset',
								bodyPadding: '0',
								items: statlist,
							}
						}),
						jsonroomsobj.push(jsonstageobj[y]);
					}
				}
			}
		};
		sink.StructureStore = new Ext.data.TreeStore({
		    model: 'RoomModel',
		    root: {
			items: sink.Structure
		    },
		    proxy: {
			type: 'ajax',
			reader: {
			    type: 'tree',
			    root: 'items'
			}
		    }
		});
		Ext.setup({
		    tabletStartupScreen: 'resources/img/tablet_startup.png',
		    phoneStartupScreen: 'resources/img/phone_startup.png',
		    icon: 'resources/img/icon.png',
		    glossOnIcon: false,
		    onReady: function() {
			sink.Main.init();
		    }
		});
	},
	failure: function(response, opts) {
			console.log('server-side failure with status code ' + response.status);
	}
});

//focus_event(slider)
function focus_event(slider) {
	FormUpdate_enable = 0;
	slider.startValue = -99;
}
//focus_event(slider)
function blur_event(slider) {
	FormUpdate_enable = 1;
	slider.startValue = -3;
}

//change_event(slider, thumb, oldValue, newValue)
function change_event(slider, thumb, newValue, oldValue) {
	if (FormUpdate_enable = 1) {
		if(typeof newValue == "object"){
			var VAL = thumb;
			var ID = slider.getId();
			var TAG = slider.tagname;
			var GROUP = slider.group;
			post_to_url(ID, VAL, TAG, GROUP);
		} else {
			if (oldValue != newValue) {
				var SVAL = slider.startValue;
				var VAL = newValue;
				if (SVAL==-1) {
					slider.startValue = 0;
				} else {
					var ID = slider.getId();
					var TAG = slider.tagname;
					var GROUP = slider.group;
					slider.startValue = -3;
					post_to_url(ID, VAL, TAG, GROUP);
				};
			};
		};
	}
}
//change_number_event(slider, newValue, oldValue)
function change_number_event(slider, newValue, oldValue) {
	if (FormUpdate_enable = 1) {
			if (oldValue != newValue) {
				var SVAL = slider.startValue;
				var VAL = newValue;
				if (SVAL==-1) {
					slider.startValue = 0;
				} else {
					var ID = slider.getId();
					var TAG = slider.tagname;
					var GROUP = slider.group;
					slider.startValue = -3;
					post_to_url(ID, VAL, TAG, GROUP);
				};
			}
	}
}


function refresh_stats(obj, span, room, stage) {
	//http://104.13.8.83/cgi-bin/luci/linknx/graph/ezr/R301/?host=OpenWrt_OG3&timespan=1hour&json
	path = '/cgi-bin/luci/linknx/graph';
	path = path+'/ezr/'+room+'?host=OpenWrt_'+stage+'&timespan='+span+'&json'
	var xmlHttpReq = false;
	var self = this;
	// Mozilla/Safari
	if (window.XMLHttpRequest) {
		self.xmlHttpReq = new XMLHttpRequest();
	}
	// IE
	else if (window.ActiveXObject) {
		self.xmlHttpReq = new ActiveXObject("Microsoft.XMLHTTP");
	}
	self.xmlHttpReq.open("GET", path, true);
	self.xmlHttpReq.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
	self.xmlHttpReq.send();
	console.log('refresh_stats')
}

function post_to_url(varName, value, tagName, group) {
	var jdata = {};
	jdata.id = CONFIG.id;
	jdata.name = varName;
	jdata.value = value;
	jdata.group = group;
	jdata.tagname = tagName;
	jdata.comment = "";
	jdata.ontime = "";
	jdata.offtime = "";
	jdata.acktime = "";
	jdata.lastime = "";
	jdata.ack = "";
	var JSONobj = JSON.stringify(jdata);
	socket_di.send(JSONobj);
}


function post_to_url_alm(varName, value, group, ackTime, ack) {
	var jdata = {};
	jdata.id = CONFIG.id;
	jdata.name = varName;
	jdata.value = value;
	jdata.group = group;
	jdata.comment = "";
	jdata.ontime = "";
	jdata.offtime = "";
	jdata.acktime = ackTime;
	jdata.lastime = "";
	jdata.ack = ack;
	var JSONobj = JSON.stringify(jdata);
	socket_di.send(JSONobj);
}

//****************************Websocket*****************************************
var CONFIG = { debug: false
             , id: null    // set in onConnect
             , last_message_time: 1
             , focus: true //event listeners bound in onConnect
             , unread: 0 //updated in the message-processing loop
             , timeout: 3000
             };

function get_appropriate_ws_url()
{
	var pcol;
	var u = document.URL;
	var n;

	/*
	 * We open the websocket encrypted if this page came on an
	 * https:// url itself, otherwise unencrypted
	 */

	if (u.substring(0, 5) == "https") {
		pcol = "wss://";
		u = u.substr(8);
	} else {
		pcol = "ws://";
		if (u.substring(0, 4) == "http")
			u = u.substr(7);
	}

	u = u.split('/');
	n = u[0].split(':');
	if (n[1]) {
		return pcol + u[0];
	} else {
		//return pcol + u[0]+':7681';
		return pcol + u[0]+':7682';
	}
}

function startWs() {
	try {
		socket_di = new WebSocket(get_appropriate_ws_url(),"lws-mirror-protocol");
		socket_di.onopen = function(evt) { ws_onOpen(evt) };
		socket_di.onclose = function(evt) { ws_onClose(evt) };
		socket_di.onmessage = function(evt) { ws_onMessage(evt) };
		socket_di.onerror = function(evt) { ws_onError(evt) };
	} catch (err) {
		console.log(" websocket catch timeout: 3000 ms");
	        console.log(err);
		setTimeout(startWs, CONFIG.timeout);
	}
}
var cbutton;
var panel;
startWs();


function ws_onOpen(evt)
	{
		CONFIG.id   = evt.timeStamp;
		cbutton = Ext.getCmp('CButton');
		if (cbutton) {
			cbutton.setText('WS Connect');
			cbutton.removeCls('x-cbutton-disconnect');
			cbutton.removeCls('x-cbutton-message');
			cbutton.addCls('x-cbutton-connect');
			cbutton.show();
			cbutton.doComponentLayout();
		}
		console.log(" websocket connection opened ");
	}

function ws_onMessage(evt)
	{
		var msgd=evt.data;
		var msgd = JSON.parse(evt.data);
		var varname;
		var value;
		var alarm;
		if (msgd.id == CONFIG.id) {
			return 0;
		}
		config_id=msgd.id;
		varname=msgd.name;
		value=msgd.value;
		group=msgd.group;
		comment=msgd.comment;
		onTime=msgd.ontime;
		offTime=msgd.offtime;
		ackTime=msgd.acktime;
		lastTime=msgd.lastime;
		ack=msgd.ack;
		element = Ext.getCmp(varname);
		store = Ext.getCmp('alertList');
		panel = Ext.getCmp('ext-panel');
		cbutton = Ext.getCmp('CButton');
       		var now = new Date();
		if (element) {
			var oldval = element.getValue();
			var newval = value;
			if (oldval != newval) {
				element.startValue=-1;
				element.setValue(newval);
			}
		}
		var sindex = store.store.find('varName',varname);
		if (ack == 'unack') {
			if (sindex < 0) {
				store.show();
				store.store.add([{varName: varname, value: value, group: group, commentName: comment, onTime: onTime, offTime: offTime, ackTime: ackTime, lastTime: lastTime, ack: ack}]);
				cbutton.setText('Alarm: '+varname+' Value: '+value);
				cbutton.removeCls('x-cbutton-message');
				cbutton.removeCls('x-cbutton-connect');
				cbutton.addCls('x-cbutton-disconnect');
			} else {
				var aobj=store.store.getAt(sindex);
				aobj.data.value=value;
				aobj.data.group=group;
				aobj.data.commentName=comment;
				aobj.data.onTime=onTime;
				aobj.data.offTime=offTime;
				aobj.data.ackTime=ackTime;
				aobj.data.lastTime=lastTime;
				aobj.data.ack=ack;
				store.refreshNode(sindex);
				cbutton.setText('Alarm: '+varname+' Value: '+value);
				cbutton.removeCls('x-cbutton-message');
				cbutton.removeCls('x-cbutton-connect');
				cbutton.addCls('x-cbutton-disconnect');
			}
		} else if (ack == 'ack') {
			if (sindex >= 0) {
				var aobj=store.store.getAt(sindex);
				if (offTime > 0) {
					store.store.removeAt(sindex);
				} else {
					aobj.data.value=value;
					aobj.data.group=group;
					aobj.data.commentName=comment;
					aobj.data.onTime=onTime;
					aobj.data.offTime=offTime;
					aobj.data.ackTime=ackTime;
					aobj.data.lastTime=lastTime;
					aobj.data.ack=ack;
					store.refreshNode(sindex);
				}
			}
			if (Rooms.currentRoom) {
				var card = Rooms.currentRoom.get('card');
				panel.setActiveItem(card, 'slide');
			} else {
				panel.setActiveItem('launchscreen', 'slide');
			}
		}
		refreshcbuttono(store.store,'CButton');
	}

function ws_onClose(evt)
	{
		cbutton = Ext.getCmp('CButton');
		if (cbutton) {
			cbutton.setText('Disconect. Retry every 3 s');
			cbutton.removeCls('x-cbutton-disconnect');
			cbutton.removeCls('x-cbutton-message');
			cbutton.removeCls('x-cbutton-connect');
			cbutton.addCls('x-cbutton-disconnect');
			cbutton.show();
			cbutton.doComponentLayout();
		}
		console.log(" websocket connection CLOSED timeout: 3000 ms");
		setTimeout(startWs, CONFIG.timeout);
	}
//****************************Websocket*****************************************


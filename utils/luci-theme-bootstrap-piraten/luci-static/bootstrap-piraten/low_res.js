function to24em(){ //set page width to effectively 24em	
	document.getElementsByTagName("body")[0].style.fontSize = window.innerWidth/24 +'px'
}

function getNavElement(class_name){
	var uls = document.getElementsByTagName('ul')
	for(var i = 0; i < uls.length; i++){
		if(uls[i].getAttribute('class').indexOf(class_name)!=-1) return(uls[i])
	}
	return(false)	
}


function getChildrenByTagName(el, tag){
	if(!el) return([])
	var children 	= el.childNodes,
		result		= []

	for(var i=0; i<children.length; i++){
		if(children[i].nodeName==tag) result.push(children[i])
	}
	return(result)
}

function withChildrenByTagNameDo(el, tag, fnc){
	if(!el) return(false)
	var children = getChildrenByTagName(el, tag)
	for(var i=0; i<children.length; i++) fnc(children[i],i)
}

function getChildrenByType(el, tag){
	if(!el) return([])
	var children 	= el.childNodes,
		result		= []

	for(var i=0; i<children.length; i++){
		if(children[i].nodeType==tag) result.push(children[i])
	}
	return(result)
}

function withChildrenByTypeDo(el, type, fnc){
	if(!el) return(false)
	var children = getChildrenByType(el, type)
	for(var i=0; i<children.length; i++) fnc(children[i])
}


function ulSubstitute(ul, donottoggle){

	function hideAll(){
		var uls = document.getElementsByTagName('ul')
		for(var i = 0; i < uls.length; i++){
			if(uls[i].getAttribute('class')){
				if(uls[i].getAttribute('class').indexOf('mobile_nav')!=1){
					uls[i].style.display = 'none'
				}
			}
		}
	}

	function show(x, toggle){
		if(toggle){
			return(function(){
				var off = false
				if(this.getAttribute('class')== 'open'){			
					hideAll()
					x.style.display='block'
					this.setAttribute('class', 'hide')
				}else{
					hideAll()
					this.setAttribute('class', 'open')
				}
			})
		}else{
			return(function(){
					hideAll()
					x.style.display='block'				
			})
		}
	}

	if(getChildrenByTagName(ul, 'LI').length==0){
		if(ul) ul.parentNode.removeChild(ul)
		return(false)
	}
	var	open	= document.createElement("DIV"),
		close	= document.createElement("DIV")

	open.setAttribute('class', 'open')
	open.onmousedown = show(ul, !donottoggle)

	ul.parentNode.replaceChild(open, ul)
	ul.setAttribute('class', 'mobile_nav')
	ul.style.display='none'

	document.getElementsByTagName('body')[0].appendChild(ul)

	withChildrenByTagNameDo(ul,'LI', function(child){
		withChildrenByTypeDo(child, 3, function(grandchild){	
			grandchild.parentNode.removeChild(grandchild)
		})
		withChildrenByTagNameDo(child,'UL', function(list){
			var	li 	= document.createElement("LI"),
				back= document.createElement("DIV")

			back.setAttribute('class', 'back')
			back.onmousedown = show(ul)

			li.appendChild(back)
			li.setAttribute('class', 'level_down')		
			li.appendChild(list.previousSibling.cloneNode())
			list.insertBefore(li, list.firstChild)			
			ulSubstitute(list, 1)
		})
		
	})
}


function reorderTables(){
	var tables_ = document.getElementsByTagName('TABLE'),
		tables	= []

	for(var i=0; i<tables_.length; i++){
		tables.push(tables_[i])
	}
		
	for(var k=0; k<tables.length; k++){
		var table 		= tables[k],
			thead		= table.getElementsByTagName('thead')[0],
			tbody		= table.getElementsByTagName('tbody')[0]||table,
			firstrow	= getChildrenByTagName(thead||tbody, 'TR')[0],
			headers		= getChildrenByTagName(firstrow, 'TH'), //does not work with multicolumn!		
			div			= document.createElement('DIV')
		
		withChildrenByTagNameDo(tbody, 'TR', function(row,i){
			var	rep_table	= document.createElement('TABLE'),
				row_sub		= document.createElement('DIV')

			withChildrenByTagNameDo(row, 'TD', function(data,j){
				var	rep_row	= document.createElement('TR')
				if(headers && headers[j]){
					rep_row.appendChild(headers[j].cloneNode())
				}
				rep_row.appendChild(data)
				rep_table.appendChild(rep_row)									
			})
			row_sub.setAttribute('class','row_substitute')
			row_sub.appendChild(rep_table)		
			if(rep_table.childNodes.length>0) div.appendChild(row_sub)
		})


		table.parentNode.replaceChild(div, table)
	}
}

var checkbox_substitutes = []

function replaceCheckboxes(){

	function toggleCheckbox(checkbox, checkmark){
		return(function(){
			checkbox.checked = !checkbox.checked
			checkmark.setAttribute('class', 
				checkmark.getAttribute('class') == 'on'
				? 'off' 
				: 'on'
			)
			checkbox.onchange()
			checkbox.onclick()			
		})
	}

	function refresh(checkbox, checkmark){
		return(function(){
			checkmark.setAttribute('class', checkbox.getAttribute('checked') == 'checked' ? 'on' : 'off')
			checkbox.onchange()
			checkbox.onclick()
		})
	}

	function reset(checkbox, checkmark){
		return(function(){
			checkbox.checked = checkbox.defaultChecked
			checkmark.setAttribute('class', 
				checkbox.defaultChecked 
				? 'on' 
				: 'off'
			)
			checkbox.onchange()
			checkbox.onclick()
		})
	}

	var inputs		= document.getElementsByTagName('input'),
		checkboxes	= []

	for(var i=0; i<inputs.length; i++){
		if(inputs[i].getAttribute('type')=='checkbox') checkboxes.push(inputs[i])
	}

	for(var i=0; i<checkboxes.length; i++){
		var checkbox 	= checkboxes[i],
			div 		= document.createElement('DIV'),
			checkmark	= document.createElement('DIV')

		div.setAttribute('class', checkbox.getAttribute('class')+' checkbox_substitute')
		div.onclick = toggleCheckbox(checkbox, checkmark)
		div.refresh = refresh(checkbox, checkmark)
		div.refresh()		

		div.reset = reset(checkbox, checkmark)

		div.appendChild(checkmark)
		checkbox.parentNode.insertBefore(div, checkbox)
		checkbox.setAttribute('style', 'display:none')
		checkbox_substitutes.push(div)
	}
		
	var forms = document.getElementsByTagName('form')

	for(var i=0; i<forms.length; i++){
		forms[i].onreset = function(){
			for(var j=0; j<checkbox_substitutes.length; j++){
				checkbox_substitutes[j].reset()
			}
			return(true)			
		}
	}
}


function lowResSetup(media){
	if(window.innerWidth<=740){
		ulSubstitute(getNavElement('nav'))
		replaceCheckboxes()
		reorderTables();
		var a = document.createElement('link');
		a.setAttribute('rel','stylesheet');
		a.setAttribute('href',media+'/low_res.css');
		document.getElementsByTagName('head')[0].appendChild(a);
		to24em()
		window.onresize = to24em
	}	
}

# Reference jQuery
$ = jQuery

class ScrollTable
	constructor: (@options) ->
		defaults =
			debug: true
			selector:
				row: '.st-row'
				space: '.st-space'
			view:
				start: 0
				end: 0
				distance: 60
			reload:
				last: -1000
				min: 10
			clean:
				distance: 120
			orderBy: []
			filter: {}
		@settings = $.extend defaults, options
		@el = @settings.el
		@loading = off
		@name = @el.attr('data-scrolltable');
		@infoUrl = Routing.generate('scrolltable_info', {'name': @name})
		@rowsUrl = Routing.generate('scrolltable_rows', {'name': @name})
		@settings.lineHeight = @el.find(@settings.selector.row).first().outerHeight(); 
		@resize () => 
			@fill()
			@scroll()
			$(window).on('scroll', @scroll)
		
	log: (msg) ->
		console?.log msg if @settings.debug
	
	addFilterParam: (string) =>
		for key, value of @settings.filter
			string += '&' if string isnt ''
			string += 'f[\''+key+'\']='+value
		return string
		
	addArrayParm: (string, key, array) =>
		for value in array
			string += '&' if string isnt ''
			string += key+'[]='+value
		return string
	addOrderByParam: (string) =>
		@addArrayParm(string, 'o', @settings.orderBy)
	addRowParam: (string, items) =>
		@addArrayParm(string, 'r', items)
	info: (callback) ->
		$.ajax
			url: @infoUrl
			data: @addFilterParam('')
			type: 'POST'
			dataType: 'xml'
			success: (info) =>
				callback({rows: $(info).find('rc').text() })
				
	resize: (callback) ->
		@info((info) =>
			#@log(info);
			@settings.rows = info.rows*1
			@el.height(info.rows * @settings.lineHeight + 'px')
			callback()
		)
	refresh: =>
		@resize () =>
			@el.find(@settings.selector.row).remove()
			@el.find(@settings.selector.space).remove().first().appendTo(@el);
			@fill()
			@settings.reload.last = -1000
			@settings.view.start = 0
			@settings.view.end = 0
				
			@scroll()
	fill: ->
		rows = @el.find(@settings.selector.row)
		space = @el.find(@settings.selector.space).detach().first()
		@settings.positions = []
		for row in rows
			pos = $(row).attr('data-pos')*1
			nextsmaller = -1
			for p in @settings.positions
				nextsmaller = p if p < pos
			@settings.positions.push pos
			# if no row before pos and pos greater then 0
			if nextsmaller < 0 and pos > 0
				$(row).before(space.clone().height(pos * @settings.lineHeight+'px'))
			# if an row is before pos but not on pos - 1
			if nextsmaller > 0 and (nextsmaller + 1) < pos
				$(row).before(space.clone().height((pos-nextsmaller-1) * @settings.lineHeight+'px'))
			#@log('pos: '+pos+' next: '+nextsmaller)
		
		if @settings.positions.length > 0
			footerSpaceSize = @settings.rows - @settings.positions[@settings.positions.length - 1] - 1
		else
			footerSpaceSize = @settings.rows
		if footerSpaceSize > 0
			@el.append(space.clone().height((footerSpaceSize * @settings.lineHeight)+'px'))
	
	pixelToRow:(pixel) ->
		Math.floor(pixel / @settings.lineHeight)
	
	scroll: =>
		return off if @loading is on
		viewtop = $(document).scrollTop() - @el.position().top
		return off if Math.abs(@settings.reload.last - viewtop) < (@settings.reload.min * @settings.lineHeight)
		@settings.reload.last = viewtop
		viewheight = window.innerHeight
		viewstartrow = @pixelToRow(viewtop)
		viewendrow = @pixelToRow(viewtop+viewheight)
		startrow = viewstartrow - @settings.view.distance
		endrow = viewendrow + @settings.view.distance
		startrow = 0 if startrow < 0
		endrow = @settings.rows - 1 if endrow >= @settings.rows
		@log('viewstartrow: '+viewstartrow+' viewendrow: '+viewendrow+' startrow: '+startrow+' endrow: '+endrow+' @el.position().top: '+@el.position().top)
		if (@settings.view.start isnt startrow or @settings.view.end isnt endrow)
			@loading = on
			@settings.view.start = startrow
			@settings.view.end = endrow
			@loadRows(startrow, endrow)
			return on
		return off
	
	loadRows: (start, end) =>
		@log('load '+start+' '+end);
		#@loading = off
		#return;
		range = [start..end]
		items = $.grep range, (item) =>
			if $.inArray(item, @settings.positions) < 0
				return 1
			else
				return 0
		if items.length < 1
			@loading = off
			return
		params = ''
		params = @addRowParam(params, items)
		params = @addFilterParam(params)
		params = @addOrderByParam(params)
		$.ajax
			url: @rowsUrl
			data: params
			type: 'POST'
			dataType: 'html'
			success: (response) =>
				rows = $(response).find(@settings.selector.row)
				#@log(rows)
				for row in rows
					@addRow(row)
				@loading = off
				@cleanup(start, end) if @settings.clean.distance > 0
				@fill()
				# check if user has moved while table was loading
				@scroll()
	addRow: (row) =>
		pos = $(row).attr('data-pos')*1
		if @settings.positions.length is 0
			@el.append(row)
			@settings.positions.push(pos)
		#@log(row)
		min = minpos = @settings.rows
		for p, i in @settings.positions
			continue if p is pos
			distance = Math.abs(p - pos)
			if distance < min
				min = distance
				minpos = p
			break if distance <= 1 or p > pos
				
		#@log('pos: '+pos+' p:' + p + ' min: ' + min + ' minpos:' + minpos + ' distance:'+distance)
		#@log($('[data-pos="'+minpos+'"]'))
		if minpos < pos
			$(row).insertAfter('[data-pos="'+minpos+'"]')
			@settings.positions.splice(minpos,0,pos)
		else
			$(row).insertBefore('[data-pos="'+minpos+'"]')
			@settings.positions.splice(minpos-1,0,pos)
	cleanup: (start, end) =>
		cleanstart = start - @settings.clean.distance
		cleanend = end + @settings.clean.distance
		#@log('cleanstart: '+cleanstart)
		#@log('cleanend: '+cleanend)
		for pos in @settings.positions
			if cleanstart > 0
				@delRow(pos) if pos < cleanstart
			if cleanend < @settings.rows
				@delRow(pos) if pos > cleanend
				
	delRow: (pos) =>
		#@log('del:'+ pos)
		$('[data-pos="'+pos+'"]').remove()
	trigger: (event) =>
		@settings.el.trigger(event)
		
$ ->
	$.fn.extend
		scrollTable: (options) ->
			$(this).each ->
				$(this).data('ScrollTable', new ScrollTable($.extend {el: $(this)}, options))
			
	$('[data-scrolltable]').scrollTable();
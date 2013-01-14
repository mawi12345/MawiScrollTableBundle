# Reference jQuery
$ = jQuery

class Connector
  constructor: (@name, @loading) ->
  setup: (fail, done) ->
    done();
  info: (filter, fail, done) ->
    @loading(on)
    @loading(off)
    done({rows: 0, pagesize: 20})
  page: (filter, order, number, fail, done) ->
    @loading(on)
    @loading(off)
    done('')

class SymfonyJqueryAjaxConnector extends Connector
  constructor: (@name, @loading) ->
  info: (filter, fail, done) ->
    @loading(on)
    rurl = Routing.generate('scrolltable_info', {'name': @name})
    $.ajax
      url: rurl
      type: 'GET'
      dataType: 'xml'
      success: (info) =>
        @loading(off)
        done({pages: $(info).find('pc').text()*1})
      error: () =>
        @loading(off)
        fail()
  page: (filter, order, number, fail, done) ->
    @loading(on)
    order = 'default' if order.length <= 0
    rurl = Routing.generate('scrolltable_page', {'name': @name, 'number': number, 'order': order, 'filter': filter})
    $.ajax
      url: rurl
      type: 'GET'
      dataType: 'html'
      success: (response) =>
        page = $(response)
        @loading(off)
        done(page)
      error: =>
        @loading(off)
        fail()
        
class ScrollTable
  constructor: (@options) ->
    defaults =
      debug: false
      selector:
        page: '.st-page'
        space: '.st-space'
      distance: 5
      clean: 8
      order: ''
      filter: ''
    @settings = $.extend defaults, options
    @el = @settings.el
    @initState =
      pages: 0
      pageHeight: 0
      last: -10000
      pages: []
      viewStartPage: 0
      viewEndPage: 0
      needCleanup: off
      needFill: off
      needScroll: off
    @state = {}
    @resetState()
    @connectorLoading = off
    @connections = 0
    @name = @el.attr('data-scrolltable');
    @connector = new SymfonyJqueryAjaxConnector(@name, @connectorLoadingStateChange)
    @log('page height: '+ @state.pageHeight)
    @connector.setup @errorHandler, () =>
      @log('connector finished setup')
      # init
      @resize () =>
        @fill()
        $(window).on('scroll', @scroll)
        @scroll()
  
  resetState: =>
    for key of @initState
      @state[key] = @initState[key]
    @state.pageHeight = @el.find(@settings.selector.page).first().outerHeight();
  
  log: (msg) =>
    console?.log msg if @settings.debug
  
  errorHandler: =>
    @log('ERROR')
  
  connectorLoadingStateChange: (state) =>
    if state
      @connections++ 
    else
      @connections--
    if @connections <= 0 and @connectorLoading
      @log('connector has finished loading')
      @trigger('loading', off)
      @connectorLoading = off
      if @state.needCleanup
        @state.needCleanup = off
        @cleanup()
      if @state.needFill
        @state.needFill = off
        @fill()   
      if @state.needScroll
        @state.needScroll = off
        @scroll()  
    else if @connections > 0 and not @connectorLoading
      @log('connector is loading')
      @trigger('loading', on)
      @connectorLoading = on
  
  info: (done) =>
    @connector.info @settings.filter, @errorHandler, done
    
  page: (number, done) =>
    @connector.page @settings.filter, @settings.order, number, @errorHandler, done
        
  resize: (done) ->
    @info (info) =>
      @log(info);
      @state.pages = info.pages
      @el.height(info.pages * @state.pageHeight + 'px')
      @log(@state);
      done()
  
  refresh: =>
    @resetState()
    @resize () =>
      @el.find(@settings.selector.page).remove()
      @el.find(@settings.selector.space).remove().first().appendTo(@el);
      @fill()
      @scroll()
      
  fill: ->
    pages = @el.find(@settings.selector.page)
    space = @el.find(@settings.selector.space).detach().first()
    @state.positions = []
    for page in pages
      pos = $(page).attr('data-p')*1
      nextsmaller = -1
      for p in @state.positions
        nextsmaller = p if p < pos
      @state.positions.push pos
      # if no row before pos and pos greater then 0
      if nextsmaller < 0 and pos > 0
        $(page).before(space.clone().height(pos * @state.pageHeight+'px'))
      # if an row is before pos but not on pos - 1
      if nextsmaller > 0 and (nextsmaller + 1) < pos
        $(page).before(space.clone().height((pos-nextsmaller-1) * @state.pageHeight+'px'))
      #@log('pos: '+pos+' next: '+nextsmaller)
    
    if @state.positions.length > 0
      footerSpaceSize = @state.pages - @state.positions[@state.positions.length - 1] - 1
    else
      footerSpaceSize = @state.pages
    if footerSpaceSize > 0
      @el.append(space.clone().height((footerSpaceSize * @state.pages)+'px'))
  
  pixelToPage:(pixel) ->
    Math.floor(pixel / @state.pageHeight)
  
  scroll: =>
    if @connectorLoading is on
      @state.needScroll = on
      return off
    viewtop = $(document).scrollTop() - @el.position().top
    
    viewHeight = window.innerHeight
    @state.viewStartPage = @pixelToPage(viewtop)
    @state.viewEndPage = @pixelToPage(viewtop+viewHeight)
    @state.viewStartPage = 0 if @state.viewStartPage < 0
    @state.viewEndPage = @state.pages - 1 if @state.viewEndPage >= @settings.pages
    
    return off if Math.abs(@state.last - viewtop) < (@settings.distance * @state.pageHeight)
    @state.last = viewtop
    
    startPage = @state.viewStartPage - @settings.distance
    endPage = @state.viewEndPage + @settings.distance
    startPage = 0 if startPage < 0
    endPage = @state.pages - 1 if endPage >= @state.pages
    #@log('viewStartPage: '+@state.viewStartPage+' viewEndPage: '+@state.viewEndPage+' startPage: '+startPage+' endPage: '+endPage+' @el.position().top: '+@el.position().top)
    @loadPages(startPage, endPage)
    return on
    
  loadPages: (start, end) =>
    @log('load pages: '+start+' - '+end);
    range = [start..end]
    items = $.grep range, (item) =>
      if $.inArray(item, @state.positions) < 0
        return 1
      else
        return 0
    return off if items.length < 1 
    #@log(items);
    @state.needCleanup = on
    for num in items
      @page num, (page) =>
        @addPage(page)
        @fill()
        
  addPage: (page) =>
    #@log(page)
    pos = $(page).attr('data-p')*1
    if @state.positions.length is 0
      @el.append(page)
      @state.positions.push(pos)
      return on
    min = minpos = @state.pages
    for p, i in @state.positions
      continue if p is pos
      distance = Math.abs(p - pos)
      if distance < min
        min = distance
        minpos = p
      break if distance <= 1 or p > pos
        
    #@log('pos: '+pos+' p:' + p + ' min: ' + min + ' minpos:' + minpos + ' distance:'+distance)
    @delPage(pos)
    if minpos < pos
      $(page).insertAfter('[data-p="'+minpos+'"]')
      @state.positions.splice(minpos,0,pos)
    else
      $(page).insertBefore('[data-p="'+minpos+'"]')
      @state.positions.splice(minpos-1,0,pos)
      
  cleanup: () =>
    cleanstart = @state.viewStartPage - @settings.clean
    cleanend = @state.viewEndPage + @settings.clean
    cleanstart = 0 if cleanstart < 0
    cleanend = @state.pages - 1 if cleanend >= @settings.pages
    #@log('cleanstart: '+cleanstart)
    #@log('cleanend: '+cleanend)
    for pos in @state.positions
      if cleanstart > 0
        @delPage(pos) if pos < cleanstart
      if cleanend < @state.pages
        @delPage(pos) if pos > cleanend
        
  delPage: (pos) =>
    #@log('del:'+ pos)
    $('[data-p="'+pos+'"]').remove()
    
  trigger: (event, data) =>
    @settings.el.trigger(event, data)
    
$ ->
  $.fn.extend
    scrollTable: (options) ->
      $(this).each ->
        $(this).data('ScrollTable', new ScrollTable($.extend {el: $(this)}, options))
      
  $('[data-scrolltable]').scrollTable();
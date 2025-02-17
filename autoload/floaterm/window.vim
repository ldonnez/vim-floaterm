" vim:sw=2:
" ============================================================================
" FileName: floatwin.vim
" Author: voldikss <dyzplus@gmail.com>
" GitHub: https://github.com/voldikss
" ============================================================================

let s:has_popup = has('textprop') && has('patch-8.2.0286')
let s:has_float = has('nvim') && exists('*nvim_win_set_config')

function! s:get_wintype() abort
  if empty(g:floaterm_wintype)
    if s:has_float
      return 'floating'
    elseif s:has_popup
      return 'popup'
    else
      return 'normal'
    endif
  elseif g:floaterm_wintype == 'floating' && !s:has_float
    call floaterm#util#show_msg("floating window is not supported in your nvim, fall back to normal window", 'warning')
    return 'normal'
  elseif g:floaterm_wintype == 'popup' && !s:has_popup
    call floaterm#util#show_msg("popup window is not supported in your vim, fall back to normal window", 'warning')
    return 'normal'
  else
    return g:floaterm_wintype
  endif
endfunction

function! s:make_title(bufnr, text) abort
  if empty(a:text) | return '' | endif
  let buffers = floaterm#buflist#gather()
  let cnt = len(buffers)
  let idx = index(buffers, a:bufnr) + 1
  let title = substitute(a:text, '$1', idx, 'gm')
  let title = substitute(title, '$2', cnt, 'gm')
  return title
endfunction

function! s:get_floatwin_pos(width, height, pos) abort
  if a:pos == 'topright'
    let row = 1
    let col = &columns
    let anchor = 'NE'
  elseif a:pos == 'topleft'
    let row = 1
    let col = 0
    let anchor = 'NW'
  elseif a:pos == 'bottomright'
    let row = &lines - &cmdheight - 1
    let col = &columns
    let anchor = 'SE'
  elseif a:pos == 'bottomleft'
    let row = &lines - &cmdheight - 1
    let col = 0
    let anchor = 'SW'
  elseif a:pos == 'top'
    let row = 1
    let col = (&columns - a:width)/2
    let anchor = 'NW'
  elseif a:pos == 'right'
    let row = (&lines - a:height)/2
    let col = &columns
    let anchor = 'NE'
  elseif a:pos == 'bottom'
    let row = &lines - &cmdheight - 1
    let col = (&columns - a:width)/2
    let anchor = 'SW'
  elseif a:pos == 'left'
    let row = (&lines - a:height)/2
    let col = 0
    let anchor = 'NW'
  elseif a:pos == 'center'
    let row = (&lines - a:height)/2
    let col = (&columns - a:width)/2
    let anchor = 'NW'
    if row < 0
      let row = 0
    endif
    if col < 0
      let col = 0
    endif
  else " at the cursor place
    let winpos = win_screenpos(0)
    let row = winpos[0] - 1 + winline()
    let col = winpos[1] - 1 + wincol()
    if row + a:height <= &lines - &cmdheight - 1
      let vert = 'N'
    else
      let vert = 'S'
      let row -= 1
    endif
    if col + a:width <= &columns
      let hor = 'W'
    else
      let hor = 'E'
    endif
    let anchor = vert . hor
  endif
  if !has('nvim')
    let anchor = substitute(anchor, '\CN', 'top', '')
    let anchor = substitute(anchor, '\CS', 'bot', '')
    let anchor = substitute(anchor, '\CW', 'left', '')
    let anchor = substitute(anchor, '\CE', 'right', '')
  endif
  return [row, col, anchor]
endfunction

function! s:winexists(winid) abort
  return !empty(getwininfo(a:winid))
endfunction

" TODO: give this function a better name
" @argument: config, a floaterm local variable, will be stored as a `b:` variable
" @return: config, generated from `a:config`, has more additional info, used to
"   config the floaterm style
function! s:parse_config(config) abort
  if !has_key(a:config, 'width')
    let a:config.width = g:floaterm_width
  endif
  if !has_key(a:config, 'height')
    let a:config.height = g:floaterm_height
  endif
  if !has_key(a:config, 'wintype')
    let a:config.wintype = s:get_wintype()
  endif
  if !has_key(a:config, 'position')
    let a:config.position = g:floaterm_position
  endif
  if !has_key(a:config, 'autoclose')
    let a:config.autoclose = g:floaterm_autoclose
  endif
  if !has_key(a:config, 'title')
    let a:config.title = g:floaterm_title
  endif

  " generate and return window configs based on a:config
  let config = deepcopy(a:config)

  let config.borderchars = g:floaterm_borderchars

  let width = config.width
  if type(width) == v:t_float | let width = width * &columns | endif
  let config.width = float2nr(width)

  let height = config.height
  if type(height) == v:t_float | let height = height * (&lines - &cmdheight - 1) | endif
  let config.height = float2nr(height)

  if config.position == 'random'
    let randnum = str2nr(matchstr(reltimestr(reltime()), '\v\.@<=\d+')[1:])
    if s:get_wintype() == 'normal'
      let config.position = ['top', 'right', 'bottom', 'left'][randnum % 4]
    else
      let config.position = ['top', 'right', 'bottom', 'left', 'center', 'topleft', 'topright', 'bottomleft', 'bottomright', 'auto'][randnum % 10]
    endif
  endif

  let [row, col, anchor] = s:get_floatwin_pos(config.width, config.height, config.position)
  let config['anchor'] = anchor
  let config['row'] = row
  let config['col'] = col
  return config
endfunction

function! s:open_float(bufnr, config) abort
  let options = {
        \ 'relative': 'editor',
        \ 'anchor': a:config.anchor,
        \ 'row': a:config.row + (a:config.anchor[0] == 'N' ? 1 : -1),
        \ 'col': a:config.col + (a:config.anchor[1] == 'W' ? 1 : -1),
        \ 'width': a:config.width - 2,
        \ 'height': a:config.height - 2,
        \ 'style':'minimal',
        \ }
  let winid = nvim_open_win(a:bufnr, v:true, options)
  call s:init_win(winid, v:false)

  let bd_options = {
        \ 'relative': 'editor',
        \ 'anchor': a:config.anchor,
        \ 'row': a:config.row,
        \ 'col': a:config.col,
        \ 'width': a:config.width,
        \ 'height': a:config.height,
        \ 'focusable': v:false,
        \ 'style':'minimal',
        \ }
  let a:config.title = s:make_title(a:bufnr, a:config.title)
  let bd_bufnr = floaterm#buffer#create_border_buf(a:config)
  let bd_winid = nvim_open_win(bd_bufnr, v:false, bd_options)
  call nvim_win_set_var(winid, 'floatermborder_winid', bd_winid)
  call s:init_win(bd_winid, v:true)
  return winid
endfunction

function! s:open_popup(bufnr, config) abort
  let options = {
        \ 'pos': a:config.anchor,
        \ 'line': a:config.row,
        \ 'col': a:config.col,
        \ 'maxwidth': a:config.width,
        \ 'minwidth': a:config.width,
        \ 'maxheight': a:config.height,
        \ 'minheight': a:config.height,
        \ 'border': [1, 1, 1, 1],
        \ 'borderchars': a:config.borderchars,
        \ 'borderhighlight': ['FloatermBorder'],
        \ 'padding': [0,1,0,1],
        \ 'highlight': 'Floaterm',
        \ 'zindex': len(floaterm#buflist#gather()) + 1
        \ }

  " vim will pad the end of title but not begin part
  " so we build the title as ' floaterm (idx/cnt)'
  let options.title = ' ' . s:make_title(a:bufnr, a:config.title)
  let winid = popup_create(a:bufnr, options)
  call s:init_win(winid, v:false)
  return winid
endfunction

function! s:open_split(bufnr, config) abort
  if a:config.position == 'top'
    execute 'topleft' . a:config.height . 'split'
  elseif a:config.position == 'left'
    execute 'topleft' . a:config.width . 'vsplit'
  elseif a:config.position == 'right'
    execute 'botright' . a:config.width . 'vsplit'
  else " default position: bottom
    execute 'botright' . a:config.height . 'split'
  endif
  execute 'buffer ' . a:bufnr
  let winid = win_getid()
  call s:init_win(winid, v:false)
  return winid
endfunction

function! s:init_win(winid, is_border) abort
  if has('nvim')
    call setwinvar(a:winid, '&winhl', 'Normal:Floaterm,NormalNC:FloatermNC')
    if a:is_border
      call setwinvar(a:winid, '&winhl', 'Normal:FloatermBorder')
    endif
  else
    call setwinvar(a:winid, 'wincolor', 'Floaterm')
  endif
  call setwinvar(a:winid, '&sidescrolloff', 0)
endfunction

function! floaterm#window#open(bufnr, config) abort
  let config = s:parse_config(a:config)
  if config.wintype == 'floating'
    let winid = s:open_float(a:bufnr, config)
  elseif config.wintype == 'popup'
    let winid = s:open_popup(a:bufnr, config)
  else
    let winid = s:open_split(a:bufnr, config)
  endif
  return [winid, a:config]
endfunction

function! floaterm#window#hide(bufnr) abort
  let winid = getbufvar(a:bufnr, 'floaterm_winid', -1)
  if !s:winexists(winid) | return | endif
  if has('nvim')
    let bd_winid = getwinvar(winid, 'floatermborder_winid', -1)
    if s:winexists(bd_winid)
      call nvim_win_close(bd_winid, v:true)
    endif
    call nvim_win_close(winid, v:true)
  else
    if exists('*win_gettype')
      if win_gettype() == 'popup'
        call popup_close(winid)
      elseif bufwinnr(a:bufnr) > 0
        silent! execute bufwinnr(a:bufnr) . 'hide'
      endif
    else
      try
        call popup_close(winid)
      catch
        if bufwinnr(a:bufnr) > 0
          silent! execute bufwinnr(a:bufnr) . 'hide'
        endif
      endtry
    endif
  endif
  silent checktime
endfunction

" find **one** visible floaterm window
function! floaterm#window#find() abort
  let found_winnr = 0
  for winnr in range(1, winnr('$'))
    if getbufvar(winbufnr(winnr), '&filetype') ==# 'floaterm'
      let found_winnr = winnr
      break
    endif
  endfor
  return found_winnr
endfunction

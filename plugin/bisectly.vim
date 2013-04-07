" Vim global plugin for locating faulty plugins
" Maintainer:	Barry Arthur <barry.arthur@gmail.com>
" Version:	0.1
" Description:	Plugin-manager agnostic fault locator using a BSFL algorithm.
" Last Change:	2013-04-06
" License:	Vim License (see :help license)
" Location:	plugin/bisectly.vim
" Website:	https://github.com/dahu/vim-bisectly
"
" See bisectly.txt for help.  This can be accessed by doing:
"
" :helptags ~/.vim/doc
" :help bisectly

let g:bisectly_version = '0.1'

" Vimscript Setup: {{{1
" Allow use of line continuation.
let s:save_cpo = &cpo
set cpo&vim

" load guard
" uncomment after plugin development.
" XXX The conditions are only as examples of how to use them. Change them as
" needed. XXX
"if exists("g:loaded_bisectly")
"      \ || v:version < 700
"      \ || v:version == 703 && !has('patch338')
"      \ || &compatible
"  let &cpo = s:save_cpo
"  finish
"endif
"let g:loaded_bisectly = 1

" Private Functions: {{{1
function! Bisector(...)
  let b = {}
  let b.all = split(&rtp, '\\\@<!,')
  let b.rc_file = tempname() . '_bisectly.vimrc'
  let b.diagnostic = ''
  if a:0
    let b.diagnostic = a:1
  endif
  let b.vim_command = '!vim -N -u ' . b.rc_file
          \ . ' -c ' . shellescape('command! Unicorns q!', 1)
          \ . ' -c ' . shellescape('command! U q!', 1)
          \ . ' -c ' . shellescape('command! Zombies cq!', 1)
          \ . ' -c ' . shellescape('command! Z cq!', 1)
          \ . ' -c ' . shellescape(b.diagnostic, 1)

  func b.make_rc_file() dict abort
    " TODO: allow user to provide a base vimrc that gets copied into
    " self.rc_file after the &rtp block
    let lines='set rtp='.join(self.all[self.enabled[0] : self.enabled[1]], ',')
    try
      call writefile(split(lines, "\n"), self.rc_file)
    endtry
  endfunc

  func b.vim_test_run() dict
    call self.make_rc_file()
    silent! execute self.vim_command
  endfunc

  func b.locate_fault() dict
    let self.enabled = [0, (len(self.all) / 2)]
    let self.disabled = [(len(self.all) / 2) + 1, len(self.all) - 1]
    call self.vim_test_run()

    " TODO: might need a better loop termination condition
    while self.enabled[0] != self.enabled[1]
      " halve the enabled range depending on v:shell_error.
      " v:shell_error == 1 when exited with :cq (:Zombies), meaning the user
      " considers this session to possess the pertinent fault.
      if v:shell_error == 0
        let range = self.disabled
        " no fault found, so we need to keep looking in the previously disabled
        " half
      else
        let range = self.enabled
        " the currently enabled half has the fault, so we need to keep looking
        " within it
      endif
      let half = range[0] + (range[1] - range[0]) / 2
      let self.enabled = [range[0], half]
      let self.disabled = [half + 1, range[1]]
      call self.vim_test_run()
    endwhile

    if v:shell_error == 0
      return self.disabled[0]
    else
      return self.enabled[0]
    endif
  endfunc

  func b.report_fault(fault) dict
    if a:fault < len(self.all)
      echohl WarningMsg
      echo "Bisectly located a fault with: " . self.all[a:fault]
      echohl None
    else
      echohl ErrorMsg
      echo "Bisectly was unable to locate a fault."
      echohl None
    endif
  endfunc

  return b
endfunction

" Public Interface: {{{1
func Bisectly(...)
  let diagnostic = ''
  if a:0
    let diagnostic = a:1
  endif
  let bisector = Bisector(diagnostic)
  let fault = bisector.locate_fault()
  redraw!
  call bisector.report_fault(fault)
endfunc

" Commands: {{{1
command! -nargs=* -complete=file Bisectly call Bisectly("<args>")

" Teardown:{{{1
"reset &cpo back to users setting
let &cpo = s:save_cpo

" vim: set sw=2 sts=2 et fdm=marker:

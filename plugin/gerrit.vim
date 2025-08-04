" gerrit.nvim - Gerrit Code Review plugin for Neovim
" Maintainer: Anuj Varma
" Version: 1.0.0

" Prevent loading if already loaded or if vim version is too old
if exists('g:loaded_gerrit') || v:version < 800 || !has('lua')
  finish
endif
let g:loaded_gerrit = 1

" Plugin configuration
let g:gerrit_config = get(g:, 'gerrit_config', {})

" Set up health check
command! -nargs=0 GerritHealth lua require('gerrit').health()

" Auto-setup for comment management
augroup GerritPlugin
  autocmd!
  " Setup comment autocommands when plugin loads
  autocmd VimEnter * lua pcall(function() require('gerrit.comments').setup_autocommands() end)
augroup END
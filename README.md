# Dependency-assist.nvim

This project is *ARCHIVED* and no longer maintained. I've decided to massively narrow down the scope of to focus on providing version information
for dart and flutter rather than the original goal of a generalised API for dependency management. I think the current appetite and approach in the
nvim plugin space as of 11/2020 is for language specific plugins that handle dependencies e.g.

[package-info.nvim](https://github.com/vuki656/package-info.nvim)
[crates.nvim](https://github.com/Saecki/crates.nvim)

So I will start work on [pubspec-assist.nvim](https://github.com/akinsho/pubspec-assist.nvim) when I get some time which will provide
similar functionality but focused on dart dependency management.

Hopefully someone else will try again with a generalised approach but think it
will be a lot more work than I would personally want to take on again, since
maintaining dependency management for languages you don't use is a pain.

## Introduction
Inspired by [pubspec assist](https://github.com/jeroen-meijer/pubspec-assist) a vscode dart plugin for getting version information for packages,
and by [vim-crates](https://github.com/mhinz/vim-crates), a vim plugin for visualising dependency versions.

Dependency assist is a neovim plugin written in lua, which is designed to help you find out which dependencies
are up to date and add new ones to your dependency file.

status: _Alpha_

<img src="./.github/dependency_assist.gif" alt="Dependency assist in action" height="400px">

**Dependency versions using virtual text**

<img alt="dependency assist virtual text" src="./.github/dependencies_virt_text.png" height="300px">

### Supported languages

- Dart
- Rust (not 100% complete yet)

![rust and dart virtual text](./.github/rust-and-dart.png)

## Requirements

- **Nightly Neovim**

## Installation

```
Plug 'akinsho/dependency-assist.nvim'
```

Then in your `init.vim` somewhere after loading the plugin call

```vim
lua << EOF
  require'dependency_assist'.setup{}
EOF
```

## Usage

### `AddDependency/AddDevDependency`

These commands are buffer specific and only added within a supported file. For now this is any `dart` file or a `pubspec.yaml`.

This plugin works by showing you the current version of a dependency _if_ it differs from the version you have.

It also provides `AddDependency` and `AddDevDependency` commands within a supported filetype.
These commands open an input buffer which on hitting `Enter` is used to search `pub.dev` for matching packages.

It then returns a list of matches and on selecting them they will be added to your `devDependencies` or your `dependencies`
depending on what you selected.

### `UpdateDependencyLine`

Whilst inside a dependency file (`pubspec.yaml` for now) whilst on a line where there is a new version
available `UpdateDependencyLine` will swap the current version for the latest.

## Goals

This plugin was designed to be extensible 🤞. Hopefully adding a module for other compatible languages shouldn't be too
much work.

This won't scale to all languages, and tbh I'm going to focus my energy on languages I use. If you are interested in contributing a
module for the language you use, open an issue.

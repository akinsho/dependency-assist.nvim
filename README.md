# Dependency-assist.nvim

Inspired by [pubspec assist](https://github.com/jeroen-meijer/pubspec-assist) a vscode dart plugin for getting version information for packages,
and by [vim-crates](https://github.com/mhinz/vim-crates), a vim plugin for visualising dependency versions.

Dependency assist is a neovim plugin written in lua, which is designed to help you find out which dependencies
are up to date and add new ones to your dependency file.

**Currently `dart` is the only supported language.**

<img src="./.github/dependency_assist.gif" alt="Dependency assist in action" height="400px">

**Dependency versions using virtual text**

<img alt="dependency assist virtual text" src="./.github/dependencies_virt_text.png" height="300px">

## ⚠ NOTE

This plugin is **WIP**.

## Usage

This plugin works by showing you the current version of a dependency _if_ it differs from the version you have.

It also provides `AddDependency` and `AddDevDependency` commands. These commands open an input buffer which on hitting
`Enter` is used to search `pub.dev` for matching packages.

It then returns a list of matches and on selecting one it will open a list of versions.
Once you select one, it will be added to your `devDependencies` or your `dependencies` depending on what you selected.

## Goals

This plugin was designed to be extensible 🤞. Hopefully adding a module for other compatible languages shouldn't be too
much work but I haven't tested this out by integrating another example yet.

This won't scale to all languages, and tbh I'm going to focus my energy on languages I use. If you are interested in contributing a
module for the language you use, open an issue.

## TODO

#### Dart

- [x] Parse `pubspec.yaml` and show versions using virtual text
- [x] insert specifically into `devDependencies` or standard dependencies
- [x] search for multiple packages

#### Rust

- [ ] Implement `formatter`, `api` etc. (aka _everything_)

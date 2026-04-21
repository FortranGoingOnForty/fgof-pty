# fgof-pty

[![CI](https://github.com/FortranGoingOnForty/fgof-pty/actions/workflows/ci.yml/badge.svg)](https://github.com/FortranGoingOnForty/fgof-pty/actions/workflows/ci.yml)

POSIX-first PTY and terminal session helpers for modern Fortran applications.

`fgof-pty` is intended to be a small, standalone library that gives Fortran tools an ergonomic PTY surface for interactive subprocesses, terminal resizing, and terminal-aware automation.

It is built for the kind of Fortran programs that need to drive interactive children: shells, terminal emulators, test harnesses, TUI tools, editors, and automation helpers.

It is part of the [FortranGoingOnForty lib-modules](https://github.com/FortranGoingOnForty/lib-modules) catalog, but it is intended to stand on its own as a normal `fpm` package.

Current v1 target:

- POSIX-first PTY sessions on macOS and Linux
- child attach and close
- PTY read and write helpers
- terminal resize propagation
- explicit session state and terminal-size types
- clean integration points for `fgof-process` and future expect-style tooling

Future scope:

- richer termios guards in a companion package
- expect-style testing helpers
- higher-level line-editing and key-decoding layers

## Status

First real PTY session slice is in place.

Implemented today:

- public `fgof_pty` and `fgof_pty_types` modules
- PTY session and terminal-size types
- `spawn_pty()` for argv-based child launch on macOS and Linux
- `read_some()`, `write_all()`, `resize_pty()`, `refresh_pty()`, `wait_pty()`, and `close_pty()`
- session-level error codes and messages
- interactive smoke-test coverage and CI wiring

Still to implement:

- deeper failure semantics and edge-case hardening
- richer session lifecycle helpers
- expect-style helpers in a future companion package

## Why Use It

- PTY support is a real ecosystem gap for interactive Fortran tools
- shells, TUIs, and terminal automation all need the same primitives repeatedly
- the package is meant to stay small, direct, and composable
- it complements `fgof-process` rather than overlapping it

## Public API Shape

Primary modules:

- `fgof_pty`
- `fgof_pty_types`

Public types:

- `pty_session`
- `terminal_size`

Current public procedures:

- `pty_backend_name`
- `default_terminal_size`
- `spawn_pty`
- `read_some`
- `refresh_pty`
- `wait_pty`
- `write_all`
- `resize_pty`
- `close_pty`

## Quick Start

```fortran
program demo_pty
  use fgof_pty, only : close_pty, pty_session, read_some, spawn_pty, wait_pty, write_all
  implicit none

  type(pty_session) :: session

  session = spawn_pty("cat")
  if (.not. session%is_open) error stop trim(session%error_message)

  if (.not. write_all(session, "hello" // new_line("a"))) error stop trim(session%error_message)
  print "(A)", read_some(session, 256)

  if (.not. wait_pty(session, 1000)) error stop trim(session%error_message)

  if (.not. close_pty(session)) error stop trim(session%error_message)
end program demo_pty
```

## Build And Test

```bash
fpm test
```

That is the baseline verification command locally and in CI.

## Supported Platforms

- macOS
- Linux

## Boundaries

- POSIX-first for macOS and Linux
- intended to stay independently versioned and releasable
- focused on PTY transport and session control, not full terminal UI layers

## License

MIT

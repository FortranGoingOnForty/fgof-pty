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

Scaffold and planning baseline in place.

Implemented today:

- public `fgof_pty` and `fgof_pty_types` modules
- baseline PTY session and terminal-size types
- minimal backend metadata helper
- smoke-test coverage and CI wiring

Still to implement:

- PTY spawn and attach
- read and write helpers
- resize support
- close semantics and child cleanup

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

## Quick Start

```fortran
program demo_pty
  use fgof_pty, only : default_terminal_size, pty_backend_name
  use fgof_pty_types, only : terminal_size
  implicit none

  type(terminal_size) :: size

  size = default_terminal_size()
  print "(A)", pty_backend_name()
  print "(I0,1X,I0)", size%rows, size%cols
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

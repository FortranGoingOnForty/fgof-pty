module fgof_pty
  use fgof_pty_types, only : pty_session, terminal_size
  implicit none
  private

  public :: default_terminal_size
  public :: pty_backend_name
  public :: pty_session
  public :: terminal_size

contains

  function pty_backend_name() result(name)
    character(len=:), allocatable :: name

    name = "posix"
  end function pty_backend_name

  function default_terminal_size() result(size)
    type(terminal_size) :: size
  end function default_terminal_size

end module fgof_pty

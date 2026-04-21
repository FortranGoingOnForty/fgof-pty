module fgof_pty_types
  implicit none
  private

  public :: pty_session
  public :: terminal_size

  type :: terminal_size
    integer :: rows = 24
    integer :: cols = 80
  end type terminal_size

  type :: pty_session
    integer :: master_fd = -1
    integer :: child_pid = -1
    logical :: is_open = .false.
    type(terminal_size) :: size
  end type pty_session

end module fgof_pty_types

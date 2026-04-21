module fgof_pty_types
  implicit none
  private

  public :: FGOF_PTY_OK
  public :: FGOF_PTY_ERR_INVALID_COMMAND
  public :: FGOF_PTY_ERR_INVALID_SIZE
  public :: FGOF_PTY_ERR_SPAWN_FAILED
  public :: FGOF_PTY_ERR_EXEC_FAILED
  public :: FGOF_PTY_ERR_IO_FAILED
  public :: FGOF_PTY_ERR_RESIZE_FAILED
  public :: FGOF_PTY_ERR_CLOSE_FAILED
  public :: FGOF_PTY_ERR_TIMEOUT
  public :: FGOF_PTY_ERR_INTERNAL
  public :: pty_session
  public :: terminal_size

  integer, parameter :: FGOF_PTY_OK = 0
  integer, parameter :: FGOF_PTY_ERR_INVALID_COMMAND = 10
  integer, parameter :: FGOF_PTY_ERR_INVALID_SIZE = 11
  integer, parameter :: FGOF_PTY_ERR_SPAWN_FAILED = 20
  integer, parameter :: FGOF_PTY_ERR_EXEC_FAILED = 21
  integer, parameter :: FGOF_PTY_ERR_IO_FAILED = 22
  integer, parameter :: FGOF_PTY_ERR_RESIZE_FAILED = 23
  integer, parameter :: FGOF_PTY_ERR_CLOSE_FAILED = 24
  integer, parameter :: FGOF_PTY_ERR_TIMEOUT = 25
  integer, parameter :: FGOF_PTY_ERR_INTERNAL = 99

  type :: terminal_size
    integer :: rows = 24
    integer :: cols = 80
  end type terminal_size

  type :: pty_session
    integer :: master_fd = -1
    integer :: child_pid = -1
    logical :: is_open = .false.
    logical :: child_running = .false.
    logical :: completed = .false.
    logical :: exited_normally = .false.
    logical :: eof_reached = .false.
    integer :: exit_code = -1
    integer :: term_signal = 0
    type(terminal_size) :: size = terminal_size()
    integer :: error_code = FGOF_PTY_OK
    character(len=:), allocatable :: error_message
  end type pty_session

end module fgof_pty_types

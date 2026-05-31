module fgof_pty_posix
  use iso_c_binding, only : c_char, c_int, c_null_char, c_size_t
  use fgof_pty_types, only : &
    FGOF_PTY_ERR_CLOSE_FAILED, &
    FGOF_PTY_ERR_EXEC_FAILED, &
    FGOF_PTY_ERR_INTERNAL, &
    FGOF_PTY_ERR_IO_FAILED, &
    FGOF_PTY_ERR_RESIZE_FAILED, &
    FGOF_PTY_ERR_SPAWN_FAILED, &
    FGOF_PTY_OK, &
    pty_session, &
    terminal_size
  implicit none
  private

  public :: close_posix_pty
  public :: read_some_posix_pty
  public :: refresh_posix_pty
  public :: resize_posix_pty
  public :: spawn_posix_pty
  public :: write_all_posix_pty

  integer(c_int), parameter :: POSIX_PTY_OK = 0
  integer(c_int), parameter :: POSIX_PTY_ERR_OPEN = 1
  integer(c_int), parameter :: POSIX_PTY_ERR_PIPE = 2
  integer(c_int), parameter :: POSIX_PTY_ERR_FORK = 3
  integer(c_int), parameter :: POSIX_PTY_ERR_EXEC = 4
  integer(c_int), parameter :: POSIX_PTY_ERR_FCNTL = 5

  interface
    function fgof_pty_spawn(program, argv_blob, argc, arg_stride, rows, cols, master_fd, child_pid, sys_errno) &
      bind(C, name="fgof_pty_spawn")
      import :: c_char, c_int
      character(kind=c_char), intent(in) :: program(*)
      character(kind=c_char), intent(in) :: argv_blob(*)
      integer(c_int), value :: argc
      integer(c_int), value :: arg_stride
      integer(c_int), value :: rows
      integer(c_int), value :: cols
      integer(c_int), intent(out) :: master_fd
      integer(c_int), intent(out) :: child_pid
      integer(c_int), intent(out) :: sys_errno
      integer(c_int) :: fgof_pty_spawn
    end function fgof_pty_spawn

    function fgof_pty_read_some(fd, buffer, buffer_len, sys_errno) bind(C, name="fgof_pty_read_some")
      import :: c_char, c_int, c_size_t
      integer(c_int), value :: fd
      character(kind=c_char), intent(out) :: buffer(*)
      integer(c_size_t), value :: buffer_len
      integer(c_int), intent(out) :: sys_errno
      integer(c_int) :: fgof_pty_read_some
    end function fgof_pty_read_some

    function fgof_pty_write_all(fd, buffer, buffer_len, sys_errno) bind(C, name="fgof_pty_write_all")
      import :: c_char, c_int, c_size_t
      integer(c_int), value :: fd
      character(kind=c_char), intent(in) :: buffer(*)
      integer(c_size_t), value :: buffer_len
      integer(c_int), intent(out) :: sys_errno
      integer(c_int) :: fgof_pty_write_all
    end function fgof_pty_write_all

    function fgof_pty_resize(fd, rows, cols, sys_errno) bind(C, name="fgof_pty_resize")
      import :: c_int
      integer(c_int), value :: fd
      integer(c_int), value :: rows
      integer(c_int), value :: cols
      integer(c_int), intent(out) :: sys_errno
      integer(c_int) :: fgof_pty_resize
    end function fgof_pty_resize

    function fgof_pty_close_session(master_fd, child_pid, exited_normally, exit_code, term_signal, sys_errno) &
      bind(C, name="fgof_pty_close_session")
      import :: c_int
      integer(c_int), value :: master_fd
      integer(c_int), value :: child_pid
      integer(c_int), intent(out) :: exited_normally
      integer(c_int), intent(out) :: exit_code
      integer(c_int), intent(out) :: term_signal
      integer(c_int), intent(out) :: sys_errno
      integer(c_int) :: fgof_pty_close_session
    end function fgof_pty_close_session

    function fgof_pty_poll_child(child_pid, running, exited_normally, exit_code, term_signal, sys_errno) &
      bind(C, name="fgof_pty_poll_child")
      import :: c_int
      integer(c_int), value :: child_pid
      integer(c_int), intent(out) :: running
      integer(c_int), intent(out) :: exited_normally
      integer(c_int), intent(out) :: exit_code
      integer(c_int), intent(out) :: term_signal
      integer(c_int), intent(out) :: sys_errno
      integer(c_int) :: fgof_pty_poll_child
    end function fgof_pty_poll_child
  end interface

contains

  subroutine spawn_posix_pty(program, argv, term_size, session)
    character(len=*), intent(in) :: program
    character(len=*), intent(in), optional :: argv(:)
    type(terminal_size), intent(in) :: term_size
    type(pty_session), intent(inout) :: session

    character(kind=c_char), allocatable :: c_program(:)
    character(kind=c_char), allocatable :: c_argv_blob(:)
    integer(c_int) :: argc
    integer(c_int) :: arg_stride
    integer(c_int) :: master_fd
    integer(c_int) :: child_pid
    integer(c_int) :: sys_errno
    integer(c_int) :: rc

    allocate(c_program(0))
    allocate(c_argv_blob(0))
    c_program = to_c_string(program)
    if (present(argv)) then
      call pack_string_array(argv, arg_stride, c_argv_blob)
      argc = int(size(argv), c_int)
    else
      c_argv_blob = empty_c_string()
      argc = 0_c_int
      arg_stride = 0_c_int
    end if

    rc = fgof_pty_spawn(c_program, c_argv_blob, argc, arg_stride, int(term_size%rows, c_int), int(term_size%cols, c_int), &
                        master_fd, child_pid, sys_errno)

    select case (rc)
    case (POSIX_PTY_OK)
      session%master_fd = int(master_fd)
      session%child_pid = int(child_pid)
      session%is_open = .true.
      session%child_running = .true.
      session%completed = .false.
      session%exited_normally = .false.
      session%exit_code = -1
      session%term_signal = 0
      session%size = term_size
      session%error_code = FGOF_PTY_OK
      session%error_message = ""

    case (POSIX_PTY_ERR_EXEC)
      call set_error(session, FGOF_PTY_ERR_EXEC_FAILED, errno_message("exec failed", sys_errno))

    case (POSIX_PTY_ERR_FORK)
      call set_error(session, FGOF_PTY_ERR_SPAWN_FAILED, errno_message("fork failed", sys_errno))

    case (POSIX_PTY_ERR_OPEN, POSIX_PTY_ERR_PIPE, POSIX_PTY_ERR_FCNTL)
      call set_error(session, FGOF_PTY_ERR_SPAWN_FAILED, errno_message("PTY spawn failed", sys_errno))

    case default
      call set_error(session, FGOF_PTY_ERR_INTERNAL, errno_message("PTY spawn failed", sys_errno))
    end select
  end subroutine spawn_posix_pty

  function read_some_posix_pty(session, max_bytes) result(text)
    type(pty_session), intent(inout) :: session
    integer, intent(in) :: max_bytes
    character(len=:), allocatable :: text

    character(kind=c_char), allocatable :: c_buffer(:)
    integer(c_int) :: rc
    integer(c_int) :: sys_errno
    logical :: refreshed

    allocate(c_buffer(max_bytes))
    rc = fgof_pty_read_some(int(session%master_fd, c_int), c_buffer, int(max_bytes, c_size_t), sys_errno)

    if (rc < 0_c_int) then
      call set_error(session, FGOF_PTY_ERR_IO_FAILED, errno_message("PTY read failed", sys_errno))
      text = ""
      return
    end if

    if (rc == 0_c_int) then
      refreshed = refresh_posix_pty(session)
      if (refreshed .and. .not. session%child_running) session%eof_reached = .true.
      text = ""
      return
    end if

    session%eof_reached = .false.
    text = from_c_buffer(c_buffer, int(rc))
  end function read_some_posix_pty

  logical function write_all_posix_pty(session, text) result(success)
    type(pty_session), intent(inout) :: session
    character(len=*), intent(in) :: text

    character(kind=c_char), allocatable :: c_buffer(:)
    integer(c_int) :: rc
    integer(c_int) :: sys_errno

    allocate(c_buffer(0))
    if (len(text) == 0) then
      success = .true.
      return
    end if

    c_buffer = to_c_bytes(text)
    rc = fgof_pty_write_all(int(session%master_fd, c_int), c_buffer, int(size(c_buffer), c_size_t), sys_errno)
    if (rc == 0_c_int) then
      success = .true.
    else
      call set_error(session, FGOF_PTY_ERR_IO_FAILED, errno_message("PTY write failed", sys_errno))
      success = .false.
    end if
  end function write_all_posix_pty

  logical function resize_posix_pty(session, size) result(success)
    type(pty_session), intent(inout) :: session
    type(terminal_size), intent(in) :: size

    integer(c_int) :: rc
    integer(c_int) :: sys_errno

    rc = fgof_pty_resize(int(session%master_fd, c_int), int(size%rows, c_int), int(size%cols, c_int), sys_errno)
    if (rc == 0_c_int) then
      session%size = size
      success = .true.
    else
      call set_error(session, FGOF_PTY_ERR_RESIZE_FAILED, errno_message("PTY resize failed", sys_errno))
      success = .false.
    end if
  end function resize_posix_pty

  logical function close_posix_pty(session) result(success)
    type(pty_session), intent(inout) :: session

    integer(c_int) :: rc
    integer(c_int) :: exited_normally
    integer(c_int) :: exit_code
    integer(c_int) :: term_signal
    integer(c_int) :: sys_errno

    if (session%child_running) then
      if (.not. refresh_posix_pty(session)) then
        success = .false.
        return
      end if
    end if

    rc = fgof_pty_close_session(int(session%master_fd, c_int), int(session%child_pid, c_int), &
                                exited_normally, exit_code, term_signal, sys_errno)
    if (rc == 0_c_int) then
      call apply_child_outcome(session, exited_normally, exit_code, term_signal)
      session%master_fd = -1
      session%child_pid = -1
      session%is_open = .false.
      session%child_running = .false.
      success = .true.
    else
      call set_error(session, FGOF_PTY_ERR_CLOSE_FAILED, errno_message("PTY close failed", sys_errno))
      success = .false.
    end if
  end function close_posix_pty

  logical function refresh_posix_pty(session) result(success)
    type(pty_session), intent(inout) :: session

    integer(c_int) :: rc
    integer(c_int) :: running
    integer(c_int) :: exited_normally
    integer(c_int) :: exit_code
    integer(c_int) :: term_signal
    integer(c_int) :: sys_errno

    if (session%child_pid <= 0) then
      success = .true.
      return
    end if

    rc = fgof_pty_poll_child(int(session%child_pid, c_int), running, exited_normally, exit_code, term_signal, sys_errno)
    if (rc /= 0_c_int) then
      call set_error(session, FGOF_PTY_ERR_INTERNAL, errno_message("PTY child poll failed", sys_errno))
      success = .false.
      return
    end if

    if (running /= 0_c_int) then
      session%child_running = .true.
      success = .true.
      return
    end if

    session%child_running = .false.
    call apply_child_outcome(session, exited_normally, exit_code, term_signal)
    success = .true.
  end function refresh_posix_pty

  subroutine set_error(session, code, message)
    type(pty_session), intent(inout) :: session
    integer, intent(in) :: code
    character(len=*), intent(in) :: message

    session%error_code = code
    session%error_message = trim(message)
  end subroutine set_error

  subroutine apply_child_outcome(session, exited_normally, exit_code, term_signal)
    type(pty_session), intent(inout) :: session
    integer(c_int), intent(in) :: exited_normally
    integer(c_int), intent(in) :: exit_code
    integer(c_int), intent(in) :: term_signal

    if (session%completed) return

    session%completed = .true.
    session%exited_normally = (exited_normally /= 0_c_int)
    session%exit_code = int(exit_code)
    session%term_signal = int(term_signal)
  end subroutine apply_child_outcome

  function to_c_string(str) result(buf)
    character(len=*), intent(in) :: str
    character(kind=c_char), allocatable :: buf(:)
    integer :: i
    integer :: n

    n = len_trim(str)
    allocate(buf(n + 1))
    do i = 1, n
      buf(i) = str(i:i)
    end do
    buf(n + 1) = c_null_char
  end function to_c_string

  function empty_c_string() result(buf)
    character(kind=c_char), allocatable :: buf(:)

    allocate(buf(1))
    buf(1) = c_null_char
  end function empty_c_string

  function to_c_bytes(str) result(buf)
    character(len=*), intent(in) :: str
    character(kind=c_char), allocatable :: buf(:)
    integer :: i

    allocate(buf(len(str)))
    do i = 1, len(str)
      buf(i) = str(i:i)
    end do
  end function to_c_bytes

  subroutine pack_string_array(values, stride, buffer)
    character(len=*), intent(in) :: values(:)
    integer(c_int), intent(out) :: stride
    character(kind=c_char), allocatable, intent(out) :: buffer(:)
    integer :: i
    integer :: j
    integer :: width
    integer :: offset

    if (size(values) == 0) then
      stride = 0_c_int
      buffer = empty_c_string()
      return
    end if

    width = max_trimmed_string_length(values) + 1
    stride = int(width, c_int)
    allocate(buffer(size(values) * width))
    buffer = c_null_char

    do i = 1, size(values)
      offset = (i - 1) * width
      do j = 1, len_trim(values(i))
        buffer(offset + j) = values(i)(j:j)
      end do
      buffer(offset + len_trim(values(i)) + 1) = c_null_char
    end do
  end subroutine pack_string_array

  integer function max_trimmed_string_length(values) result(max_len)
    character(len=*), intent(in) :: values(:)
    integer :: i

    max_len = 1
    do i = 1, size(values)
      max_len = max(max_len, len_trim(values(i)))
    end do
  end function max_trimmed_string_length

  function from_c_buffer(buffer, count) result(text)
    character(kind=c_char), intent(in) :: buffer(:)
    integer, intent(in) :: count
    character(len=:), allocatable :: text
    integer :: i

    if (count <= 0) then
      text = ""
      return
    end if

    allocate(character(len=count) :: text)
    do i = 1, count
      text(i:i) = char(iachar(buffer(i)))
    end do
  end function from_c_buffer

  function errno_message(prefix, errnum) result(message)
    character(len=*), intent(in) :: prefix
    integer(c_int), intent(in) :: errnum
    character(len=:), allocatable :: message
    character(len=32) :: code_text

    write(code_text, '(I0)') int(errnum)
    message = trim(prefix) // " (errno=" // trim(code_text) // ")"
  end function errno_message

end module fgof_pty_posix

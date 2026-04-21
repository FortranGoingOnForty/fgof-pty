module fgof_pty
  use fgof_pty_posix, only : close_posix_pty, read_some_posix_pty, refresh_posix_pty, resize_posix_pty, spawn_posix_pty, write_all_posix_pty
  use fgof_pty_types, only : &
    FGOF_PTY_ERR_CLOSE_FAILED, &
    FGOF_PTY_ERR_INTERNAL, &
    FGOF_PTY_ERR_INVALID_COMMAND, &
    FGOF_PTY_ERR_INVALID_SIZE, &
    FGOF_PTY_ERR_IO_FAILED, &
    FGOF_PTY_ERR_RESIZE_FAILED, &
    FGOF_PTY_ERR_EXEC_FAILED, &
    FGOF_PTY_ERR_SPAWN_FAILED, &
    FGOF_PTY_ERR_TIMEOUT, &
    FGOF_PTY_OK, &
    pty_session, &
    terminal_size
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
  public :: close_pty
  public :: default_terminal_size
  public :: pty_backend_name
  public :: pty_session
  public :: read_some
  public :: refresh_pty
  public :: resize_pty
  public :: spawn_pty
  public :: terminal_size
  public :: wait_pty
  public :: write_all

contains

  function pty_backend_name() result(name)
    character(len=:), allocatable :: name

    name = "posix"
  end function pty_backend_name

  function default_terminal_size() result(size)
    type(terminal_size) :: size
  end function default_terminal_size

  function spawn_pty(program, argv, size) result(session)
    character(len=*), intent(in) :: program
    character(len=*), intent(in), optional :: argv(:)
    type(terminal_size), intent(in), optional :: size
    type(pty_session) :: session
    type(terminal_size) :: launch_size

    call init_session(session)

    if (len_trim(program) == 0) then
      call set_error(session, FGOF_PTY_ERR_INVALID_COMMAND, "program must not be empty")
      return
    end if

    if (present(size)) then
      launch_size = size
    else
      launch_size = default_terminal_size()
    end if

    if (.not. valid_terminal_size(launch_size)) then
      call set_error(session, FGOF_PTY_ERR_INVALID_SIZE, "terminal size must use positive rows and cols")
      return
    end if

    call spawn_posix_pty(program, argv, launch_size, session)
  end function spawn_pty

  function read_some(session, max_bytes) result(text)
    type(pty_session), intent(inout) :: session
    integer, intent(in), optional :: max_bytes
    character(len=:), allocatable :: text
    integer :: byte_count

    call clear_error(session)

    if (.not. session%is_open) then
      call set_error(session, FGOF_PTY_ERR_IO_FAILED, "PTY session is not open")
      text = ""
      return
    end if

    if (present(max_bytes)) then
      byte_count = max_bytes
    else
      byte_count = 4096
    end if

    if (byte_count <= 0) then
      call set_error(session, FGOF_PTY_ERR_IO_FAILED, "max_bytes must be positive")
      text = ""
      return
    end if

    text = read_some_posix_pty(session, byte_count)
  end function read_some

  logical function write_all(session, text) result(success)
    type(pty_session), intent(inout) :: session
    character(len=*), intent(in) :: text

    call clear_error(session)

    if (.not. session%is_open) then
      call set_error(session, FGOF_PTY_ERR_IO_FAILED, "PTY session is not open")
      success = .false.
      return
    end if

    if (session%child_running) then
      if (.not. refresh_pty(session)) then
        success = .false.
        return
      end if
    end if

    if (session%completed .or. .not. session%child_running) then
      call set_error(session, FGOF_PTY_ERR_IO_FAILED, "PTY child is no longer running")
      success = .false.
      return
    end if

    success = write_all_posix_pty(session, text)
  end function write_all

  logical function resize_pty(session, size) result(success)
    type(pty_session), intent(inout) :: session
    type(terminal_size), intent(in) :: size

    call clear_error(session)

    if (.not. session%is_open) then
      call set_error(session, FGOF_PTY_ERR_RESIZE_FAILED, "PTY session is not open")
      success = .false.
      return
    end if

    if (.not. valid_terminal_size(size)) then
      call set_error(session, FGOF_PTY_ERR_INVALID_SIZE, "terminal size must use positive rows and cols")
      success = .false.
      return
    end if

    success = resize_posix_pty(session, size)
  end function resize_pty

  logical function close_pty(session) result(success)
    type(pty_session), intent(inout) :: session

    if (.not. session%is_open) then
      call clear_error(session)
      success = .true.
      return
    end if

    call clear_error(session)
    success = close_posix_pty(session)
  end function close_pty

  logical function refresh_pty(session) result(success)
    type(pty_session), intent(inout) :: session

    call clear_error(session)

    if (session%child_pid <= 0) then
      success = .true.
      return
    end if

    success = refresh_posix_pty(session)
  end function refresh_pty

  logical function wait_pty(session, timeout_ms) result(success)
    type(pty_session), intent(inout) :: session
    integer, intent(in) :: timeout_ms
    integer :: start_count
    integer :: current_count
    integer :: rate
    integer :: elapsed_ms

    call clear_error(session)

    if (.not. session%is_open .and. .not. session%completed) then
      call set_error(session, FGOF_PTY_ERR_IO_FAILED, "PTY session is not open")
      success = .false.
      return
    end if

    if (.not. session%child_running) then
      success = .true.
      return
    end if

    call system_clock(start_count, rate)
    do
      if (.not. refresh_posix_pty(session)) then
        success = .false.
        return
      end if

      if (.not. session%child_running) then
        success = .true.
        return
      end if

      call system_clock(current_count)
      if (rate > 0) then
        elapsed_ms = int((real(current_count - start_count) / real(rate)) * 1000.0)
      else
        elapsed_ms = max(0, timeout_ms) + 1
      end if

      if (elapsed_ms > max(0, timeout_ms)) then
        call set_error(session, FGOF_PTY_ERR_TIMEOUT, "PTY wait timed out")
        success = .false.
        return
      end if

      call spin_wait(20)
    end do
  end function wait_pty

  subroutine init_session(session)
    type(pty_session), intent(out) :: session

    session%master_fd = -1
    session%child_pid = -1
    session%is_open = .false.
    session%child_running = .false.
    session%completed = .false.
    session%exited_normally = .false.
    session%eof_reached = .false.
    session%exit_code = -1
    session%term_signal = 0
    session%size = default_terminal_size()
    session%error_code = FGOF_PTY_OK
    session%error_message = ""
  end subroutine init_session

  subroutine clear_error(session)
    type(pty_session), intent(inout) :: session

    session%error_code = FGOF_PTY_OK
    session%error_message = ""
  end subroutine clear_error

  subroutine set_error(session, code, message)
    type(pty_session), intent(inout) :: session
    integer, intent(in) :: code
    character(len=*), intent(in) :: message

    session%error_code = code
    session%error_message = trim(message)
  end subroutine set_error

  logical function valid_terminal_size(size) result(valid)
    type(terminal_size), intent(in) :: size

    valid = (size%rows > 0 .and. size%cols > 0)
  end function valid_terminal_size

  subroutine spin_wait(delay_ms)
    integer, intent(in) :: delay_ms
    integer :: start_count
    integer :: current_count
    integer :: rate
    integer :: elapsed_ms

    call system_clock(start_count, rate)
    if (rate <= 0) return

    do
      call system_clock(current_count)
      elapsed_ms = int((real(current_count - start_count) / real(rate)) * 1000.0)
      if (elapsed_ms >= delay_ms) exit
    end do
  end subroutine spin_wait

end module fgof_pty

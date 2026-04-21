program test_pty_api
  use fgof_pty, only : &
    FGOF_PTY_ERR_EXEC_FAILED, &
    FGOF_PTY_ERR_INVALID_COMMAND, &
    FGOF_PTY_ERR_INVALID_SIZE, &
    FGOF_PTY_OK, &
    close_pty, &
    default_terminal_size, &
    pty_backend_name, &
    pty_session, &
    spawn_pty, &
    terminal_size
  implicit none

  type(pty_session) :: session
  type(terminal_size) :: size
  character(len=20) :: argv(2)

  if (pty_backend_name() /= "posix") error stop "backend should report posix"

  size = default_terminal_size()
  if (size%rows <= 0) error stop "default rows should be positive"
  if (size%cols <= 0) error stop "default cols should be positive"

  session = spawn_pty("")
  if (session%error_code /= FGOF_PTY_ERR_INVALID_COMMAND) error stop "empty program should be rejected"
  if (session%is_open) error stop "invalid command should not open a session"

  session = spawn_pty("sh", size=terminal_size(rows=0, cols=80))
  if (session%error_code /= FGOF_PTY_ERR_INVALID_SIZE) error stop "invalid size should be rejected"

  session = spawn_pty("fgof-pty-missing-command")
  if (session%error_code /= FGOF_PTY_ERR_EXEC_FAILED) error stop "missing command should surface exec failure"

  argv = ""
  argv(1) = "-c"
  argv(2) = "exit 0"
  session = spawn_pty("sh", argv)
  if (session%error_code /= FGOF_PTY_OK) error stop "simple spawn should succeed"
  if (.not. session%is_open) error stop "successful spawn should open a session"

  if (.not. close_pty(session)) error stop "close_pty should succeed for open sessions"
  if (session%is_open) error stop "close_pty should mark session closed"
  if (session%master_fd /= -1) error stop "close_pty should clear master fd"
  if (session%child_pid /= -1) error stop "close_pty should clear child pid"
end program test_pty_api

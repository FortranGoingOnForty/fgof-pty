program test_pty_error_recovery
  use fgof_pty, only : &
    FGOF_PTY_ERR_RESIZE_FAILED, &
    FGOF_PTY_OK, &
    close_pty, &
    pty_session, &
    resize_pty, &
    spawn_pty, &
    terminal_size
  implicit none

  type(pty_session) :: session
  character(len=16) :: argv(2)
  integer :: real_master_fd

  argv = ""
  argv(1) = "-c"
  argv(2) = "sleep 5"
  session = spawn_pty("sh", argv)
  if (session%error_code /= FGOF_PTY_OK) error stop "recovery spawn should succeed"

  real_master_fd = session%master_fd
  session%master_fd = -1

  if (resize_pty(session, terminal_size(rows=40, cols=120))) error stop "resize should fail with invalid fd"
  if (session%error_code /= FGOF_PTY_ERR_RESIZE_FAILED) error stop "resize failure should report resize error"
  if (.not. session%is_open) error stop "backend errors should not mark session closed"
  if (.not. session%child_running) error stop "backend errors should preserve child state"

  session%master_fd = real_master_fd
  if (.not. close_pty(session)) error stop "close_pty should still clean up after backend error"
end program test_pty_error_recovery

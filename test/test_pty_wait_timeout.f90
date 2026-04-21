program test_pty_wait_timeout
  use fgof_pty, only : FGOF_PTY_ERR_TIMEOUT, FGOF_PTY_OK, close_pty, pty_session, spawn_pty, wait_pty
  implicit none

  type(pty_session) :: session
  character(len=64) :: argv(2)

  argv = ""
  argv(1) = "-c"
  argv(2) = "sleep 1"
  session = spawn_pty("sh", argv)
  if (session%error_code /= FGOF_PTY_OK) error stop "timeout spawn should succeed"

  if (wait_pty(session, 50)) error stop "wait_pty should time out for a sleeping child"
  if (session%error_code /= FGOF_PTY_ERR_TIMEOUT) error stop "timeout should set timeout error code"
  if (.not. session%child_running) error stop "timed-out wait should leave child marked running"

  if (.not. close_pty(session)) error stop "close_pty should still succeed after timeout"
end program test_pty_wait_timeout

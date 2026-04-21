program test_scaffold
  use fgof_pty, only : default_terminal_size, pty_backend_name
  use fgof_pty_types, only : pty_session, terminal_size
  implicit none

  type(terminal_size) :: size
  type(pty_session) :: session

  if (pty_backend_name() /= "posix") error stop "pty backend should report posix"

  size = default_terminal_size()
  if (size%rows <= 0) error stop "default rows should be positive"
  if (size%cols <= 0) error stop "default cols should be positive"

  if (session%is_open) error stop "default session should start closed"
  if (session%master_fd /= -1) error stop "default session master fd should be -1"
  if (session%child_pid /= -1) error stop "default session child pid should be -1"
end program test_scaffold

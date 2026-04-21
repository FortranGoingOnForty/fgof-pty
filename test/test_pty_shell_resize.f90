program test_pty_shell_resize
  use fgof_pty, only : FGOF_PTY_OK, close_pty, pty_session, read_some, resize_pty, spawn_pty, terminal_size, wait_pty, write_all
  implicit none

  type(pty_session) :: session
  character(len=96) :: argv(2)
  character(len=:), allocatable :: output

  argv = ""
  argv(1) = "-c"
  argv(2) = "stty size; read line; stty size"
  session = spawn_pty("sh", argv, terminal_size(rows=30, cols=100))
  if (session%error_code /= FGOF_PTY_OK) error stop "resize shell spawn should succeed"

  output = read_until_contains(session, "30 100", 3000)
  if (index(output, "30 100") == 0) error stop "child should see initial terminal size"

  if (.not. resize_pty(session, terminal_size(rows=40, cols=120))) error stop "resize_pty should succeed"
  if (.not. write_all(session, new_line("a"))) error stop "write_all should unblock shell read"

  output = read_until_contains(session, "40 120", 3000)
  if (index(output, "40 120") == 0) error stop "child should see resized terminal size"

  if (.not. wait_pty(session, 3000)) error stop "resize shell should exit after second stty"
  if (.not. close_pty(session)) error stop "close_pty should succeed after resize test"

contains

  function read_until_contains(session, needle, timeout_ms) result(text)
    type(pty_session), intent(inout) :: session
    character(len=*), intent(in) :: needle
    integer, intent(in) :: timeout_ms
    character(len=:), allocatable :: text
    character(len=:), allocatable :: chunk
    integer :: start_count
    integer :: current_count
    integer :: rate
    integer :: elapsed_ms

    text = ""
    call system_clock(start_count, rate)
    do
      chunk = read_some(session, 512)
      if (len(chunk) > 0) text = text // chunk
      if (index(text, needle) > 0) return

      call system_clock(current_count)
      if (rate > 0) then
        elapsed_ms = int((real(current_count - start_count) / real(rate)) * 1000.0)
      else
        elapsed_ms = timeout_ms + 1
      end if

      if (elapsed_ms > timeout_ms) return
      call spin_wait(20)
    end do
  end function read_until_contains

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

end program test_pty_shell_resize

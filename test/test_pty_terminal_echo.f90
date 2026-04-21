program test_pty_terminal_echo
  use fgof_pty, only : FGOF_PTY_OK, close_pty, pty_session, read_some, spawn_pty, wait_pty, write_all
  implicit none

  type(pty_session) :: session
  character(len=24) :: argv(2)
  character(len=:), allocatable :: output

  argv = ""
  argv(1) = "-c"
  argv(2) = "read line"
  session = spawn_pty("sh", argv)
  if (session%error_code /= FGOF_PTY_OK) error stop "echo spawn should succeed"

  if (.not. write_all(session, "echo still works" // new_line("a"))) error stop "write_all should succeed"
  output = read_until_contains(session, "echo still works", 3000)
  if (index(output, "echo still works") == 0) error stop "PTY should preserve default terminal echo"

  if (.not. wait_pty(session, 3000)) error stop "echo shell should exit after read"
  if (.not. close_pty(session)) error stop "close_pty should succeed after echo test"

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

end program test_pty_terminal_echo

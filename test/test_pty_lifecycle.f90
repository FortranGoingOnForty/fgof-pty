program test_pty_lifecycle
  use fgof_pty, only : FGOF_PTY_OK, close_pty, pty_session, read_some, refresh_pty, spawn_pty
  implicit none

  type(pty_session) :: session
  character(len=64) :: argv(2)
  character(len=:), allocatable :: output

  argv = ""
  argv(1) = "-c"
  argv(2) = "printf 'DONE\n'; exit 7"
  session = spawn_pty("sh", argv)
  if (session%error_code /= FGOF_PTY_OK) error stop "lifecycle spawn should succeed"

  output = read_until_contains(session, "DONE", 3000)
  if (index(output, "DONE") == 0) error stop "child should emit DONE before exit"

  if (.not. wait_for_exit(session, 3000)) error stop "refresh_pty should observe child exit"
  if (.not. session%completed) error stop "session should mark child as completed"
  if (.not. session%exited_normally) error stop "shell exit 7 should count as normal exit"
  if (session%exit_code /= 7) error stop "session should preserve child exit code"
  if (session%term_signal /= 0) error stop "normal exit should not report a signal"

  if (.not. close_pty(session)) error stop "close_pty should succeed after observed exit"
  if (.not. session%completed) error stop "close_pty should preserve completion state"
  if (session%exit_code /= 7) error stop "close_pty should preserve exit code"

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

  logical function wait_for_exit(session, timeout_ms) result(done)
    type(pty_session), intent(inout) :: session
    integer, intent(in) :: timeout_ms
    integer :: start_count
    integer :: current_count
    integer :: rate
    integer :: elapsed_ms

    done = .false.
    call system_clock(start_count, rate)
    do
      if (.not. refresh_pty(session)) return
      if (.not. session%child_running) then
        done = .true.
        return
      end if

      call system_clock(current_count)
      if (rate > 0) then
        elapsed_ms = int((real(current_count - start_count) / real(rate)) * 1000.0)
      else
        elapsed_ms = timeout_ms + 1
      end if

      if (elapsed_ms > timeout_ms) return
      call spin_wait(20)
    end do
  end function wait_for_exit

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

end program test_pty_lifecycle

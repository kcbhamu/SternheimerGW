  !
  !--------------------------------------------------------
  subroutine ktokpmq ( xk0, xq0, sign, nkq)
  !--------------------------------------------------------
  !
  !   For a given k point in cart coord, find the index 
  !   of the corresponding (k + sign*q) point
  !
  !--------------------------------------------------------
  !
  use parameters
  use constants
  use gspace
  use kspace
  implicit none
  !
  real(kind=DP) :: xk0 (3), xq0 (3)
  ! input: coordinates of k points and q points
  integer :: sign, ipool, nkq, nkq_abs
  ! input: +1 for searching k+q, -1 for k-q
  ! output: in the parallel case, the pool hosting the k+-q point    
  ! output: the index of k+sign*q
  ! output: the absolute index of k+sign*q (in the full k grid)
  !
  ! work variables
  !
  real(kind=DP) :: xxk (3), xxq (3)
  integer :: nkl, nkbl, nkr, iks, ik, i, j, k, n, jpool
  real(kind=DP) :: xx, yy, zz
  logical :: in_the_list
  !
  if (abs(sign).ne.1) call error ('ktokpmq','sign must be +1 or -1',1)
  !
  ! bring k and q in crystal coordinates
  !
  xxk = xk0
  xxq = xq0
  call cryst_to_cart (1, xxk, at, -1)
  call cryst_to_cart (1, xxq, at, -1)
  !
  !  check that k is actually on a uniform mesh centered at gamma
  !
  xx = xxk(1)*nq1
  yy = xxk(2)*nq2
  zz = xxk(3)*nq3
  in_the_list = abs(xx-nint(xx)).le.eps .and. &
                abs(yy-nint(yy)).le.eps .and. &
                abs(zz-nint(zz)).le.eps
  if (.not.in_the_list) call error ('ktokpmq','is this a uniform k-mesh?',1)
  !
  !  now add the phonon wavevector and check that k+q falls again on the k grid
  !
  xxk = xxk + float(sign) * xxq
  !
  xx = xxk(1)*nq1
  yy = xxk(2)*nq2
  zz = xxk(3)*nq3
  in_the_list = abs(xx-nint(xx)).le.eps .and. &
                abs(yy-nint(yy)).le.eps .and. &
                abs(zz-nint(zz)).le.eps
  if (.not.in_the_list) call error ('ktokpmq','k+q does not fall on k-grid',1)
  !
  !  find the index of this k+q in the k-grid
  !
  i = mod ( nint ( xx + 2*nq1), nq1 )
  j = mod ( nint ( yy + 2*nq2), nq2 )
  k = mod ( nint ( zz + 2*nq3), nq3 )
  n = i*nq2*nq3 + j*nq3 + k + 1
  !
  nkq = n
  !
  !  now n represents the index of k+sign*q in the original k grid.
  !
  end subroutine ktokpmq
  !--------------------------------------------------------

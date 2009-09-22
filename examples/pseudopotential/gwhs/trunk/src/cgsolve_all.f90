  !
  !-----------------------------------------------------------------------
!@  subroutine cgsolve_all (h_psi, cg_psi, e, d0psi, dpsi, h_diag, &
!@     ndmx, ndim, ethr, ik, kter, conv_root, anorm, nbnd)
  subroutine cgsolve_all (h_psi, e, d0psi, dpsi, h_diag, &
     ndmx, ndim, ethr, ik, kter, conv_root, anorm, nbnd, g2kin, vr, evq)
  !-----------------------------------------------------------------------
  !
  !     iterative solution of the linear system:
  !
  !                 ( h - e + Q ) * dpsi = d0psi                      (1)
  !
  !                 where h is a complex hermitean matrix, e is a real sca
  !                 dpsi and d0psi are complex vectors
  !
  !     on input:
  !                 h_psi    EXTERNAL  name of a subroutine:
  !                          h_psi(ndim,psi,psip)
  !                          Calculates  H*psi products.
  !                          Vectors psi and psip should be dimensined
  !                          (ndmx,nvec). nvec=1 is used!
  !
  !                 cg_psi   EXTERNAL  name of a subroutine:
  !                          g_psi(ndmx,ndim,notcnv,psi,e)
  !                          which calculates (h-e)^-1 * psi, with
  !                          some approximation, e.g. (diag(h)-e)
  !
  !                 e        real     unperturbed eigenvalue.
  !
  !                 dpsi     contains an estimate of the solution
  !                          vector.
  !
  !                 d0psi    contains the right hand side vector
  !                          of the system.
  !
  !                 ndmx     integer row dimension of dpsi, ecc.
  !
  !                 ndim     integer actual row dimension of dpsi
  !
  !                 ethr     real     convergence threshold. solution
  !                          improvement is stopped when the error in
  !                          eq (1), defined as l.h.s. - r.h.s., becomes
  !                          less than ethr in norm.
  !
  !     on output:  dpsi     contains the refined estimate of the
  !                          solution vector.
  !
  !                 d0psi    is corrupted on exit
  !
  !   revised (extensively)       6 Apr 1997 by A. Dal Corso & F. Mauri
  !   revised (to reduce memory) 29 May 2004 by S. de Gironcoli
  !
!@#include "f_defs.h"
!@  USE kinds, only : DP
  use parameters, only : DP, nbnd_occ
  use gspace, only : nr, ngm
!@
  implicit none
!@
  integer :: i
  complex(DP) :: vr(nr)
  real(DP) :: g2kin (ngm)
  complex(kind=DP) :: evq (ngm, nbnd_occ)
!@
  !
  !   first the I/O variables
  !
  integer :: ndmx, & ! input: the maximum dimension of the vectors
             ndim, & ! input: the actual dimension of the vectors
             kter, & ! output: counter on iterations
             nbnd, & ! input: the number of bands
             ik      ! input: the k point

  real(kind=DP) :: &
             e(nbnd), & ! input: the actual eigenvalue
             anorm,   & ! output: the norm of the error in the solution
             h_diag(ndmx,nbnd), & ! input: an estimate of ( H - \epsilon )
             ethr       ! input: the required precision

  complex(kind=DP) :: &
             dpsi (ndmx, nbnd), & ! output: the solution of the linear syst
             d0psi (ndmx, nbnd)   ! input: the known term

  logical :: conv_root ! output: if true the root is converged
  external h_psi, &    ! input: the routine computing h_psi
           cg_psi      ! input: the routine computing cg_psi
  !
  !  here the local variables
  !
  integer, parameter :: maxter = 200
  ! the maximum number of iterations
  integer :: iter, ibnd, lbnd
  ! counters on iteration, bands
  integer , allocatable :: conv (:)
  ! if 1 the root is converged

  complex(kind=DP), allocatable :: g (:,:), t (:,:), h (:,:), hold (:,:)
  !  the gradient of psi
  !  the preconditioned gradient
  !  the delta gradient
  !  the conjugate gradient
  !  work space
  complex(kind=DP) ::  dcgamma, dclambda, ZDOTC
  !  the ratio between rho
  !  step length
  !  the scalar product
  real(kind=DP), allocatable :: rho (:), rhoold (:), eu (:), a(:), c(:)
  ! the residue
  ! auxiliary for h_diag
  real(kind=DP) :: kter_eff
  ! account the number of iterations with b
  ! coefficient of quadratic form
  !
!@  call start_clock ('cgsolve')
  allocate ( g(ndmx,nbnd), t(ndmx,nbnd), h(ndmx,nbnd), hold(ndmx ,nbnd) )    
  allocate (a(nbnd), c(nbnd))    
  allocate (conv ( nbnd))    
  allocate (rho(nbnd),rhoold(nbnd))    
  allocate (eu (  nbnd))    
  !      WRITE( stdout,*) g,t,h,hold

  kter_eff = 0.d0
  do ibnd = 1, nbnd
     conv (ibnd) = 0
  enddo
  do iter = 1, maxter
     !
     !    compute the gradient. can reuse information from previous step
     !
     if (iter == 1) then
!@        call h_psi (ndim, dpsi, g, e, ik, nbnd)
        call h_psi ( dpsi, g, e, ik, nbnd, g2kin, vr, evq)
        do ibnd = 1, nbnd
           call ZAXPY (ndim, (-1.d0,0.d0), d0psi(1,ibnd), 1, g(1,ibnd), 1)
        enddo
     endif
     !
     !    compute preconditioned residual vector and convergence check
     !
     lbnd = 0
     do ibnd = 1, nbnd
        if (conv (ibnd) .eq.0) then
           lbnd = lbnd+1
           call ZCOPY (ndim, g (1, ibnd), 1, h (1, ibnd), 1)

!@         call cg_psi(ndmx, ndim, 1, h(1,ibnd), h_diag(1,ibnd) )
           do i = 1, ndim
             h (i, ibnd) = h (i, ibnd) * h_diag (i, ibnd)
           enddo
!@
           rho(lbnd) = ZDOTC (ndim, h(1,ibnd), 1, g(1,ibnd), 1)
        endif
     enddo
     kter_eff = kter_eff + float (lbnd) / float (nbnd)
!@#ifdef __PARA
!@     call reduce (lbnd, rho )
!@#endif
     do ibnd = nbnd, 1, -1
        if (conv(ibnd).eq.0) then
           rho(ibnd)=rho(lbnd)
           lbnd = lbnd -1
           anorm = sqrt (rho (ibnd) )
           if (anorm.lt.ethr) conv (ibnd) = 1
        endif
     enddo
!
     conv_root = .true.
     do ibnd = 1, nbnd
        conv_root = conv_root.and. (conv (ibnd) .eq.1)
     enddo
     if (conv_root) goto 100
     !
     !        compute the step direction h. Conjugate it to previous step
     !
     lbnd = 0
     do ibnd = 1, nbnd
        if (conv (ibnd) .eq.0) then
!
!          change sign to h 
!
           call DSCAL (2 * ndim, - 1.d0, h (1, ibnd), 1)
           if (iter.ne.1) then
              dcgamma = rho (ibnd) / rhoold (ibnd)
              call ZAXPY (ndim, dcgamma, hold (1, ibnd), 1, h (1, ibnd), 1)
           endif

!
! here hold is used as auxiliary vector in order to efficiently compute t = A*h
! it is later set to the current (becoming old) value of h 
!
           lbnd = lbnd+1
           call ZCOPY (ndim, h (1, ibnd), 1, hold (1, lbnd), 1)
           eu (lbnd) = e (ibnd)
        endif
     enddo
     !
     !        compute t = A*h
     !
!@@@
!@     call h_psi (ndim, hold, t, eu, ik, lbnd)
     call h_psi ( hold, t, eu, ik, lbnd, g2kin, vr, evq)
!@@@
     !
     !        compute the coefficients a and c for the line minimization
     !        compute step length lambda
     lbnd=0
     do ibnd = 1, nbnd
        if (conv (ibnd) .eq.0) then
           lbnd=lbnd+1
           a(lbnd) = ZDOTC (ndim, h(1,ibnd), 1, g(1,ibnd), 1)
           c(lbnd) = ZDOTC (ndim, h(1,ibnd), 1, t(1,lbnd), 1)
        end if
     end do
!@#ifdef __PARA
!@     call reduce (lbnd, a)
!@     call reduce (lbnd, c)
!@#endif
     lbnd=0
     do ibnd = 1, nbnd
        if (conv (ibnd) .eq.0) then
           lbnd=lbnd+1
           dclambda = DCMPLX ( - a(lbnd) / c(lbnd), 0.d0)
           !
           !    move to new position
           !
           call ZAXPY (ndim, dclambda, h(1,ibnd), 1, dpsi(1,ibnd), 1)
           !
           !    update to get the gradient
           !
           !g=g+lam
           call ZAXPY (ndim, dclambda, t(1,lbnd), 1, g(1,ibnd), 1)
           !
           !    save current (now old) h and rho for later use
           ! 
           call ZCOPY (ndim, h(1,ibnd), 1, hold(1,ibnd), 1)
           rhoold (ibnd) = rho (ibnd)
        endif
     enddo
  enddo
100 continue
  kter = kter_eff
  deallocate (eu)
  deallocate (rho, rhoold)
  deallocate (conv)
  deallocate (a,c)
  deallocate (g, t, h, hold)

!@  call stop_clock ('cgsolve')
  !
  return
  end subroutine cgsolve_all
  !

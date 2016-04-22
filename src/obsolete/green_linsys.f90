!------------------------------------------------------------------------------
!
! This file is part of the Sternheimer-GW code.
! 
! Copyright (C) 2010 - 2016 
! Henry Lambert, Martin Schlipf, and Feliciano Giustino
!
! Sternheimer-GW is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! Sternheimer-GW is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with Sternheimer-GW. If not, see
! http://www.gnu.org/licenses/gpl.html .
!
!------------------------------------------------------------------------------ 
SUBROUTINE green_linsys (ik0)
  USE kinds,                ONLY : DP
  USE ions_base,            ONLY : nat, ntyp => nsp, ityp
  USE io_global,            ONLY : stdout, ionode
  USE io_files,             ONLY : prefix, iunigk
  USE check_stop,           ONLY : check_stop_now
  USE wavefunctions_module, ONLY : evc
  USE constants,            ONLY : degspin, pi, tpi, RYTOEV, eps8
  USE cell_base,            ONLY : tpiba2
  USE ener,                 ONLY : ef
  USE klist,                ONLY : xk, wk, nkstot
  USE gvect,                ONLY : nrxx, g, nl, ngm, ecutwfc
  USE gsmooth,              ONLY : doublegrid, nrxxs, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, ngms
  USE lsda_mod,             ONLY : lsda, nspin, current_spin, isk
  USE wvfct,                ONLY : nbnd, npw, npwx, igk, g2kin, et
  USE uspp,                 ONLY : okvan, vkb
  USE uspp_param,           ONLY : upf, nhm, nh
  USE noncollin_module,     ONLY : noncolin, npol, nspin_mag
  USE paw_variables,        ONLY : okpaw
  USE paw_onecenter,        ONLY : paw_dpotential, paw_dusymmetrize, &
                                   paw_dumqsymmetrize
  USE control_gw,           ONLY : rec_code, niter_gw, nmix_gw, tr2_gw, &
                                   alpha_pv, lgamma, lgamma_gamma, convt, &
                                   nbnd_occ, alpha_mix, ldisp, rec_code_read, &
                                   current_iq, ext_recover, eta, tr2_green, w_green_start
  USE nlcc_gw,              ONLY : nlcc_any
  USE units_gw,             ONLY : iuwfc, lrwfc, iuwfcna, iungreen, lrgrn
  USE eqv,                  ONLY : evq, eprec
  USE qpoint,               ONLY : xq, npwq, igkq, nksq, ikks, ikqs
  USE recover_mod,          ONLY : read_rec, write_rec
  USE mp,                   ONLY : mp_sum
  USE disp,                 ONLY : nqs
  USE freq_gw,              ONLY : fpol, fiu, nfs, nfsmax, nwgreen, wgreen
  USE gwsigma,              ONLY : ngmgrn, ngmsco
  USE mp_global,            ONLY : inter_pool_comm, intra_pool_comm, mp_global_end, mpime, &
                                   nproc_pool, nproc, me_pool, my_pool_id, npool
  USE mp,                   ONLY: mp_barrier, mp_bcast, mp_sum

  IMPLICIT NONE 

  COMPLEX(DP) :: rhs(npwx, 1)
  COMPLEX(DP) :: aux1(npwx)
  COMPLEX(DP) :: ci, cw, green(ngmgrn,ngmgrn)
  COMPLEX(DP), ALLOCATABLE :: etc(:,:)
  COMPLEX(DP), ALLOCATABLE :: gr_A(:,:)

  REAL(DP)    :: eprecloc
  REAL(DP) :: thresh, anorm, averlt, dr2
  REAL(DP) :: dirac, delta
  REAL(DP) :: x
  REAL(DP) :: k0mq(3) 
  REAL(DP) :: w_ryd(nwgreen)
  REAL(DP) , ALLOCATABLE :: h_diag (:,:)
  REAL(DP) :: ar, ai

  INTEGER :: iw, igp, iwi
  INTEGER :: iq, ik0
  INTEGER :: ngvecs
  INTEGER :: rec0, n1
  INTEGER :: kter,       & ! counter on iterations
             iter0,      & ! starting iteration
             ipert,      & ! counter on perturbations
             ibnd,       & ! counter on bands
             iter,       & ! counter on iterations
             lter,       & ! counter on iterations of linear system
             ltaver,     & ! average counter
             lintercall, & ! average number of calls to cgsolve_all
             ik, ikk,    & ! counter on k points
             ikq,        & ! counter on k+q points
             ig,         & ! counter on G vectors
             ndim,       & ! integer actual row dimension of dpsi
             is,         & ! counter on spin polarizations
             nt,         & ! counter on types
             na,         & ! counter on atoms
             nrec, nrec1,& ! the record number for dvpsi and dpsi
             ios,        & ! integer variable for I/O control
             mode          ! mode index

  LOGICAL :: conv_root

  COMPLEX(DP), EXTERNAL :: zdotc
  EXTERNAL cg_psi, cch_psi_all_fix, cch_psi_all_green

  INTEGER, PARAMETER   ::  lmres = 1
  INTEGER     :: igkq_ig(npwx) 
  INTEGER     :: igkq_tmp(npwx) 
  INTEGER     :: counter
!PARALLEL
  INTEGER :: igstart, igstop, ngpool, ngr, igs
!LINALG

   ALLOCATE (h_diag (npwx, 1))
   ALLOCATE (etc(nbnd, nkstot))
   ALLOCATE(gr_A(npwx, 1))


   ci = (0.0d0, 1.0d0)


!Convert freq array generated in freqbins into rydbergs.
   w_ryd(:) = wgreen(:)/RYTOEV
   CALL start_clock('greenlinsys')
   if (nksq.gt.1) rewind (unit = iunigk)



!Loop over q in the IBZ_{k}
DO iq = w_green_start, nksq 
      if (lgamma) then
           ikq = iq
          else
           ikq = 2*iq
      endif
      if (nksq.gt.1) then
          read (iunigk, err = 100, iostat = ios) npw, igk
 100      call errore ('green_linsys', 'reading igk', abs (ios) )
      endif
      if(lgamma) npwq=npw 
      if (.not.lgamma.and.nksq.gt.1) then
           read (iunigk, err = 200, iostat = ios) npwq, igkq
 200       call errore ('green_linsys', 'reading igkq', abs (ios) )
      endif

!Need a loop to find all plane waves below ecutsco 
!when igkq takes us outside of this sphere.
!igkq_tmp is gamma centered index up to ngmsco,
!igkq_ig  is the linear index for looping up to npwq.

      counter = 0
      igkq_tmp(:) = 0
      igkq_ig(:)  = 0 
      do ig = 1, npwx
         if((igkq(ig).le.ngmgrn).and.((igkq(ig)).gt.0)) then
             counter = counter + 1
            !index in total G grid.
             igkq_tmp (counter) = igkq(ig)
            !index for loops 
             igkq_ig  (counter) = ig
         endif
      enddo

      if(nimage.gt.1) then
          CALL para_img(ngmunique, igstart, igstop)
      else
          igstart = 1
          igstop = ngmunique
      endif
      WRITE(6, '(5x, "iq ",i4, " igstart ", i4, " igstop ", i4)')iq, igstart, igstop

! Now the G-vecs up to the correlation cutoff have been divided between images.


      call init_us_2 (npwq, igkq, xk (1, ikq), vkb)
! psi_{k+q}(r) is every ikq entry
      call davcio (evq, lrwfc, iuwfc, ikq, - 1)
      do ig = 1, npwq
         g2kin (ig) = ((xk (1,ikq) + g (1, igkq(ig) ) ) **2 + &
                       (xk (2,ikq) + g (2, igkq(ig) ) ) **2 + &
                       (xk (3,ikq) + g (3, igkq(ig) ) ) **2 ) * tpiba2
      enddo

  WRITE(6, '(4x,"k0-q = (",3f12.7," )",10(3x,f7.3))') xk(:,ikq), et(:,ikq)*RYTOEV
  WRITE(600+mpime, '(4x,"k0-q = (",3f12.7," )",10(3x,f7.3))') xk(:,ikq), et(:,ikq)*RYTOEV
  aux1=(0.d0,0.d0)
  DO ig = 1, npwq
     aux1 (ig) = g2kin (ig) * evq (ig,4)
  END DO
  eprecloc = zdotc(npwx*npol, evq(1,4), 1, aux1(1),1)

  gr_A(:,:) = (0.0d0, 0.0d0)
  DO iw = 1, nwgreen
      green = DCMPLX(0.0d0, 0.0d0)
      h_diag(:,:) = 0.d0
      do ibnd = 1, 1
!For all elements up to <Ekin> use standard TPA:
         if (w_ryd(iw).le.0.0d0) then
            do ig = 1, npwq
!The preconditioner needs to be real and symmetric to decompose as E^T*E
               x = (g2kin(ig)-w_ryd(iw))
               h_diag(ig,ibnd) =  (27.d0+18.d0*x+12.d0*x*x+8.d0*x**3.d0) &
                                 /(27.d0+18.d0*x+12.d0*x*x+8.d0*x**3.d0+16.d0*x**4.d0)
            enddo
         else 
         !Really choosy preconditioner.
            do ig = 1, npwq
               if(g2kin(ig).gt.w_ryd(iw)) then
               !Trying without... 
                  x = (g2kin(ig)-w_ryd(iw))
               !maybe eprecloc is no goood...
               !  x = (g2kin(ig)-w_ryd(iw))
                  h_diag(ig,ibnd) =  (27.d0+18.d0*x+12.d0*x*x+8.d0*x**3.d0) &
                                    /(27.d0+18.d0*x+12.d0*x*x+8.d0*x**3.d0+16.d0*x**4.d0)
               else
                  h_diag(ig,ibnd) = 1.0d0
               endif
            enddo
         endif
      enddo
      do ig = igstart, igstop
         rhs(:,:)  = DCMPLX(0.0d0, 0.0d0)
         rhs(igkq_ig(ig), 1) = DCMPLX(-1.0d0, 0.0d0)
         gr_A(:,:) = DCMPLX(0.0d0, 0.0d0) 
         lter = 0
         etc(:, :) = CMPLX(0.0d0, 0.0d0, kind=DP)
         cw = CMPLX(w_ryd(iw), eta, kind=DP)
        !TR
        !cw = CMPLX(w_ryd(iw), -eta, kind=DP)
         anorm = 0.0d0
!Doing Linear System with Wavefunction cutoff (full density).
       call  cbicgstabl(cch_psi_all_green, cg_psi, etc(1,ikq), rhs, gr_A(:,1), h_diag, &
                        npwx, ngmsco, tr2_green, ikq, lter, conv_root, anorm, 1, npol, cw, lmres, .true.)
      if(.not.conv_root) write(600+mpime,'(2f15.6)') wgreen(iw), anorm
!In case of breakdown...
       ar = real(anorm)
       if (( ar .ne. ar )) then
          gr_A(:,:) = (0.0d0,0.0d0)
          write(600 + mpime,'("anorm imaginary")') 
       endif

       do igp = 1, counter
          green (igkq_tmp(ig), igkq_tmp(igp)) = green (igkq_tmp(ig), igkq_tmp(igp)) + gr_A(igkq_ig(igp),1)
          !HLTR
          !green (igkq_tmp(ig), igkq_tmp(igp)) = green (igkq_tmp(ig), igkq_tmp(igp)) + gr_A(igkq_ig(igp),1)
       enddo
      enddo !ig
!Green's Fxn Non-analytic Component:
!PARA
    do ig = igstart, igstop
       do igp = 1, counter       
!should be nbnd_occ:
        do ibnd = 1, nbnd
           x = et(ibnd, ikq) - w_ryd(iw)
           dirac = eta / pi / (x**2.d0 + eta**2.d0)
          !Green should now be indexed (igkq_tmp(ig), igkq_tmp(igp)) according to the
          !large G-grid which extends out to 4*ecutwfc. Keep this in mind when doing
          !ffts and taking matrix elements (especially matrix elements in G space!). 
          !Normal.
          green(igkq_tmp(ig), igkq_tmp(igp)) =  green(igkq_tmp(ig), igkq_tmp(igp))   + &
                                                tpi*ci*conjg(evq(igkq_ig(ig), ibnd)) * &
                                                evq(igkq_ig(igp), ibnd) * dirac
        enddo 
       enddo
    enddo 
!Collect G vectors across processors and then write the full green's function to file. 
#ifdef __PARA
    CALL mp_barrier(inter_image_comm)
!Collect all elements of green's matrix from different
!processors.
    CALL mp_sum (green, inter_image_comm )
    CALL mp_barrier(inter_image_comm)
    if(ionode) then
#endif
!HL Original:
!  rec0 = (iw-1) * 1 * nqs + (ik0-1) * nqs + (iq-1) + 1
     rec0 = (iw-1) * 1 * nksq + (iq-1) + 1
     CALL davcio(green, lrgrn, iungreen, rec0, +1, ios)
#ifdef __PARA
    endif
    CALL mp_barrier(inter_image_comm)
#endif
  ENDDO  ! iw 
ENDDO    ! iq
DEALLOCATE(h_diag)
DEALLOCATE(etc)

CALL stop_clock('greenlinsys')
RETURN
END SUBROUTINE green_linsys
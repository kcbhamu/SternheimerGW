!
! Copyright (C) 2001-2004 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!----------------------------------------------------------------------------
SUBROUTINE gwq_readin()
  !----------------------------------------------------------------------------
  !
  !    This routine reads the control variables for the program GW.
  !    from standard input (unit 5).
  !    A second routine readfile reads the variables saved on a file
  !    by the self-consistent program.
  !
  !
  USE kinds,         ONLY : DP
  USE parameters,    ONLY : nsx
  USE constants,     ONLY : RYTOEV
  USE ions_base,     ONLY : nat, ntyp => nsp
  USE io_global,     ONLY : ionode_id
  USE mp,            ONLY : mp_bcast
  USE mp_world,      ONLY : world_comm
  USE input_parameters, ONLY : max_seconds
  USE ions_base,     ONLY : amass, atm
  USE klist,         ONLY : xk, nks, nkstot, lgauss, two_fermi_energies
  USE control_flags, ONLY : gamma_only, tqr, restart, lkpoint_dir
  USE uspp,          ONLY : okvan
  USE fixed_occ,     ONLY : tfixed_occ
  USE lsda_mod,      ONLY : lsda, nspin
  USE run_info,      ONLY : title
  USE control_gw,    ONLY : maxter, alpha_mix, lgamma, lgamma_gamma, epsil, &
                            reduce_io, tr2_gw, niter_gw, tr2_green, &
                            nmix_gw, ldisp, recover, lrpa, lnoloc, start_irr, &
                            last_irr, start_q, last_q, current_iq, tmp_dir_gw, &
                            ext_recover, ext_restart, u_from_file, modielec, eta, &
                            do_coulomb, do_sigma_c, do_sigma_exx,do_sigma_exxG, do_green, do_sigma_matel, &
                            do_q0_only, maxter_green, godbyneeds, padecont, cohsex, multishift, do_sigma_extra, &
                            solve_direct, w_green_start, tinvert, coul_multishift, trunc_2d, do_epsil, do_serial, &
                            do_diag_g, do_diag_w, do_imag, do_pade_coul
  USE save_gw,       ONLY : tmp_dir_save
  USE qpoint,        ONLY : nksq, xq
  USE partial,       ONLY : atomo, list, nat_todo, nrapp
  USE output,        ONLY : fildyn, fildvscf, fildrho
  USE disp,          ONLY : nq1, nq2, nq3, iq1, iq2, iq3, xk_kpoints, kpoints, num_k_pts, w_of_q_start
  USE io_files,      ONLY : outdir, tmp_dir, prefix
  USE noncollin_module, ONLY : i_cons, noncolin
  USE ldaU,          ONLY : lda_plus_u
  USE control_flags, ONLY : iverbosity, modenum
  USE io_global,     ONLY : meta_ionode, meta_ionode_id, ionode, ionode_id, stdout
  USE mp_images,     ONLY : nimage, my_image_id, intra_image_comm,   &
                            me_image, nproc_image
  USE mp_global,     ONLY : nproc_pool_file, &
                            nproc_bgrp_file, nproc_image_file
  USE mp_pools,      ONLY : nproc_pool, npool
  USE mp_bands,      ONLY : nproc_bgrp, ntask_groups
  USE control_flags, ONLY : twfcollect
  USE paw_variables, ONLY : okpaw
  USE freq_gw,       ONLY : fpol, fiu, nfs, nfsmax, wsigmamin, wsigmamax, deltaw, wcoulmax, plasmon,&
                            greenzero
  USE gwsigma,       ONLY : ecutsig, nbnd_sig, ecutsex, ecutsco, ecutpol, ecutgrn
  USE gwsymm,        ONLY : use_symm
  !
  !
  IMPLICIT NONE
  !
  CHARACTER(LEN=256), EXTERNAL :: trimcheck
  !
  INTEGER :: ios, ipol, iter, na, it, ierr
  ! integer variable for I/O control
  ! counter on polarizations
  ! counter on iterations
  ! counter on atoms
  ! counter on types
  REAL(DP) :: amass_input(nsx)
  ! save masses read from input here
  !
  CHARACTER(LEN=80)          :: card
  CHARACTER(LEN=1), EXTERNAL :: capital
  CHARACTER(LEN=6) :: int_to_char
  INTEGER                    :: i
  LOGICAL                    :: nogg
  INTEGER, EXTERNAL  :: atomic_number
  REAL(DP), EXTERNAL :: atom_weight
  LOGICAL, EXTERNAL  :: imatches
  REAL(DP)           :: ar, ai
  !
  NAMELIST / INPUTGW / tr2_gw, amass, alpha_mix, niter_gw, nmix_gw,  &
                       nat_todo, iverbosity, outdir, epsil,  &
                       nrapp, max_seconds, reduce_io, &
                       modenum, prefix, fildyn, fildvscf, fildrho,   &
                       ldisp, nq1, nq2, nq3, iq1, iq2, iq3,   &
                       recover, fpol, lrpa, lnoloc, start_irr, last_irr, &
                       start_q, last_q, nogg, modielec, ecutsig, nbnd_sig, eta, kpoints,&
                       ecutsco, ecutsex, do_coulomb, do_sigma_c, do_sigma_exx, do_green,& 
                       do_sigma_matel, tr2_green, do_q0_only, wsigmamin, do_sigma_exxG,&
                       wsigmamax, deltaw, wcoulmax,&
                       use_symm, maxter_green, w_of_q_start, godbyneeds,& 
                       padecont, cohsex, ecutpol, ecutgrn, multishift, plasmon, do_sigma_extra,&
                       greenzero, solve_direct, w_green_start, tinvert, coul_multishift, trunc_2d,&
                       do_epsil, do_serial, do_diag_g, do_diag_w, do_imag, do_pade_coul

  ! alpha_mix    : the mixing parameter
  ! niter_gw     : maximum number of iterations
  ! nmix_gw      : number of previous iterations used in mixing
  ! nat_todo     : number of atom to be displaced
  ! iverbosity   : verbosity control
  ! outdir       : directory where input, output, temporary files reside
  ! max_seconds  : maximum cputime for this run
  ! reduce_io    : reduce I/O to the strict minimum
  ! prefix       : the prefix of files produced by pwscf
  ! fildvscf     : output file containing deltavsc
  ! fildrho      : output file containing deltarho
  ! eth_rps      : threshold for calculation of  Pc R |psi> (Raman)
  ! eth_ns       : threshold for non-scf wavefunction calculation (Raman)
  ! recover      : recover=.true. to restart from an interrupted run
  ! start_irr    : does the irred. representation from start_irr to last_irr
  ! last_irr     : 
  ! nogg         : if .true. lgamma_gamma tricks are not used

  IF (meta_ionode) THEN

  !
  ! flib/inpfile.f90!
  ! Reads in from standar input (5)
  ! 
     CALL input_from_file ( )
  !
  ! ... Read the first line of the input file
  !
     READ( 5, '(A)', IOSTAT = ios ) title
     WRITE(6,*) nsx, maxter
  !
  ENDIF
  !
  CALL mp_bcast(ios, meta_ionode_id, world_comm )
  CALL errore( 'gwq_readin', 'reading title ', ABS( ios ) )
  CALL mp_bcast(title, meta_ionode_id, world_comm  )
  !
  ! Rewind the input if the title is actually the beginning of inputgw namelist
  IF( imatches("&inputgw", title)) THEN
    WRITE(*, '(6x,a)') "Title line not specified: using 'default'."
    title='default'
    IF (meta_ionode) REWIND(5, iostat=ios)
    CALL mp_bcast(ios, meta_ionode_id, world_comm  )
    CALL errore('gwq_readin', 'Title line missing from input.', abs(ios))
  ENDIF
  !
  ! ... set default values for variables in namelist
  !
  tr2_gw       = 1.D-4
  tr2_green    = 1.D-4
  amass(:)     = 0.D0
  alpha_mix(:) = 0.D0
  alpha_mix(1) = 0.6D0
  niter_gw     = maxter
  nmix_gw      = 5
  nat_todo     = 0
  modenum      = 0
  nrapp        = 0
  iverbosity   = 0
  lnoloc       = .FALSE.
  epsil        = .FALSE.
  fpol         = .FALSE.
  max_seconds  =  1.E+7_DP
  reduce_io    = .FALSE.
  IF ( TRIM(outdir) == './') THEN
     CALL get_env( 'ESPRESSO_TMPDIR', outdir )
     IF ( TRIM( outdir ) == ' ' ) outdir = './'
  ENDIF
  prefix       = 'pwscf'
  fildyn       = 'matdyn'
  fildrho      = ' '
  fildvscf     = ' '
  nq1          = 0
  nq2          = 0
  nq3          = 0
  iq1          = 0
  iq2          = 0
  iq3          = 0
  nogg         = .FALSE.
  recover      = .FALSE.
  start_irr    = 0
  last_irr     = -1000
  start_q      = 1
  last_q       =-1000
  ldisp        = .FALSE.
  lrpa         = .FALSE.
  maxter_green  = 220
  w_green_start = 1

  do_serial       = .TRUE.
  coul_multishift = .FALSE.
  trunc_2d        = .FALSE.
  do_epsil        = .FALSE.
  do_diag_g       = .FALSE.
  do_diag_w       = .FALSE.
  do_imag         = .FALSE.
  do_pade_coul    = .FALSE.

!Sigma cutoff, correlation cutoff, exchange cutoff
  ecutsig      = 5.0
  plasmon      = 17.0d0
  greenzero    = 0.0d0 
 
!this is in case we want to define different cutoffs for 
!W and G. G cannot exceed sigma.
  ecutgrn      = ecutsig
  ecutpol      = ecutsig
  ecutsco      = ecutgrn
  ecutsex      = 5.0
  nbnd_sig     = 8

!Should have a catch if no model for screening is chosen...
  modielec     = .FALSE.
  godbyneeds   = .FALSE.
  cohsex       = .FALSE.
  padecont     = .FALSE.
  multishift   = .FALSE.


!imaginary component added to linear system should be in Rydberg
  eta            = 0.02
  kpoints        = .FALSE.
  do_coulomb     = .FALSE.
  do_sigma_c     = .FALSE.
  do_sigma_exx   = .FALSE.
  do_sigma_exxG   = .FALSE.
  do_green       = .FALSE.
  do_sigma_matel = .FALSE.
  do_sigma_extra = .FALSE.
  do_q0_only     = .FALSE.
  solve_direct   = .FALSE.
  tinvert        = .TRUE.

!Frequency variables
  wsigmamin      =-10.0d0
  wsigmamax      = 10.0d0
  deltaw         =  0.2d0 
  wcoulmax       = 80.0d0   

 !Symmetry Default:yes!, which q, point to start on.
 !can be used in conjunction with do_q0_only.
  use_symm       = .TRUE.
  w_of_q_start   = 1
  w_green_start  = 1 

  

  ! ...  reading the namelist inputgw

  IF (meta_ionode) READ( 5, INPUTGW, ERR=30, IOSTAT = ios )
!HL TEST PARA FINE
30 CALL mp_bcast(ios, meta_ionode_id, world_comm )
   CALL errore( 'gwq_readin', 'reading inputgw namelist', ABS( ios ) )
  IF (meta_ionode) tmp_dir = trimcheck (outdir)

  CALL bcast_gw_input ( ) 
  CALL mp_bcast(nogg, meta_ionode_id, world_comm  )


! write(6,'("broadcast.")')
! HL FINE

  !
  ! ... Check all namelist variables
  !
  IF (tr2_gw <= 0.D0) CALL errore (' gwq_readin', ' Wrong tr2_gw ', 1)
  IF (tr2_green <= 0.D0) CALL errore (' gwq_readin', ' Wrong tr2_green ', 1)

  !HL raman thresholds
  !IF (eth_rps<= 0.D0) CALL errore ( 'gwq_readin', ' Wrong eth_rps', 1)
  !IF (eth_ns <= 0.D0) CALL errore ( 'gwq_readin', ' Wrong eth_ns ', 1)

  DO iter = 1, maxter
     IF (alpha_mix (iter) .LT.0.D0.OR.alpha_mix (iter) .GT.1.D0) CALL &
          errore ('gwq_readin', ' Wrong alpha_mix ', iter)
  ENDDO
!  write(6,'("alphamix.")')

  IF (niter_gw.LT.1.OR.niter_gw.GT.maxter) CALL errore ('gwq_readin', &
       ' Wrong niter_gw ', 1)
  IF (nmix_gw.LT.1.OR.nmix_gw.GT.5) CALL errore ('gwq_readin', ' Wrong &
       &nmix_gw ', 1)
  !
  IF (iverbosity.NE.0.AND.iverbosity.NE.1) CALL errore ('gwq_readin', &
       &' Wrong  iverbosity ', 1)
  IF (fildyn.EQ.' ') CALL errore ('gwq_readin', ' Wrong fildyn ', 1)
  IF (max_seconds.LT.0.1D0) CALL errore ('gwq_readin', ' Wrong max_seconds', 1)

  IF (nat_todo.NE.0.AND.nrapp.NE.0) CALL errore ('gwq_readin', &
       &' incompatible flags', 1)
  IF (modenum < 0) CALL errore ('gwq_readin', ' Wrong modenum ', 1)
  !
  !
  IF (meta_ionode) THEN
    ios = 0 
     IF (.NOT. ldisp) &
        READ (5, *, iostat = ios) (xq (ipol), ipol = 1, 3)
  END IF

  CALL mp_bcast(ios, meta_ionode_id, world_comm )
  CALL errore ('gwq_readin', 'reading xq', ABS (ios) )
  CALL mp_bcast(xq, meta_ionode_id, world_comm  )


! HL here we can just use this to readin the list of frequencies that we want to calculate
! Stored in array  fiu(:), of size nfs.
! reads the frequencies ( just if fpol = .true. )
  IF ( fpol ) THEN
     nfs=0
     IF (meta_ionode) THEN
        READ (5, *, iostat = ios) card
        IF ( TRIM(card)=='FREQUENCIES'.OR. &
             TRIM(card)=='frequencies'.OR. &
             TRIM(card)=='Frequencies') THEN
           READ (5, *, iostat = ios) nfs
        ENDIF
     ENDIF

     CALL mp_bcast(ios, meta_ionode_id, world_comm )
     CALL errore ('gwq_readin', 'reading number of FREQUENCIES', ABS(ios) )
     CALL mp_bcast(nfs, meta_ionode_id, world_comm )

     if (nfs > nfsmax) call errore('gwq_readin','Too many frequencies',1) 
     if (nfs < 1) call errore('gwq_readin','Too few frequencies',1) 

     IF (meta_ionode) THEN
        IF ( TRIM(card) == 'FREQUENCIES' .OR. &
             TRIM(card) == 'frequencies' .OR. &
             TRIM(card) == 'Frequencies' ) THEN
           DO i = 1, nfs
              !HL Need to convert frequencies from electron volts into Rydbergs
              READ (5, *, iostat = ios) ar, ai 
              fiu(i) = dcmplx(ar, ai) / dcmplx(RYTOEV,0.0d0)
           END DO
        END IF
     END IF

     CALL mp_bcast(ios, meta_ionode_id, world_comm)
     CALL errore ('gwq_readin', 'reading FREQUENCIES card', ABS(ios) )
     CALL mp_bcast(fiu, meta_ionode_id, world_comm )
!     write(1000+mpime,*) fiu(:)

  ELSE
      nfs=0
     !fiu=0.0_DP
      fiu=DCMPLX(0.0d0, 0.d0)
      CALL mp_bcast(fiu, meta_ionode_id, world_comm )
  END IF
!  write(6,'("freq read.")')
! Reading in kpoints specified by user.
! Note max number of k-points is 10. 
! Why? Because that's the number I picked. 
! If k-points option is not specified it defaults to Gamma. 

 IF (kpoints) then
     num_k_pts = 0
     IF (meta_ionode) THEN
        READ (5, *, iostat = ios) card
        READ (5, *, iostat = ios) card
        IF ( TRIM(card)=='K_POINTS'.OR. &
             TRIM(card)=='k_points'.OR. &
             TRIM(card)=='K_points') THEN
           READ (5, *, iostat = ios) num_k_pts
        ENDIF
     ENDIF
     CALL mp_bcast(ios, meta_ionode_id, world_comm )
     CALL errore ('pwq_readin', 'reading number of kpoints', ABS(ios) )
     CALL mp_bcast(num_k_pts, meta_ionode_id, world_comm )
     if (num_k_pts > 10) call errore('phq_readin','Too many k-points',1) 
     if (num_k_pts < 1) call errore('phq_readin','Too few kpoints',1) 
     IF (meta_ionode) THEN
        IF ( TRIM(card)=='K_POINTS'.OR. &
             TRIM(card)=='k_points'.OR. &
             TRIM(card)=='K_points') THEN
           DO i = 1, num_k_pts
              !should be in units of 2pi/a0 cartesian co-ordinates
              READ (5, *, iostat = ios) xk_kpoints(1,i), xk_kpoints(2,i), xk_kpoints(3,i)
           END DO
        END IF
     END IF
     CALL mp_bcast(ios, meta_ionode_id, world_comm)
     CALL errore ('gwq_readin', 'reading KPOINTS card', ABS(ios) )
     CALL mp_bcast(xk_kpoints, meta_ionode_id, world_comm)
 ELSE
     num_k_pts = 1
 ENDIF
  !   Here we finished the reading of the input file.
  !   Now allocate space for pwscf variables, read and check them.
  !   amass will also be read from file:
  !   save its content in auxiliary variables
  !
  amass_input(:)= amass(:)
  !
  tmp_dir_save=tmp_dir
  tmp_dir_gw= TRIM (tmp_dir) // '_gw' // int_to_char(my_image_id)
  ext_restart=.FALSE.
  ext_recover=.FALSE.
  recover=.false.

  IF (recover) THEN
     CALL gw_readfile('init',ierr)
     IF (ierr /= 0 ) THEN
        recover=.FALSE.
        goto 1001
     ENDIF
     tmp_dir=tmp_dir_gw
     CALL check_restart_recover(ext_recover, ext_restart)
     tmp_dir=tmp_dir_save
     IF (ldisp) lgamma = (current_iq==1)
!
!  If there is a restart or a recover file gw.x has saved its own data-file 
!  and we read the initial information from that file
!
     IF ((ext_recover.OR.ext_restart).AND..NOT.lgamma) &
                                                      tmp_dir=tmp_dir_gw
     u_from_file=.true.
  ENDIF
1001 continue

  CALL read_file ( )

  tmp_dir=tmp_dir_save
  !
  IF (modenum > 3*nat) CALL errore ('gwq_readin', ' Wrong modenum ', 2)

  IF (gamma_only) CALL errore('gwq_readin',&
     'cannot start from pw.x data file using Gamma-point tricks',1)

  IF (nproc_image /= nproc_image_file .and. .not. twfcollect)  &
     CALL errore('gwq_readin',&
     'pw.x run with a different number of processors. Use wf_collect=.true.',1)

  IF (nproc_pool /= nproc_pool_file .and. .not. twfcollect)  &
     CALL errore('gwq_readin',&
     'pw.x run with a different number of pools. Use wf_collect=.true.',1)

  IF (start_irr < 0 ) CALL errore('gwq_readin', 'wrong start_irr',1)
  !
  IF (start_q <= 0 ) CALL errore('gwq_readin', 'wrong start_q',1)
  !
  !
  ! If a band structure calculation needs to be done do not open a file 
  ! for k point
  !
  lkpoint_dir=.FALSE.
  restart = recover
  !
  lgamma_gamma=.FALSE.
  IF (.NOT.ldisp) THEN
     IF (nkstot==1.OR.(nkstot==2.AND.nspin==2)) THEN
        lgamma_gamma=(lgamma.AND.(ABS(xk(1,1))<1.D-12) &
                            .AND.(ABS(xk(2,1))<1.D-12) &
                            .AND.(ABS(xk(3,1))<1.D-12) )
     ENDIF
     IF (nogg) lgamma_gamma=.FALSE.
     IF ((nat_todo /= 0 .or. nrapp /= 0 ) .and. lgamma_gamma) CALL errore( &
        'gwq_readin', 'gamma_gamma tricks with nat_todo or nrapp &
       & not available. Use nogg=.true.', 1)
     !
     IF (lgamma) THEN
        nksq = nks
     ELSE
        nksq = nks / 2
     ENDIF
  ENDIF

  IF ( nat_todo < 0 .OR. nat_todo > nat ) &
     CALL errore ('gwq_readin', 'nat_todo is wrong', 1)
  IF (nat_todo.NE.0) THEN
     IF (meta_ionode) &
     READ (5, *, iostat = ios) (atomo (na), na = 1, &
          nat_todo)
     CALL mp_bcast(ios, meta_ionode_id, world_comm )
     CALL errore ('gwq_readin', 'reading atoms', ABS (ios) )
     CALL mp_bcast(atomo, meta_ionode_id, world_comm )
  ENDIF
  IF (nrapp.LT.0.OR.nrapp.GT.3 * nat) CALL errore ('gwq_readin', &
       'nrapp is wrong', 1)
  IF (nrapp.NE.0) THEN
     IF (meta_ionode) &
     READ (5, *, iostat = ios) (list (na), na = 1, nrapp)
     CALL mp_bcast(ios, meta_ionode_id, world_comm )
     CALL errore ('gwq_readin', 'reading list', ABS (ios) )
     CALL mp_bcast(list, meta_ionode_id, world_comm )
  ENDIF
  
  IF (ldisp .AND. (nq1 .LE. 0 .OR. nq2 .LE. 0 .OR. nq3 .LE. 0)) &
      CALL errore('phq_readin','nq1, nq2, and nq3 must be greater than 0',1)
  RETURN
END SUBROUTINE gwq_readin
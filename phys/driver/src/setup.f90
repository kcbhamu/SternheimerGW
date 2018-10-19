!------------------------------------------------------------------------------
!
! This file is part of the SternheimerGW code.
! 
! Copyright (C) 2010 - 2018
! Henry Lambert, Martin Schlipf, and Feliciano Giustino
!
! SternheimerGW is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! SternheimerGW is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with SternheimerGW. If not, see
! http://www.gnu.org/licenses/gpl.html .
!
!------------------------------------------------------------------------------
MODULE setup_module

  IMPLICIT NONE

  PRIVATE
  PUBLIC setup_calculation

CONTAINS

  SUBROUTINE setup_calculation(calc)
    !
    USE check_stop,        ONLY: check_stop_init
    USE control_gw,        ONLY: do_imag, output
    USE environment,       ONLY: environment_start
    USE freq_gw,           ONLY: nwsigma, nwsigwin, wsigmamin, wsigmamax, wcoulmax, nwcoul, &
                                 wsig_wind_min, wsig_wind_max, nwsigwin
    USE freqbins_module,   ONLY: freqbins
    USE driver,            ONLY: calculation
    USE gw_container,      ONLY: open_container, write_k_point, backup, &
                                 consistent_dimension, write_dimension, gw_dimension
    USE gw_opening,        ONLY: gw_opening_logo, gw_opening_message
    USE gwsigma,           ONLY: ecutsco, ecutsex
    USE mp_global,         ONLY: mp_startup
    USE sigma_grid_module, ONLY: sigma_grid
    USE timing_module,     ONLY: time_setup
    !
    TYPE(calculation), INTENT(OUT) :: calc
    TYPE(gw_dimension) dims
    CHARACTER(*), PARAMETER :: code = 'SternheimerGW'
    LOGICAL backup_needed
    !
    ! Initialize MPI, clocks, print initial messages
    CALL mp_startup(start_images = .TRUE.)
    CALL gw_opening_logo()
    CALL environment_start(code)
    CALL gw_opening_message()
    ! Initialize GW calculation, read ground state information.
    ! Initialize frequency grids, FFT grids for correlation
    ! and exchange operators, open relevant GW-files.
    CALL start_clock(time_setup)
    CALL gwq_readin(calc%config_coul, calc%config_green, calc%freq, calc%vcut, calc%debug)
    CALL check_stop_init()
    CALL check_initial_status()
    CALL freqbins(do_imag, wsigmamin, wsigmamax, nwsigma, wcoulmax, nwcoul, &
                  wsig_wind_min, wsig_wind_max, nwsigwin, calc%freq)
    CALL sigma_grid(calc%freq, ecutsex, ecutsco, calc%grid)
    CALL open_container(output%file_data, calc%data)
    CALL write_k_point(calc%data)
    CALL determine_dimension(calc, dims)
    backup_needed = .NOT.consistent_dimension(calc%data, dims)
    IF (backup_needed) CALL backup(calc%data)
    CALL write_dimension(calc%data, dims)
    CALL stop_clock(time_setup)
    !
  END SUBROUTINE setup_calculation

  SUBROUTINE determine_dimension(calc, dims)
    !
    USE container_interface, ONLY: allocate_copy_from_to
    USE control_gw,   ONLY: do_epsil
    USE disp,         ONLY: nqs
    USE driver,       ONLY: calculation
    USE gw_container, ONLY: gw_dimension
    TYPE(calculation), INTENT(IN) :: calc
    TYPE(gw_dimension), INTENT(OUT) :: dims
    INTEGER num_g_exch, num_g_corr, num_k_pts, num_q_pts, num_freq_corr, num_freq_coul
    !
    num_g_exch = calc%grid%exch_fft%ngm
    num_g_corr = calc%grid%corr_fft%ngm
    num_k_pts = SIZE(calc%data%k_point, 2)
    IF (do_epsil) THEN
      num_q_pts = num_k_pts
    ELSE
      num_q_pts = nqs
    END IF
    num_freq_coul = SIZE(calc%freq%solver)
    num_freq_corr = calc%freq%num_sigma()
    CALL allocate_copy_from_to([num_g_corr, num_g_corr, num_freq_coul, num_q_pts], dims%coul)
    CALL allocate_copy_from_to([num_g_exch, num_g_exch, num_k_pts], dims%exch)
    CALL allocate_copy_from_to([num_g_corr, num_g_corr, num_freq_corr, num_k_pts], dims%corr)
    !
  END SUBROUTINE determine_dimension

END MODULE setup_module

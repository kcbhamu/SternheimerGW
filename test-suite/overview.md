<!--
 
  This file is part of the Sternheimer-GW code.
  
  Copyright (C) 2010 - 2016 
  Henry Lambert, Martin Schlipf, and Feliciano Giustino
 
  Sternheimer-GW is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
 
  Sternheimer-GW is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.
 
  You should have received a copy of the GNU General Public License
  along with Sternheimer-GW. If not, see
  http://www.gnu.org/licenses/gpl.html .
 
-->

Test suite for the SGW code
===========================

Features of the SGW code
------------------------

The following SGW features are tested in this suite

* evaluate the dielectric function on the imaginary axis
* evaluate the dielectric function along the real axis
* select a specific k-point for the dielectric constant
* manual selection of solver for W
* use the direct solver to determine the dielectric constant
* use the iterative solver to determine the dielectric constant
* Godby-Needs plasmon pole model to obtain a denser grid on the imaginary axis
* full frequency integration using Pade approximation to interpolate
* obtain the Green's function on the real axis
* obtain the Green's function on the imaginary axis
* use the multishift solver to obtain the Green's function
* convolute G and W on the imaginary axis to obtain the self energy
* obtain the exchange self energy
* overcome the divergence of the Coulomb potential with spherical truncation
* overcome the divergence of the Coulomb potential with 2d truncation
* overcome the divergence of the Coulomb potential with Wigner-Seitz truncation
* evaluate the quasi particle eigenvalues using the Z factor
* obtain the frequency dependent spectral function for all bands
* restart from previously calculated W

Test case: sgw\_bn
------------------

Evaluate the GW correction for a film of BN using the direct solver, plasmon
pole model, and imaginary frequency integration. We test both the 2d and the
Wigner-Seitz truncation.

The following SGW features are tested by this case

* evaluate the dielectric function on the imaginary axis
* use the direct solver to determine the dielectric constant
* Godby-Needs plasmon pole model to obtain a denser grid on the imaginary axis
* obtain the Green's function on the imaginary axis
* use the multishift solver to obtain the Green's function
* obtain the exchange self energy
* overcome the divergence of the Coulomb potential with 2d truncation
* overcome the divergence of the Coulomb potential with Wigner-Seitz truncation
* evaluate the quasi particle eigenvalues using the Z factor
* obtain the frequency dependent spectral function for all bands
* restart from previously calculated W

Test case: sgw\_c
-----------------

Evaluate the GW correction for C using the direct solver, imaginary frequency
integration, and full frequency integration for W.
Then evaluate the GW correction with a full frequency integration along the
real axis. In the first part, we use the padecont flag to go to the real axis,
in the second part, we restart and use the paderobust flag.

The following SGW features are tested by this case

* evaluate the dielectric function on the imaginary axis
* use the direct solver to determine the dielectric constant
* full frequency integration using Pade approximation to interpolate
* obtain the Green's function on the real axis
* obtain the Green's function on the imaginary axis
* use the multishift solver to obtain the Green's function
* convolute G and W on the imaginary axis to obtain self energy
* overcome the divergence of the Coulomb potential with spherical truncation
* evaluate the quasi particle eigenvalues using the Z factor
* obtain the frequency dependent spectral function for all bands
* restart from previously calculated W

Test case: sgw\_licl
--------------------

Evaluate the dielectric constant for LiCl using the direct solver. Manually
select the specialized solver for SGW.

The following SGW features are tested by this case:
* evaluate the dielectric function along the real axis
* use the direct solver to determine the dielectric constant
* select a specific k-point for the dielectric constant
* manual selection of solver for W

Test case: sgw\_si
------------------

Evaluate the GW correction for Si using the direct solver, imaginary frequency
integration, and a plasmon-pole model for W. Then restart the calculation to
evaluate the self energy for the X point.
As a separate calculation, evaluate the GW correction with the iterative solver.

The following SGW features are tested by this case

* evaluate the dielectric function on the imaginary axis
* use the direct solver to determine the dielectric constant
* use the iterative solver to determine the dielectric constant
* Godby-Needs plasmon pole model to obtain a denser grid on the imaginary axis
* obtain the Green's function on the imaginary axis
* use the multishift solver to obtain the Green's function
* convolute G and W on the imaginary axis to obtain the self energy
* obtain the exchange self energy
* overcome the divergence of the Coulomb potential with spherical truncation
* evaluate the quasi particle eigenvalues using the Z factor
* obtain the frequency dependent spectral function for all bands
* restart from previously calculated W
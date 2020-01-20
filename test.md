*Implementation of an Air-Based Building Integrated PV/Thermal Collector
(BIPV/T) Model*

*Kamel Haddad\*, Sébastien Brideau, Anil Parekh, 1 Hannel Drive, Ottawa,
ON, K1A 1M1,*

> \*Primary Contact:
> [[kamel.haddad\@canada.ca]{.underline}](mailto:kamel.haddad@canada.ca)*,
> (613) 947-9822*
>
> *Natural Resources Canada, CanmetENERGY-Ottawa*

Overview
========

Currently, E+ includes PV models with building integration capabilities,
and a simple PV/T model with constant thermal efficiency. This design
document provides details on the implementation of an advanced BIPVT
model in EnergyPlus. First the mathematical formulation of the model is
provided. Followed by the needed changes to the IDD and source code
files.

Mathematical model for BIPV/T air collector
===========================================

![](media/image1.png){width="5.010416666666667in"
height="3.5420866141732286in"}

Figure 1 Resistance circuit representation of BIPV/T collector - adapted
from Deslisle and Kummert, 2014. Light grey portion is representative of
building side and will be solved by E+ building solver.

The mathematical model discussed here is taken from work by Delisle and
Kummert (2014). The thermal resistance circuit representation is shown
in Figure 1.

The following equations describe energy balances on the various layers
of interest. These are the PV glazing outer layer, the PV cells, the PV
backing outer surface, and the air cavity.

Energy Balances:
----------------

### PV glazing outer surface:

> $0 = h_{conv,t}\left( T_{\text{PVg}} - T_{a} \right) + h_{rad,t}\left( T_{\text{PVg}} - T_{\text{sur}} \right) + \left( \frac{T_{\text{PVg}} - T_{\text{PV}}}{R_{PVg - PV}} \right)$
> \[1\]

### PV cells:

> $S + \left( \frac{T_{\text{PVg}} - T_{\text{PV}}}{R_{PVg - PV}} \right) = \left( \frac{T_{\text{PV}} - T_{1}}{R_{PV - 1}} \right)$
> \[2\]

### PV backing outer surface:

$\left( \frac{T_{\text{PV}} - T_{1}}{R_{PV - 1}} \right) + S_{1} = h_{conv,f1}\left( T_{1} - {\overline{T}}_{f} \right) + h_{rad,1 - 2}\left( T_{1} - T_{2} \right)$
\[3\]

### Air in cavity:

> $\dot{m}C_{p}\frac{dT_{f}}{\text{dx}} = \left\lbrack h_{conv,f1}\left( T_{1} - {\overline{T}}_{f} \right) + h_{conv,f2}\left( T_{2} - {\overline{T}}_{f} \right) \right\rbrack \cdot W$
> \[4\]

Where

> $S = \text{IAM}_{\text{PV}}\left( \text{τα} \right)_{PV,N}GF_{\text{cell}} - \eta_{\text{PV}}G$
> \[5\]
>
> $S_{1} = \text{IAM}_{\text{bs}}\left( \text{τα} \right)_{bs,N}G\left( 1 - F_{\text{cell}} \right)$
> \[6\]

Let

> $h_{PVg - PV} = \frac{1}{R_{Vg - PV}}$ \[7\]
>
> $h_{PV - 1} = \frac{1}{R_{PV - 1}}$ \[8\]

The radiative heat transfer coefficients are given by:

$h_{rad,t} = \varepsilon_{\text{PVg}}\sigma(T_{\text{PVg}}^{2} + T_{\text{surr}}^{2})(T_{\text{PVg}} + T_{\text{surr}})$
\[9\]

$h_{rad,1 - 2} = \frac{\sigma(T_{1}^{2} + T_{2}^{2})(T_{1} + T_{2})}{\frac{1}{\varepsilon_{1}} + \frac{1}{\varepsilon_{2}} - 1}$
\[10\]

The absorptance-transmittance product modifier:

$\text{IAM}_{\text{PV}} = 1 - b_{0,PV}\left( \frac{1}{\cos\theta} - 1 \right) - b_{1,PV}\left( \frac{1}{\cos\theta} - 1 \right)^{2}$
\[12\]

$\text{IAM}_{\text{bs}} = 1 - b_{o,bs}\left( \frac{1}{\cos\theta} - 1 \right) - b_{1,bs}\left( \frac{1}{cos\theta} - 1 \right)^{2}$
\[13\]

The PV efficiency is:

$դ_{\text{PV}} = \frac{P_{PV,max}}{\text{AG}}$ \[14\]

When the flow is turbulent inside the air channel, the heat transfer
coefficients *h~conv,f1~* and *h~conv,f2~* are calculated using the
Dittus Boetler equation for the Nusselt Number:

$Nu = 0.023\text{Re}^{0.8}\Pr^{n}$ \[15\]

where *n* = 0.4 for heating and *n* = 0.3 for cooling. When the flow is
laminar, a constant Nusselt Number (3.66) is used.

Solving the energy balances
---------------------------

There are two general approaches typically used to solving the energy
balance equations for collector models. Delisle and Kummert take a
finite difference approach and discretize the collector along the fluid
motion. The advantage of this is method is that the calculation of the
PV cell temperature at every node might improve the accuracy of the PV
model. The alternative approach is to solve for the average temperatures
along the flow direction analytically. This approach is taken by Duffie
and Beckman and in various models described by TESS for TRNSYS. This
methodology has for advantage to be faster than a full numerical
solution. However, it is possible that the results are slightly less
accurate due to the use of average temperatures to calculate PV
efficiency. The relative accuracy of either approach is unclear at this
time, and they have both been used extensively in the literature.
Because of this it was decided to use the analytical solution approach.

Summing Equations \[1\] through \[3\] and subtracting Equation \[4\]
gives:

$\frac{\dot{m}C_{p}}{W}\frac{dT_{f}}{\text{dx}} = S + S_{1} + h_{conv,f2}\left( T_{2} - T_{f} \right) + h_{conv,t}\left( T_{a} - T_{\text{PVg}} \right) + h_{rad,t}\left( T_{\text{sur}} - T_{\text{PVg}} \right) + h_{rad,1 - 2}\left( T_{2} - T_{1} \right)$

\[16\]

Let

$A = \ S + S_{1} + h_{conv,t}\left( T_{a} - T_{\text{PVg}} \right) + h_{rad,t}\left( T_{\text{sur}} - T_{\text{PVg}} \right) + h_{rad,1 - 2}\left( T_{2} - T_{1} \right)$
\[17\]

> $D = A + h_{conv,f2}T_{2}$ \[18\]
>
> $B = - h_{conv,f2}$ \[19\]

Therefore;

> $\dot{m}C_{p}\frac{dT_{f}}{\text{dx}} = DW + BWT_{f}$ \[20\]

Rearrange and integrate both sides for the entire length of the
collector (length=*L*)

$\int_{x = 0}^{x = L}{\frac{dT_{f}}{T_{f}B + D} = \int_{x = 0}^{x = L}\frac{W}{\dot{m}C_{p}}}\text{dx}$
\[21\]

Which gives:

> $T_{f}(L) = \left( T_{f}(0) + \frac{D}{B} \right)e^{\frac{\text{BWL}}{\dot{m}C_{p}}} - \frac{D}{B}$
> \[22\]

To find fluid temperature at any point *x*, replace *L* with distance x.

Average fluid temperature:

$\overline{T_{f}} = \frac{1}{L}\int_{x = 0}^{x = L}{T_{f}(x})dx = \left\lbrack \left. \ \frac{\dot{m}C_{p}\left( BT_{f}\left( 0 \right) + D \right)e^{\frac{\text{BWx}}{\dot{m}C_{p}}} - BDWx}{B^{2}W} \right|_{x = 0}^{x = L} \right\rbrack\frac{1}{L}$
\[23\]

$\overline{T_{f}} = \frac{\dot{m}C_{p}}{B^{2}\text{WL}}\left( BT_{f}(0) + D \right)e^{\frac{\text{BWL}}{\dot{m}C_{p}}} - \frac{D}{B} - \frac{\dot{m}C_{p}}{B^{2}\text{WL}}\left( BT_{f}(0) + D \right)$
\[24\]

If we assume that all temperatures are average over the length of the
collector, and if we assume that $T_{f}(0)$, $T_{2}$, $S$,$\ S_{1}$ are
known, we can solve equations 1, 2 and 3. Equations 1-3 can be
re-written as the following:

> \[25\]

This can then be easily solved with matrix inversion.

The PV temperature will be passed directly to the proper
"Photovoltaics.cc" subroutine to calculate the PV efficiency.

The steps to solve each time steps are:

1.  Assume (guess) values $\overline{T_{f}}$ and $T_{\text{PV}}$. If not
    the first time step, use previous time step values.

2.  Get current values of all boundary conditions

3.  Get PV efficiency from PV model using $T_{\text{PV}}$ from step 1.

4.  Update all the coefficients and constants in Equation \[25\]

5.  Solve Equation \[25\] (Gives values for $T_{\text{PVg}}$,
    $T_{\text{PV}}$, $T_{1}$)

6.  Solve Equation \[23\] (Gives $\overline{T_{f}}$)

7.  Iterate steps 2-6 until convergence.

8.  Calculate $T_{f}(L)$ using Equation \[22\]

9.  Calculate $\dot{Q} = \dot{m}C_{p}\left( T_{f}(L) - T_{f}(0) \right)$

Current EnergyPlus PVT Modeling Approach
----------------------------------------

A PVT system in EnergyPlus is modeled using object:

"SolarCollector:FlatPlate:PhotovoltaicThermal"

One of the inputs to this object is "Photovoltaic-Thermal Model
Performance Name". Currently the only option available for this input is
an object of type:

"SolarCollectorPerformance:PhotovoltaicThermal:Simple"

This object uses a fixed or scheduled thermal efficiency for the PVT
system. The new model for BIPVT will be based on a new IDF object named:

"SolarCollectorPerformance:PhotovoltaicThermal:BuildingIntegratedPVT"

Another input to object "SolarCollector:FlatPlate:PhotovoltaicThermal"
is "Photovoltaic Name" which is a reference to an object of type
"Generator:Photovoltaic". The photovoltaic generator object has three
methods for calculating the electrical performance of the PV cells:
"Simple", "EquivalentOne-Diode", and "Sandia". The photovoltaic
generator object also has a parameter "Heat Transfer Integration Mode"
that can specify a link to a
"SolarCollector:FlatPlate:PhotovoltaicThermal" object.

Changes to EnergyPlus IDD File
------------------------------

The new IDF object:

'SolarCollectorPerformance:PhotovoltaicThermal:BuildingIntegratedPVT"

will be entered in the EnergyPlus IDD file. Below is a description of
each of the fields in the IDD file for this new object and, if
applicable, the name of the variable in the model associated with input.
Some of the descriptions are taken from IDD file entries for the
following two objects:

'SolarCollector:UnglazedTranspired'

'SolarCollector:FlatPlate:PhotovoltaicThermal'

as they are similar to what this work is trying to achieve. This model
will only work for air-based thermal collectors, although the
'SolarCollector:FlatPlate:PhotovoltaicThermal' allows for water as well.

> 'SolarCollectorPerformance:PhotovoltaicThermal:BuildingIntegratedPVT'

1.  **Field: Name**

This field contains a unique name for the BIPVT solar collector

2.  **Field: Boundary Conditions Model Name**

This field contains the name of a
'SurfaceProperty:OtherSideConditionsModel' object declared elsewhere in
the input file. The "Type of Modelling" for this object will be set to
"GapConvectionRadiation". This will connect the collector to the
exterior boundary conditions for the underlying heat transfer surface in
the EnergyPlus building envelope model.

3.  **Field: Availability Schedule Name**

This field contains the name of a schedule to indicate when the solar
collector is available. When the schedule value is 0, the collector will
be bypassed. When the value is greater than 0 the collector is available
to provide heat recovery. If this field is left blank, it is assumed
that the collector is available.

4.  **Field: Effective Gap Plenum Behind PV modules**

This field is used to enter a nominal gap thickness for the collector.
This is used to calculate the convective heat transfer coefficient
behind the PV modules and on the building wall surface.

5.  **Field: Effective Overall Height of Collector**

This field is used to enter the nominal height of the collector. This is
defined as the distance from the inlet, (typically at the bottom of the
collector), to the outlet (typically at the top of the collector).

Model variable name: *L*

6.  **Field: Effective Overall Width of Collector**

This field is used to enter the nominal width of the collector.

Model variable name: *W*

7.  **Field: PV Transmittance-Absorptance Product**

This field is used to enter PV Normal Transmittance-Absorptance Product.
This value is typically not known and literature gives values between
approx. 0.8 to 0.9. Default value is 0.87.

Model variable name: ${(\tau\alpha)}_{PV,N}$

8.  **Field: Backing Material Normal Transmittance-Absorptance Product**

This field is used to enter Backing Material Normal
Transmittance-Absorptance Product. This value is typically not known.
Dependent on backing color. Values in absorptivity for tedlar in
literature vary between approx. 0.39 and 0.94. This would yield
Transmittance-Absorptance of between approx. 0.37 and 0.87. Default is
set to 0.87.

Model variable name: ${(\tau\alpha)}_{bs,N}$

9.  **Field: Fraction of collector gross area covered by PV cells**

This field is used to enter the Fraction of collector gross area covered
by PV cells. Generally around 0.85 but can vary.

Model variable name: *F~cell~*

10. **Field: PV glass thickness**

This field is used to enter the PV glass thickness in mm. It is usually
around 3 or 4 mm. This value is used to calculate the thermal resistance
of the encapsulating glass.

11. **Field: Backing material thickness**

This field is used to enter the backing materiel thickness in mm. It is
usually around 0.5 mm. This value is used to calculate the thermal
resistance of the backing material (assumed to be tedlar).

12. **Field: Emissivity PV modules**

This field is used to enter the emissivity of the PV modules. Usually
not known. Default is 0.85 for typical PV modules.

Model variable name: $\varepsilon_{PV,g}$

13. **Field: Emissivity of backing material**

This field is used to enter the emissivity of the backing material.
Usually not known. Default is 0.9 (black tedlar).

File "PhotovoltaicThermalCollectors.hh" List of Changes
-------------------------------------------------------

A new structure will be added to this file named "BIPVTModelStruct"
within "namespace PhotovoltaicThermalCollectors". The structure will
declare all the needed variables associated with the new model IDD
object
"SolarCollectorPerformance:PhotovoltaicThermal:BuildingIntegratedPVT".

File "PhotovoltaicThermalCollectors.cc" List of Changes
-------------------------------------------------------

1.  Subroutine "GetPVTcollectorsInput": Add code to read all the IDF
    file input variables for object:
    "SolarCollectorPerformance:PhotovoltaicThermal:BuildingIntegratedPVT".
    Also implement any diagnostic messages related to these inputs.

2.  Subroutine "PVTCollectorStruct::calculate()": Add code for
    implementation of the new BIPVT model as described in Equations
    1-25.

3.  Subroutine "PVTCollectorStruct::control()": Add reference to new
    BIPVT object.

4.  Subdroutine "PVTCollectorStruct::update()": Add code to update
    variables for object "OtherSideConnectionModel": *Tconv*, *Hconv*,
    *Trad*, and *Hrad*.

File "Photovoltaics.cc" List of Changes
---------------------------------------

1.  Add subroutine "GetPVTmodelIndex" to get index for object
    "SolarCollector:FlatPlate:PhotovoltaicThermal" associated with
    object "Generator:Photovoltaic". Also update appropriate header file
    to refer to this new subroutine.

2.  Subroutine "GetPVInput()": Invoke subroutine "GetPVTmodelIndex" to
    link object "Generator:Photovoltaic" to associated object
    "SolarCollector:FlatPlate:PhotovoltaicThermal" through the surface
    name on which "Generator:Photovoltaic" is mounted.

3.  Add subroutine "GetBIPVTTsColl" to get temperature of the BIPVT
    surface. Update appropriate header file to refer to this subroutine.

4.  Subroutine "CalcSandiaPV": Add call to subroutine "GetBIPVTTsColl"
    to get temperature of BIPVT surface.

5.  Subroutine "CalcTRNSYSPV": Add call to subroutine "GetBIPVTTsColl"
    to get temperature of BIPVT surface.

Input Output Reference Documentation
------------------------------------

A new section will added to the I/O documentation for the new object:
"SolarCollectorPerformance:PhotovoltaicThermal:BuildingIntegratedPVT".

Engineering Reference Documentation
-----------------------------------

A new section will be added to the Engineering documentation to on the
new BIPVT model added.

Example File
------------

A new example file will be created to demonstrate the new BIPVT model.

References
----------

Delisle, V. and Kummert, M. 2014. A novel approach to compare
building-integrated photovoltaic/thermal air collectors to side-by-side
PV modules and solar thermal collectors. Solar Energy, vol. 100, pp.
50-65.

Duffie, J. and Beckman, W. 2013. Solar Engineering of Thermal Processes.
4^th^ Edition. John Wiley and Sons. New York.

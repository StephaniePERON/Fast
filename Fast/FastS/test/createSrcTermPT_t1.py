# - source term (pyTree) -
import Converter.PyTree as C
import Generator.PyTree as G
import Initiator.PyTree as I
import Fast.PyTree as Fast
import FastS.PyTree as FastS
import Converter.Internal as Internal
import KCore.test as test
test.TOLERANCE=1.e-9

mach = 0.
npts = 251
h = 100./(npts-1)
smin = -50.

a = G.cart((smin-2*h,smin-2*h,0.), (h,h,h), (npts+4,npts+4,2))

t = C.newPyTree(['Base', a])
I._initConst(t, MInf=mach, loc='centers')
C._addState(t, 'GoverningEquations', 'Euler')
C._addState(t, 'EquationDimension', 2)
C._addState(t, adim='dim3', UInf=0.1, PInf=101103., RoInf=1.2, LInf=1., alphaZ=0., alphaY=0.)
I._initConst(t, loc='centers')
staref = C.getState(t)
G._getVolumeMap(t)

# Data source term
from math import *
pi = 4.*atan(1.)
gamma  = staref[11]
rgp    = staref[7]*(gamma-1.)
gam2   =  gamma*rgp
gam3   =  gam2/(gamma-1.)
coefa = 2.71128
coefb = 2.4
x0    = 0.
y0    = 0.
z0    = 0.
amp   = 0.01
per   = 0.014
phi   = 0.
rcrit = 30.

temps  = 0.
alpha  = 0.174#log(coefa)/(coefb*coefb)
omega  = 2.*pi/per
seuil = exp(-alpha*30.)

C._addBC2Zone(t, 'period', 'BCautoperiod', 'imin')
C._addBC2Zone(t, 'period', 'BCautoperiod', 'imax')
C._addBC2Zone(t, 'period', 'BCautoperiod', 'jmin')
C._addBC2Zone(t, 'period', 'BCautoperiod', 'jmax')

C._initVars(t,'{centers:r2}=({centers:CoordinateX}-%g)**2+({centers:CoordinateY}-%g)**2+({centers:CoordinateZ}-%g)**2'%(x0,y0,z0))

# Numerics
source = 1
numb = {}
numb["temporal_scheme"]    = "explicit"
numb["ss_iteration"]       = 10
numb["modulo_verif"]       = 5
numz = {}
numz["time_step"]          = 0.000044
numz["time_step_nature"]   = "global"
numz["scheme"]             = "roe"
numz["source"]         = source
Fast._setNum2Zones(t, numz); Fast._setNum2Base(t, numb)

(t, tc, metrics) = FastS.warmup(t, None)

nit = 100
timeStep = numz['time_step']
for it in range(nit):
    # create source term
    if source == 1:
        omt    = omega*temps+phi
        eps    = amp*sin(omt)
        C._initVars(t,'{centers:Density_src}=%g*exp(-%g*(({centers:r2}<%g)*{centers:r2}+({centers:r2}>%g)*%g))*{centers:vol}'%(eps,alpha,rcrit,rcrit,rcrit))
        C._initVars(t,'{centers:MomentumX_src}=0.')
        C._initVars(t,'{centers:MomentumY_src}=0.')
        C._initVars(t,'{centers:MomentumZ_src}=0.')
        C._initVars(t,'{centers:EnergyStagnationDensity_src}={centers:Temperature}*{centers:Density_src}*%g'%gam3)

    FastS._compute(t, metrics, it)
    temps += timeStep

Internal._rmNodesByName(t, '.Solver#Param')
Internal._rmNodesByName(t, '.Solver#ownData')
test.testT(t, 1)

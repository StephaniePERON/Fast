import Fast.PyTree as Fast
import FastS.PyTree as FastS
import Fast.FastIBM as FastIBM
import Converter.Internal as Internal
import KCore.test as test

##PREP
tb = FastIBM.naca0012(snear=0.005, alpha=0.)
t,tc = FastIBM.prepareIBMData(tb, None, None, vmin=21, expand=3, frontType=1)

####
# The following lines are to avoid regression since the bug fix for duplicate information in tc
####
for b in Internal.getBases(tc):
    for z in Internal.getZones(b):
        pos = 0
        z2 = Internal.copyRef(z)
        for zs in z2[2]:
            if 'ID' in zs[0] or 'IBCD' in zs[0]:
                Internal.addChild(z, zs, pos)
                pos +=2
            else:
                pos += 1
####

test.testT(t , 1)
test.testT(tc, 2)

##COMPUTE
numb = {}
numb["temporal_scheme"]    = "implicit"
numb["ss_iteration"]       = 1
numb["omp_mode"]           = 0
numb["modulo_verif"]       = 100

numz = {}
numz["time_step"]          = 3.e-5
numz["time_step_nature"]   = "local"
numz["cfl"]                = 5.
numz["scheme"]             = "roe"

it0 = 0.; time0 = 0.
Fast._setNum2Base(t, numb); Fast._setNum2Zones(t, numz)

t, tc, metrics = FastS.warmup(t, tc)

for it in range(200):
    if it%100 == 0: print("it %d / 200"%it, flush=True)
    FastS._compute(t, metrics, it, tc)

Internal._rmNodesFromName(t, 'Parameter_int')
Internal._rmNodesByName(t, '.Solver#Param')
Internal._rmNodesByName(t, '.Solver#ownData')
Internal._rmNodesFromName(tc, 'Parameter_int')
Internal._rmNodesByName(tc, '.Solver#Param')
Internal._rmNodesByName(tc, '.Solver#ownData')

test.testT(t , 3)
test.testT(tc, 4)

##POST
graphIBCDPost, ts = FastIBM.prepareSkinReconstruction(tb, tc, dimPb=2, ibctypes=[3])
FastIBM._computeSkinVariables(ts, tc, graphIBCDPost, ibctypes=[3], dimPb=2)

wall, aeroLoads = FastIBM.computeAerodynamicLoads(ts, dimPb=2, famZones=[], Pref=None, verbose=0)
wall, aeroLoads = FastIBM.computeAerodynamicCoefficients(wall, aeroLoads, dimPb=2, Sref=1., Lref=1., Qref=None, alpha=0., beta=0., verbose=0)

import Converter.PyTree as C
C._rmVars(wall, ['yplus', 'yplusIP'])

test.testT(wall, 5)
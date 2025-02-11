# - compute (pyTree) -
# - Monobloc laminar flat plate -
import Converter.PyTree as C
import Fast.PyTree as Fast
import FastS.PyTree as FastS
import Converter.Internal as Internal
import KCore.test as test

t = C.convertFile2PyTree('Pplane_136_96.cgns')
t = C.addState(t, MInf=0.2, ReInf=25.e6, MutSMuInf=15)

numb = {'temporal_scheme':'explicit', 'ss_iteration':30, 'modulo_verif':1}
numz = {'ssdom_IJK': [600, 30, 20000], 'io_thread': -4,
        'time_step':0.00000152280,
        'cfl': 7,
        'prandtltb': 0.92,
        'scheme':'ausmpred',
        'epsi_newton': 0.02}
Fast._setNum2Zones(t, numz); Fast._setNum2Base(t, numb)

(t, tc, metrics) = FastS.warmup(t, None)

nit = 500; time = 0.
for it in range(nit):
    FastS._compute(t, metrics, it)
    if it%100 == 0:
        print('- %d - %g'%(it, time))
        FastS.display_temporal_criteria(t, metrics, it, format='double')
    time += numz['time_step']

Internal._rmNodesByName(t, '.Solver#Param')
Internal._rmNodesByName(t, '.Solver#ownData')
test.testT(t, 1)

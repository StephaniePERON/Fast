# - compute (pyTree) -
# - Lamb vortex on octree -
import Fast.PyTree as Fast
import FastS.PyTree as FastS
import Converter.PyTree as C
import Distributor2.PyTree as D2
import Converter.Mpi as Cmpi
import Converter.Internal as Internal
import KCore.test as test
import sys

LOCAL = test.getLocal()

#mpirun -np 2 -genv OMP_NUM_THREADS=1 python lambOctreeDPT_t1.py
MInf = 0.7

rank = Cmpi.rank; size = Cmpi.size
FILE = 'lamb.cgns'; FILED = 'lambD.cgns'
# lecture du squelette
t = Cmpi.convertFile2SkeletonTree(FILE)
tc = Cmpi.convertFile2SkeletonTree(FILED)

# equilibrage
(t, dic) = D2.distribute(t, NProc=size, algorithm='fast', useCom=0)
tc = D2.copyDistribution(tc, t)
graph = Cmpi.computeGraph(tc, type='ID')
procDict = D2.getProcDict(tc)

# load des zones locales dans le squelette
t = Cmpi.readZones(t, FILE, rank=rank)
tc = Cmpi.readZones(tc, FILED, rank=rank)

t = Cmpi.convert2PartialTree(t)
tc = Cmpi.convert2PartialTree(tc)

Cmpi.convertPyTree2File(t, LOCAL+'/t1.cgns')
Cmpi.convertPyTree2File(tc, LOCAL+'/t1c.cgns')
#sys.exit()
Cmpi.barrier()
t,tc,ts,graph=Fast.load(LOCAL+'/t1.cgns', LOCAL+'/t1c.cgns', split='single')

# Init
t = C.addState(t, 'GoverningEquations', 'Euler')
t = C.addState(t, MInf=MInf)
# Numerics
numb = {}
numb["temporal_scheme"]    = "explicit"
numz = {}
numz["time_step"]          = 0.01
numz["scheme"]             = "ausmpred"
Fast._setNum2Zones(t, numz); Fast._setNum2Base(t, numb)

#Initialisation parametre calcul: calcul metric + var primitive + compactage + alignement + placement DRAM
graph1 ={'graphID':graph, 'graphIBCD':None, 'procDict':procDict}
#(t, tc, metrics) = FastS.warmup(t, tc, graph=graph)
(t, tc, metrics) = FastS.warmup(t, tc, graph=None)

nit = 1000; time = 0.
for it in range(nit):
    FastS._compute(t, metrics, it, tc)
    if rank == 0 and it%100 == 0:
        print('- %d - %g -'%(it, time)); sys.stdout.flush()
    time += numz['time_step']

Internal._rmNodesByName(t, '.Solver#Param')
Internal._rmNodesByName(t, '.Solver#ownData')
test.testT(t, 1)

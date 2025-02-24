# - Fast.MB -
import Fast.MB as App
import Converter.Mpi as Cmpi

myApp = App.MB(format='single')
myApp.set(numb={"temporal_scheme": "implicit",
                "ss_iteration":3})
myApp.set(numz={"time_step": 0.0007,
                "scheme":"roe_min",
                "time_step_nature":"local",
                "cfl":4.})

# Prepare
myApp.prepare('naca.cgns', t_out='t.cgns', tc_out='tc.cgns', NP=Cmpi.size)

# open compute
t, tc, ts, metrics, graph = myApp.setup('t.cgns', 'tc.cgns')

import FastS.PyTree as FastS
import Converter.Mpi as Cmpi

for it in range(1000):
    FastS._compute(t, metrics, it, tc, graph)
    if it%100 == 0:
        if Cmpi.rank == 0: print('- %d / %d'%(it,1000))
myApp.finalize(t, 'out.cgns')

# Post
myApp.post(t, 'out.cgns', 'wall.cgns')

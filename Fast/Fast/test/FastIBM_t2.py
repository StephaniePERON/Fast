# - Fast.IBM -
# Euler, para, frontType=1
import Fast.IBM as App
import Converter.PyTree as C
import Converter.Internal as Internal
import KCore.test as test

LOCAL = test.getLocal()

myApp = App.IBM(format='single')
myApp.set(numb={"temporal_scheme": "implicit",
                "ss_iteration":3,
                "omp_mode":0})
myApp.set(numz={"time_step": 0.0007,
                "scheme":"roe_min",
                "time_step_nature":"local",
                "cfl":4.})

# Prepare
t, tc = App.prepare1('naca1DEuler.cgns', t_out=LOCAL+'/t.cgns', tc_out=LOCAL+'/tc.cgns')
Internal._rmNodesFromType(tc,'Rind_t')
Internal._rmNodesFromName(tc,Internal.__GridCoordinates__)
test.testT(tc, 1)

# Compute
t, tc = myApp.compute(LOCAL+'/t.cgns', LOCAL+'/tc.cgns', t_out=LOCAL+'/restart.cgns', tc_out=LOCAL+'/tc_restart.cgns', nit=300)
t = C.convertFile2PyTree(LOCAL+'/restart.cgns')
Internal._rmNodesByName(t, '.Solver#Param')
Internal._rmNodesByName(t, '.Solver#ownData')
Internal._rmNodesByName(t, '.Solver#dtloc')
Internal._rmNodesFromType(t, 'Rind_t')
test.testT(t, 2)

# Post
t, zw = myApp.post('naca1DEuler.cgns', LOCAL+'/restart.cgns', LOCAL+'/tc_restart.cgns', t_out=LOCAL+'/out.cgns', wall_out=LOCAL+'/wall.cgns')
Internal._rmNodesFromType(t, 'Rind_t')
Internal._rmNodesByName(t, '.Solver#dtloc')
test.testT(t, 3)

/*    
    Copyright 2013-2025 Onera.

    This file is part of Cassiopee.

    Cassiopee is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Cassiopee is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Cassiopee.  If not, see <http://www.gnu.org/licenses/>.
*/

# include "fastS.h"
# include "param_solver.h"
# include "string.h"
#ifdef _OPENMP
# include <omp.h>
#endif
using namespace std;
using namespace K_FLD;

//=============================================================================
// Compute pour l'interface pyTree
//=============================================================================
PyObject* K_FASTS::computePT_gradient(PyObject* self, PyObject* args)
{
  PyObject* zones; PyObject* metrics; PyObject* work; PyObject* vars; PyObject* varsgrad;
  E_Int order;
#if defined E_DOUBLEINT
  if (!PyArg_ParseTuple(args, "OOOOOl", &zones , &metrics, &vars ,&varsgrad,  &work, &order)) return NULL;
#else 
  if (!PyArg_ParseTuple(args, "OOOOOi", &zones , &metrics, &vars ,&varsgrad,  &work, &order)) return NULL;
#endif


  /* tableau pour stocker dimension sous-domaine omp */
  E_Int threadmax_sdm = 1;
#ifdef _OPENMP
  threadmax_sdm  = omp_get_max_threads();
#endif

  PyObject* tmp = PyDict_GetItemString(work, "MX_SYNCHRO"); E_Int mx_synchro    = PyLong_AsLong(tmp); 

  PyObject* dtlocArray  = PyDict_GetItemString(work,"dtloc"); FldArrayI* dtloc;
  K_NUMPY::getFromNumpyArray(dtlocArray, dtloc, true); E_Int* iptdtloc  = dtloc->begin();
  E_Int nssiter = iptdtloc[0];
  E_Int ompmode  = iptdtloc[8];
  E_Int shift_omp= iptdtloc[11];
  E_Int* ipt_omp = iptdtloc + shift_omp;

  E_Int nidom        = PyList_Size(zones);

  //recherche nombre maximale de gradient a calculer sur l'ensemble des zones
  E_Int nivarMax=0;  
  E_Int nivar[nidom];
  for (E_Int nd = 0; nd < nidom; nd++)
    { PyObject* tmp    = PyList_GetItem(vars       , nd  );
       nivar[nd]       = PyList_Size(tmp);
       if(nivar[nd] > nivarMax) nivarMax=nivar[nd];
    }

  E_Int ndimdx       = 0;
  E_Int neq_grad     = 3;

  //printf("nombre de zone a traiter= %d\n",nidom);

  E_Float** iptro; E_Float** iptQ; //E_Float** iptvort; E_Float** iptenst;
  E_Float** ipti;  E_Float** iptj;  E_Float** iptk; E_Float** iptvol;
  E_Float** ipti_df; E_Float** iptj_df;  E_Float** iptk_df ; E_Float** iptvol_df;
  E_Float** ipt_param_real; E_Float** iptvar; E_Float** iptgra;

  E_Int**   ipt_param_int;

  ipt_param_real    = new  E_Float*[nidom*13];
  iptro             = ipt_param_real + nidom;
  iptQ              = iptro          + nidom;
  ipti              = iptQ           + nidom;
  iptj              = ipti           + nidom;
  iptk              = iptj           + nidom;
  iptvol            = iptk           + nidom;
  ipti_df           = iptvol         + nidom;
  iptj_df           = ipti_df        + nidom;
  iptk_df           = iptj_df        + nidom;
  iptvol_df         = iptk_df        + nidom;
  //iptvort           = iptvol_df      + nidom;
  //iptenst           = iptvort        + nidom;
 
  iptvar            = new  E_Float*[nidom*nivarMax];
  iptgra            = new  E_Float*[nidom*nivarMax];

  ipt_param_int     = new  E_Int*[nidom];


  vector<PyArrayObject*> hook;


  for (E_Int nd = 0; nd < nidom; nd++)
  { 
    // check zone
    PyObject* zone    = PyList_GetItem(zones   , nd); // domaine i

    /* Get numerics from zone */
    PyObject*   numerics  = K_PYTREE::getNodeFromName1(zone    , ".Solver#ownData");
    PyObject*          t  = K_PYTREE::getNodeFromName1(numerics, "Parameter_int"); 
    ipt_param_int[nd]     = K_PYTREE::getValueAI(t, hook);
                       t  = K_PYTREE::getNodeFromName1(numerics, "Parameter_real"); 
    ipt_param_real[nd]    = K_PYTREE::getValueAF(t, hook);

    /* Get var et grad from zone */
    PyObject* varzone = PyList_GetItem(vars       , nd  );
    for (E_Int nv = 0; nv < nivar[nd]; nv++)
       { 
        // check var
        PyObject* var    = PyList_GetItem(varzone     , nv  ); 
        char* var_c;
        if (PyString_Check(var)) var_c = PyString_AsString(var);
#if PY_VERSION_HEX >= 0x03000000
        else if (PyUnicode_Check(var)) var_c = (char*)PyUnicode_AsUTF8(var);
#endif
        else var_c = NULL; 
        PyObject* vargrad= PyList_GetItem(varsgrad   , nv*3);
        char* vargrad_c; 
        if (PyString_Check(vargrad)) vargrad_c = PyString_AsString(vargrad);
#if PY_VERSION_HEX >= 0x03000000
        else if (PyUnicode_Check(vargrad)) vargrad_c = (char*)PyUnicode_AsUTF8(vargrad);
#endif
        else vargrad_c = NULL; 


        PyObject* sol_center;
        sol_center        = K_PYTREE::getNodeFromName1(zone      , "FlowSolution#Centers");

        t                  = K_PYTREE::getNodeFromName1(sol_center, var_c);
        iptvar[nv+nd*nivarMax]= K_PYTREE::getValueAF(t, hook);

        t                  = K_PYTREE::getNodeFromName1(sol_center, vargrad_c);
        iptgra[nv+nd*nivarMax]= K_PYTREE::getValueAF(t, hook);
        }

    // Check metrics
    PyObject* metric = PyList_GetItem(metrics, nd); // metric du domaine i

    GET_TI(   METRIC_TI  , metric, ipt_param_int[nd], ipti [nd]  , iptj [nd]  , iptk [nd]  , iptvol[nd]    )
    GET_TI(   METRIC_TIDF, metric, ipt_param_int[nd], ipti_df[nd], iptj_df[nd], iptk_df[nd], iptvol_df[nd] )

   if( ipt_param_int[nd][ NDIMDX ] > ndimdx ){ ndimdx = ipt_param_int[nd][ NDIMDX ]; } 
  }
  
//
//  
//  Reservation tableau travail temporaire pour calcul du champ N+1
//

  //printf("thread =%d\n",threadmax_sdm);
  //FldArrayI compteur(     threadmax_sdm); E_Int* ipt_compteur   =  compteur.begin();
  FldArrayI ijkv_sdm(   3*threadmax_sdm); E_Int* ipt_ijkv_sdm   =  ijkv_sdm.begin();
  FldArrayI topology(   3*threadmax_sdm); E_Int* ipt_topology   =  topology.begin();
  FldArrayI ind_dm(     6*threadmax_sdm); E_Int* ipt_ind_dm     =  ind_dm.begin();
  FldArrayI ind_dm_omp(12*threadmax_sdm); E_Int* ipt_ind_dm_omp =  ind_dm_omp.begin();


  // Tableau de travail verrou omp
  PyObject* lokArray = PyDict_GetItemString(work,"verrou_omp"); FldArrayI* lok;
  K_NUMPY::getFromNumpyArray(lokArray, lok, true); E_Int* ipt_lok  = lok->begin();

#pragma omp parallel default(shared)
  {
#ifdef _OPENMP
    E_Int  ithread           = omp_get_thread_num() +1;
    E_Int  Nbre_thread_actif = omp_get_num_threads();
#else
    E_Int ithread = 1;
    E_Int Nbre_thread_actif = 1;
#endif
# include "FastC/HPC_LAYER/INFO_SOCKET.h"

      //
      //---------------------------------------------------------------------
      // -----Boucle sur num.les domaines de la configuration
      // ---------------------------------------------------------------------
      E_Int nitcfg =1;

      E_Int nbtask = ipt_omp[nitcfg-1]; 
      E_Int ptiter = ipt_omp[nssiter+ nitcfg-1];

      for (E_Int ntask = 0; ntask < nbtask; ntask++)
        {
          E_Int pttask = ptiter + ntask*(6+Nbre_thread_actif*7);
          E_Int nd = ipt_omp[ pttask ];

          E_Int* ipt_ind_dm_loc         = ipt_ind_dm         + (ithread-1)*6;
          ipt_ind_dm_loc[0] = 1; ipt_ind_dm_loc[2] = 1; ipt_ind_dm_loc[4] = 1;
          ipt_ind_dm_loc[1] = ipt_param_int[nd][ IJKV];
          ipt_ind_dm_loc[3] = ipt_param_int[nd][ IJKV+1];
          ipt_ind_dm_loc[5] = ipt_param_int[nd][ IJKV+2];

          E_Int* ipt_topology_socket    = ipt_topology       + (ithread-1)*3; 
          E_Int* ipt_ijkv_sdm_thread    = ipt_ijkv_sdm       + (ithread-1)*3; 
          E_Int* ipt_ind_dm_socket      = ipt_ind_dm_omp     + (ithread-1)*12;

          // Distribution de la sous-zone sur les threads
          E_Int lmin =4;

          E_Int* ipt_topo_omp; E_Int* ipt_inddm_omp;
          E_Int ithread_loc           = ipt_omp[ pttask + 2 + ithread -1 ] +1 ;
          E_Int nd_subzone            = ipt_omp[ pttask + 1 ];
          E_Int Nbre_thread_actif_loc = ipt_omp[ pttask + 2 + Nbre_thread_actif ];
          ipt_topo_omp                = ipt_omp + pttask + 3 + Nbre_thread_actif ;
          ipt_inddm_omp               = ipt_omp + pttask + 6 + Nbre_thread_actif + (ithread_loc-1)*6;

          if (ithread_loc == -1) { continue;}

          indice_boucle_lu_(nd, socket , Nbre_socket, lmin,
                            ipt_ind_dm_loc, 
                            ipt_topology_socket, ipt_ind_dm_socket );

          E_Int* ipt_lok_thread   = ipt_lok   + ntask*mx_synchro*Nbre_thread_actif;

          for (E_Int nv = 0; nv < nivar[nd]; nv++)
            { 
                post_grad_(nd, Nbre_thread_actif_loc, ithread_loc, Nbre_socket, socket, mx_synchro, neq_grad, order,
                             ipt_param_int[nd]  , ipt_param_real[nd], ipt_ijkv_sdm_thread,
                             ipt_ind_dm_loc     , ipt_ind_dm_socket , ipt_inddm_omp, ipt_topo_omp,
                             ipt_topology_socket, ipt_lok_thread    ,
                             iptvar[nv+nd*nivarMax], ipti[nd] , iptj[nd] , iptk[nd] , iptvol[nd]  , iptgra[nv+nd*nivarMax]);  
            }// boucle var  
          }// boucle zone 
# include "FastC/HPC_LAYER/INIT_LOCK.h"
  }  // zone OMP


  delete [] ipt_param_real;
  delete [] ipt_param_int;
  delete [] iptvar;
  delete [] iptgra;
  
  RELEASESHAREDN(dtlocArray, dtloc);
  RELEASESHAREDN( lokArray  , lok  );
  RELEASEHOOK(hook)

  Py_INCREF(Py_None);
  return Py_None;
}

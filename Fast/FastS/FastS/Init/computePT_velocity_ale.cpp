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


# include "FastS/fastS.h"
# include "FastS/param_solver.h"
# include "string.h"
#ifdef _OPENMP
# include <omp.h>
#endif
using namespace std;
using namespace K_FLD;

//=============================================================================
// Compute pour l'interface pyTree
//=============================================================================
PyObject* K_FASTS::computePT_velocity_ale(PyObject* self, PyObject* args)
{
    PyObject* zones; PyObject* metrics; PyObject* work;
    E_Int omp_mode;
#if defined E_DOUBLEINT
  if (!PyArg_ParseTuple(args, "OOOl", &zones , &metrics, &work, &omp_mode)) return NULL; 
#else 
  if (!PyArg_ParseTuple(args, "OOOi", &zones , &metrics, &work, &omp_mode)) return NULL;
#endif

    /* tableau pour stocker dimension sous-domaine omp */
    E_Int threadmax_sdm = 1;
#ifdef _OPENMP
    threadmax_sdm  = omp_get_max_threads();
#endif

  PyObject* tmp = PyDict_GetItemString(work,"MX_SYNCHRO"); E_Int mx_synchro = PyLong_AsLong(tmp); 
            tmp = PyDict_GetItemString(work,"MX_SSZONE");  //E_Int mx_sszone  = PyLong_AsLong(tmp);

  PyObject* dtlocArray  = PyDict_GetItemString(work,"dtloc"); FldArrayI* dtloc;
  K_NUMPY::getFromNumpyArray(dtlocArray, dtloc, true); E_Int* iptdtloc  = dtloc->begin();
  E_Int nssiter = iptdtloc[0];
  E_Int shift_omp= iptdtloc[11];
  E_Int* ipt_omp = iptdtloc + shift_omp;

  E_Int nidom        = PyList_Size(zones);
  E_Int ndimdx       = 0;

  //printf("nombre de zone a traiter= %d\n",nidom);

  E_Float** iptro; E_Float** iptmut; E_Float** iptromoy;
  E_Float** ipti;  E_Float** iptj;  E_Float** iptk; E_Float** iptvol;
  E_Float** ipti_df; E_Float** iptj_df;  E_Float** iptk_df ; E_Float** iptvol_df;
  E_Float** iptventi; E_Float** iptventj; E_Float** iptventk;
  E_Float** iptx; E_Float** ipty; E_Float** iptz;

  E_Float** ipt_param_real; 

  E_Int** ipt_param_int;

  ipt_param_real    = new  E_Float*[nidom*18];
  iptro             = ipt_param_real + nidom;
  iptmut            = iptro          + nidom;
  ipti              = iptmut         + nidom;
  iptj              = ipti           + nidom;
  iptk              = iptj           + nidom;
  iptvol            = iptk           + nidom;
  ipti_df           = iptvol         + nidom;
  iptj_df           = ipti_df        + nidom;
  iptk_df           = iptj_df        + nidom;
  iptvol_df         = iptk_df        + nidom;
  iptromoy          = iptvol_df      + nidom;
  iptventi          = iptromoy       + nidom;
  iptventj          = iptventi       + nidom;
  iptventk          = iptventj       + nidom;
  iptx              = iptventk       + nidom; 
  ipty              = iptx           + nidom;
  iptz              = ipty           + nidom;
 
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

    //
    //
    //Pointeur maillage
    //
    //
    if(ipt_param_int[nd][ LALE ]== 0){ GET_XYZ( "GridCoordinates"     , zone, iptx[nd], ipty[nd], iptz[nd])}
    else                             { GET_XYZ( "GridCoordinates#Init", zone, iptx[nd], ipty[nd], iptz[nd])}


    PyObject* sol_center;
    sol_center   = K_PYTREE::getNodeFromName1(zone      , "FlowSolution#Centers");
    t            = K_PYTREE::getNodeFromName1(sol_center, "Density");
    iptro[nd]    = K_PYTREE::getValueAF(t, hook);

    if(ipt_param_int[nd][ IFLOW ] > 1)
      { t  = K_PYTREE::getNodeFromName1(sol_center, "ViscosityEddy");
        if (t == NULL) { PyErr_SetString(PyExc_ValueError, "viscosity is missing for NS computation."); return NULL; }
        else           { iptmut[nd]   = K_PYTREE::getValueAF(t, hook);}
      }
    else {iptmut[nd] = iptro[nd];}


    // Check metrics
    PyObject* metric = PyList_GetItem(metrics, nd); // metric du domaine i

    GET_TI(   METRIC_TI  , metric, ipt_param_int[nd], ipti [nd]  , iptj [nd]  , iptk [nd]  , iptvol[nd]    )
    GET_TI(   METRIC_TIDF, metric, ipt_param_int[nd], ipti_df[nd], iptj_df[nd], iptk_df[nd], iptvol_df[nd] )

    GET_VENT( METRIC_VENT, metric, ipt_param_int[nd], iptventi[nd], iptventj[nd], iptventk[nd] )

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

      //printf("ntask %d %d \n", nbtask, 9 + nssiter +nitcfg-1);

      for (E_Int ntask = 0; ntask < nbtask; ntask++)
        {
           E_Int pttask = ptiter + ntask*(6+Nbre_thread_actif*7);
           E_Int nd = ipt_omp[ pttask ];

           E_Int* ipt_ind_dm_loc         = ipt_ind_dm         + (ithread-1)*6;
           ipt_ind_dm_loc[0] = 1;
           ipt_ind_dm_loc[2] = 1;
           ipt_ind_dm_loc[4] = 1;
           ipt_ind_dm_loc[1] = ipt_param_int[nd][ IJKV];
           ipt_ind_dm_loc[3] = ipt_param_int[nd][ IJKV+1];
           ipt_ind_dm_loc[5] = ipt_param_int[nd][ IJKV+2];

           E_Int* ipt_topology_socket    = ipt_topology       + (ithread-1)*3; 
           E_Int* ipt_ijkv_sdm_thread    = ipt_ijkv_sdm       + (ithread-1)*3; 
           E_Int* ipt_ind_dm_socket      = ipt_ind_dm_omp     + (ithread-1)*12;

           // Distribution de la sous-zone sur les threads
           E_Int lmin =10;
	   if (ipt_param_int[nd][ITYPCP] == 2) lmin = 4;

           E_Int* ipt_topo_omp; E_Int* ipt_inddm_omp;
           E_Int ithread_loc           = ipt_omp[ pttask + 2 + ithread -1 ] +1 ;
           //E_Int nd_subzone            = ipt_omp[ pttask + 1 ];
           E_Int Nbre_thread_actif_loc = ipt_omp[ pttask + 2 + Nbre_thread_actif ];
           ipt_topo_omp                = ipt_omp + pttask + 3 + Nbre_thread_actif ;
           ipt_inddm_omp               = ipt_omp + pttask + 6 + Nbre_thread_actif + (ithread_loc-1)*6;

           if (ithread_loc == -1) { continue;}

           indice_boucle_lu_(nd, socket , Nbre_socket, lmin,
                             ipt_ind_dm_loc, 
                             ipt_topology_socket, ipt_ind_dm_socket );


           E_Int* ipt_lok_thread   = ipt_lok   + ntask*mx_synchro*Nbre_thread_actif;

           init_ventijk_( nd, nidom,  Nbre_thread_actif_loc, ithread_loc, Nbre_socket, socket, mx_synchro,
                          ipt_param_int[nd], ipt_param_real[nd],
                          ipt_ijkv_sdm_thread,
                          ipt_ind_dm_loc, ipt_ind_dm_socket,
                          ipt_topology_socket, ipt_lok_thread , ipt_topo_omp, ipt_inddm_omp,
                          ipti[nd]    , iptj[nd]    , iptk[nd]    , iptvol[nd]  ,
                          ipti_df[nd] , iptj_df[nd] , iptk_df[nd] ,
                          iptventi[nd], iptventj[nd], iptventk[nd], iptx[nd], ipty[nd], iptz[nd] );

          }// boucle zone 
# include "FastC/HPC_LAYER/INIT_LOCK.h"
  }  // zone OMP


  delete [] ipt_param_real;
  delete [] ipt_param_int;

  RELEASESHAREDN( lokArray    , lok  );
  RELEASEHOOK(hook)

  Py_INCREF(Py_None);
  return Py_None;
}

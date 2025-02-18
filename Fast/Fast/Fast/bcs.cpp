   E_Int* ipt_ind_dm_thread; 

   E_Int nbtask = ipt_omp[nitcfg-1]; 
   E_Int ptiter = ipt_omp[nssiter+ nitcfg-1];

   for (E_Int ntask = 0; ntask < nbtask; ntask++)
     {
       E_Int pttask = ptiter + ntask*(6+Nbre_thread_actif*7);
       E_Int nd = ipt_omp[ pttask ];

       E_Int* ipt_inddm_omp;

       ithread_loc           = ipt_omp[ pttask + 2 + ithread -1 ] +1 ;
       E_Int nd_subzone      = ipt_omp[ pttask + 1 ];
       Nbre_thread_actif_loc = ipt_omp[ pttask + 2 + Nbre_thread_actif ];
       ipt_inddm_omp         = ipt_omp + pttask + 2 + Nbre_thread_actif +4 + (ithread_loc-1)*6;

       if (ithread_loc == -1) {continue;}

       E_Int* ipt_nidom_loc = ipt_ind_dm[nd] + param_int[nd][ MXSSDOM_LU ]*6*nssiter + nssiter;   //nidom_loc(nssiter)
       E_Int  nb_subzone    = ipt_nidom_loc [nitcfg-1];                                           //nbre sous-zone a la sousiter courante

       E_Int* ipt_ind_CL_thread      = ipt_ind_CL         + (ithread-1)*6;
       E_Int* ipt_ind_CL119          = ipt_ind_CL         + (ithread-1)*6 +  6*Nbre_thread_actif;
       E_Int* ipt_ind_CLgmres        = ipt_ind_CL         + (ithread-1)*6 + 12*Nbre_thread_actif;
       E_Int* ipt_shift_lu           = ipt_ind_CL         + (ithread-1)*6 + 18*Nbre_thread_actif;

       E_Int* ipt_ind_dm_loc  = ipt_ind_dm[nd]  + (nitcfg-1)*6*param_int[nd][ MXSSDOM_LU ] + 6*nd_subzone;

       if (autorisation_bc[nd] == 1)
	    {

               if(param_int[nd][IFLOW] != 4)
                    {
	              E_Int ierr = K_FASTS::BCzone(nd, lrhs , nitcfg_stk, lcorner, param_int[nd], param_real[nd], npass,
		                                  ipt_ind_dm_loc, ipt_inddm_omp, 
				                  ipt_ind_CL_thread, ipt_ind_CL119,  ipt_ind_CLgmres, ipt_shift_lu,
				                  iptro_CL[nd] , ipti[nd]            , iptj[nd]    , iptk[nd]       ,
				                  iptx[nd]     , ipty[nd]            , iptz[nd]    ,
		                                  iptventi[nd] , iptventj[nd]        , iptventk[nd], iptro_CL[nd], iptmut[nd]);

	              correct_coins_(nd,  param_int[nd], ipt_inddm_omp , iptro_CL[nd]);
                    }
                   else
                    {
                      E_Float* iptventi =NULL; E_Float* iptventj =NULL; E_Float* iptventk =NULL;

                      //E_Int ierr = K_FASTASLBM::BCzone(nd, lrhs , nitcfg_stk, lcorner, param_int[nd], param_real[nd], npass,
		              // 	                    ipt_ind_dm_loc, ipt_inddm_omp, 
		      	      //                      ipt_ind_CL_thread, ipt_ind_CL119,  ipt_ind_CLgmres, ipt_shift_lu,
                      //                              iptrotmp[nd] , iptrom_CL[nd], iptroS_CL[nd], iptpsiG_CL[nd], 
                      //                              //iptro_CL[nd] , iptrom_CL[nd], iptroS_CL[nd], iptpsiG_CL[nd], 
                      //                              ipti[nd]     , iptj[nd]    , iptk[nd],
                      //                              iptx[nd]     , ipty[nd]    , iptz[nd],
                      //                              iptventi     , iptventj    , iptventk);
                    }
	    }//autorisation


       //Reinitialisation verrou omp
        E_Int l =  ntask*mx_synchro*Nbre_thread_actif  + (ithread_loc-1)*mx_synchro;
        for (E_Int i = 0;  i < mx_synchro ; i++) { ipt_lok[ l + i ]  = 0; }

        E_Int type = 4;
       ////Init verrou rhs pour chaque sous zone et chaque thread actif:  init val to zero
        E_Int* verrou_lhs_thread = verrou_lhs +  ntask*Nbre_thread_actif + ithread_loc -1; 
        verrou_c_( verrou_lhs_thread, type);

       //Reinitialisation verrou omp pour calcul residu avant lhs
        verrou_lhs_thread        = verrou_lhs + (nbtask + ntask)*Nbre_thread_actif + ithread_loc -1; 
        verrou_c_( verrou_lhs_thread, type );

     }//loop zone

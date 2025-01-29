c***********************************************************************
c     $Date: 2010-11-04 13:25:50 +0100 (Thu, 04 Nov 2010) $
c     $Revision: 64 $
c     $Author: IvanMary $
c***********************************************************************
      subroutine navier_stokes_struct( ndo, Nbre_thread_actif,
     &        ithread, ithread_io, 
     &        omp_mode, layer_mode, Nbre_socket, socket, mx_synchro, 
     &        lssiter_verif, lexit_lu,
     &        nptpsi, nitcfg, nssiter, nitrun, first_it,
     &        nb_pulse, flagCellN,
     &        param_int, param_real,
     &        temps,
     &        ijkv_sdm,
     &        ind_dm_zone, ind_dm_socket, ind_dm_omp,
     &        socket_topology, lok , topo_s, timer_omp,
     &        krylov, norm_kry,
     &        cfl,
     &        x , y , z, cellN, cellN_IBC,
     &        rop , rop_m1     , rop_tmp , rop_ssiter,
     &        xmut  ,
     &        ti, tj, tk, vol,  ti_df, tj_df, tk_df, vol_df,
     &        venti , ventj , ventk ,
     &        wig , stat_wig, rot,
     &        drodm , coe, delta, ro_res, ro_src)

c***********************************************************************
c_U   USER : TERRACOL
c     ACT
c
c_A    Appel du calcul des flux explicites
c
c     VAL
c_V    gaz parfait monoespece
c_V    processeur domaine
c_V    steady/unsteady
c
c     INP
c_I    tijk     : vecteur normale aux facettes des mailles
c_I    vent     : vitesses d entrainement aux facettes preced.
c
c     LOC
c_L    flu      : flux convectifs dans une direction de maillage
c
c     I/O
c_/    drodm    : increment de la solution
c
c***********************************************************************
!     !Notes on index ranges::
!     ! Array of 6    :: imin imax jmin jmax kmin kmax
!     ! ind_dm_zone   :: whole domain (mpi domain) (e.g. imin = 1 imax= Nx_mpi)
!     !
!     ! ind_sdm       :: interior point for sub domain (1 to Nx, with Nx = number of cells in the sub zone)
!     !
!     ! IMPORTANT NOTE::THE SIZE NX IS DEPENDENT ON EITHER CACHE SUB ZONE OR THE FULL SUB ZONE (check if its cache blocking or not)
!     !                                                                                         i.e. Nx can be Nx_cache or Nx_thread
!     ! ind_coe     :: single threaded w/o cache blocking    :: -1 to Nx+2  
!     !                single threaded w/  cache blocking    :: depends on cache sub domain number (see below)
!     !                Multi threaded but w/o cache blocking :: -1 to Nx-2
!     !                Multi threaded but w/  cache blocking :: depends on cache sub domain number (see below)
!     ! ind_grad    :: single threaded w/o cache blocking    :: 0 to Nx+1
!     !                single threaded w/  cache blocking    :: depends on cache sub domain number (see below)
!     !                Multi threaded but w/o cache blocking :: 0 to Nx-1
!     !                Multi threaded but w/  cache blocking :: depends on cache sub domain number (see below)

!     ! Diagram for assuming multi threaded w/ cache blocking but only showing for one thread
!     !          §  cache1   §  cache2   § cache3    § cache4    § cache5    §
!     !      |_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|
!     !      + * |           ^ * +       ^ * +       ^ * +       ^ * +   + * |
!     !      + * |  coe1     ^ * +  coe2 ^ * +  coe3 ^ * +  coe4 ^ * +co5+ * |
!     !        * |   grad1   ^ *    grad2^ *    grad3^ *    grad4^ * grad5 * |
!     !          ^   sdm1    ^      sdm2 ^      sdm3 ^      sdm4 ^   sdm5    ^
!     !Thread N-1|                 Thread N                                  |Thread  N+1
!     ! Note: + is the sub zone boundary for coe
!     !       * is the sub zone boundary for grad
!     !       ^ is the sub zone boundary for sdm
!     !       | is the sub zone boundary for the thread zone (interior cells)
!     !       § is the sub zone boundary for the cache zone (interior cells)
!     ! Note: if the thread and/or cache touches the right most domain (assuming 1D in x-axis) ind_coe will go up to nx+2 and ind_grad will go up to nx+1
!     !
      implicit none
#include "FastS/param_solver.h"

      INTEGER_E ndo, Nbre_thread_actif , mx_synchro, first_it,
     & ithread, ithread_io, Nbre_socket, socket, nitrun, nptpsi, nitcfg,
     & nb_pulse,lexit_lu,
     & lssiter_verif,flagCellN,omp_mode,layer_mode,nssiter
c
      INTEGER_E  ijkv_sdm(3),ind_dm_zone(6), topo_s(3),
     & ind_dm_omp(6), ind_dm_socket(6), socket_topology(3),
     & param_int(0:*), lok(*), cycl, visco_type, ierr

      REAL_E rop(*),rop_m1(*),rop_tmp(*),rop_ssiter(*),xmut(*),drodm(*),
     & coe(*), ti(*),tj(*),tk(*),vol(*),x(*),y(*),z(*),
     & venti(*),ventj(*),ventk(*), wig(*),stat_wig(*), rot(*), celln(*),
     & ti_df(*),tj_df(*),tk_df(*),vol_df(*), krylov(*), cellN_IBC(*), 
     & ro_src(*),timer_omp(*)

      REAL_E delta(*),ro_res(*)

      REAL_E psi(nptpsi)

      REAL_E temps, norm_kry, cfl(3), param_real(0:*)
c      REAL_E drodmstk(20000,param_int(NEQ)), rostk(20000,param_int(NEQ))

C Var loc
#include "FastC/HPC_LAYER/LOC_VAR_DECLARATION.for"

      INTEGER_E ind_loop(6),neq_rot,depth,nb_bc,thmax,th,shift1,shift2,
     & flag_wait,cells, it_dtloc, flag_NSLBM,lcomput,shift_vol,
     & shift_vol_n,shift_vol_m


      REAL_E rhs_begin,rhs_end

!     !Note
!     ! Q^(n+1) = Q^n + Dt/vol * Sum_Nface(F_euler - F_viscous)*n +  S
!     !           (iii) (ii)     |_____(iv)_____________________|  (iii)
!     ! (i)   Laminar & Turbulent viscosity
!     ! (ii)  Timestep/vol computation
!     ! (iii) RHS init & source term S (Q^n + S)
!     ! (iv)  euler and viscous fluxes computation and balance
!     ! (v)   solve/solution udpate
      
#include "FastS/formule_param.h"
#include "FastS/formule_mtr_param.h"


      include 'omp_lib.h'

#ifdef _OPENMP
      rhs_begin = omp_get_wtime()
#else
      rhs_begin = 0.
#endif
       shift_vol   = param_int(PT_VOL)*param_int(NDIMDX_MTR)
       if(param_int(LALE).eq.3) then
         shift_vol_n = param_int(PT_VOL)-1
         if (shift_vol_n.lt.0) shift_vol_n = 2
         shift_vol_m = shift_vol_n-1
         if (shift_vol_m.lt.0) shift_vol_m = 2
         shift_vol_n   = shift_vol_n*param_int(NDIMDX_MTR)
         shift_vol_m   = shift_vol_m*param_int(NDIMDX_MTR)
       endif
       
#include "FastC/HPC_LAYER/SIZE_MIN.for"
#include "FastC/HPC_LAYER/WORK_DISTRIBUTION_BEGIN.for"
#include "FastC/HPC_LAYER/LOOP_CACHE_BEGIN.for"
#include "FastC/HPC_LAYER/INDICE_RANGE.for"


          flag_wait = 0

c         if(ithread_io.eq.24.and.nitcfg.le.1.and.icache.eq.1
c     &    .and.jcache.eq.1) then
c         if(ithread.eq.param_int( IO_THREAD).and.nitcfg.le.1) then
c           write(*,'(a,7i6)')'ijkv_sdm  =',ijkv_sdm,icache,jcache,
c     &                                     kcache,ithread
c           write(*,'(a,9i6)')'ind_dm_zone=',ind_dm_zone,
c     &    ithread,jbloc,ndo
c           write(*,'(a,3i6)')'topo=',topo_omp
c           write(*,'(a,3i6)')'loop_patern=',shift
c           write(*,'(a,6i6)')'ind_dm_soc=',ind_dm_socket
c           write(*,'(a,6i6)')'inddm_omp =',inddm_omp
c           write(*,'(a,6i6)')'ind_dm_thr=',ind_dm_omp
c           write(*,'(a,6i6)')'ind_sdm   =',ind_sdm
c           write(*,'(a,6i6)')'ind_ssa   =',ind_ssa
c           write(*,'(a,6i6)')'ind_coe   =',ind_coe
c           write(*,'(a,6i6)')'ind_grad  =',ind_grad
c           write(*,'(a,6i6)')'ind_rhs   =',ind_rhs
c           write(*,'(a,6i6)')'ind_mjr   =',ind_mjr
c         endif


c      if(ndo.eq.-9) then
c         thmax = OMP_get_num_threads()
c         th = OMP_get_thread_num()+1

c         do i = 1, thmax
c            if (i == th) then
c        write(*,'(a,7i5)')'ind_dm  =',ind_dm_omp(1:4),th,icache,jcache
c            write(*,'(a,4i5)')'ind_sdm =',ind_sdm(1:4)
c            write(*,'(a,4i5)')'ind_coe =',ind_coe(1:4)
c            write(*,'(a,4i5)')'ind_ssa =',ind_ssa(1:4)
c            write(*,'(a,4i5)')'ind_gra =',ind_grad(1:4)
c            endif
c!$OMP BARRIER
c         enddo 
c       endif

          
          !!! variable pour l'explicit local !!!!
          !!! utilisee pour savoir si on est a la premiere ss-ite des zones !!!
          cycl=param_int(NSSITER)/param_int(LEVEL) 
          lcomput=0
          if(param_int(EXPLOC).eq.0.and.nitcfg.eq.1) lcomput=1
          if(param_int(EXPLOC).ne.0.and.mod(nitcfg,cycl).eq.1) lcomput=1

!         STEP I & II : Laminar/turbulent viscosity (i) & Timestep/vol computation (ii)   
          IF (lcomput.eq.1) then !!! calcul donnee specifique premiere sous iteration

              if(param_int(LALE).eq.1) then ! mise a jour Vent et tijk si mvt corps solide
                call mjr_ale(ndo,nitcfg, ithread,
     &                        param_int, param_real,
     &                        ind_dm_zone, ind_sdm, ijkv_sdm,
     &                        synchro_send_th, synchro_receive_th,
     &                        icache, jcache, kcache,
     &                        x,y,z,ti,ti_df,tj,tj_df,tk,tk_df,vol,
     &                        venti, ventj, ventk)
              endif

              !Calcul de la viscosite laminaire si nslaminar ou (nsles + dom 2D)
              if(param_int(IFLOW).eq.2) then
                 
                 if(param_int(ILES).eq.0.or.param_int(NIJK+4).eq.0) then
                
                   if(param_int(ITYPCP).le.1) then 
                     visco_type = 0
                     call invist(ndo, param_int, param_real, ind_coe,
     &                           rop_ssiter, xmut )
                   else 
                     visco_type = 1
                     call invist(ndo, param_int, param_real, ind_grad,
     &                           rop_ssiter, xmut )
                   endif
                 !LES selective mixed scale model
                 else
                   neq_rot    = 3
                   depth      = 1 !pour extrapolation mut, on travaille sur 1 seule rangee
                   visco_type = 1
                   call lesvist(ndo, param_int,param_real,neq_rot,depth,
     &                  ithread, nitrun,
     &                  ind_grad, ind_coe, ind_dm_zone,
     &                  xmut, rop_ssiter, ti,tj,tk, vol, rot)
                 endif

              elseif(param_int(IFLOW).eq.3) then

                 visco_type = 0
                 !! remplissage tableau xmut si SA uniquememnt. 
                 !! Pour ZDES, remplissage dans terme source 
                 !call vispalart(ndo, param_int, param_real, ind_grad,
                 call vispalart(ndo, param_int, param_real, ind_coe,
     &                         xmut,rop_ssiter)
              endif
              !Calcul hyperviscosite zone eponge
              if(param_int(LBM_SPONGE).eq.1.and.param_int(IFLOW).ne.1) then
                 shift2=1
                 if(param_int(SA_DIST).eq.1) shift2=shift2+1 !!distance paroi
                 if(param_int(SA_INT + SA_IDES-1).ge.6) shift2=shift2+1 !!zgris var

                 !write(*,*)"shift2", shift2, ndo
                 shift2=shift2*param_int(NDIMDX)
                   if(visco_type.eq.0) then 
                      call visco_sponge(ndo, param_int, ind_coe,
     &                            xmut, xmut(1 + shift2) )
                   else 
                      call visco_sponge(ndo, param_int, ind_grad,
     &                            xmut, xmut(1 + shift2) )
                   endif
              endif

              !!sinon cfl foireux
              IF(param_int(IFLOW).eq.3.and.param_int(ITYPCP).le.1) then
#include       "FastC/HPC_LAYER/SYNCHRO_WAIT.for"
                flag_wait = 1
              ENDIF
              ! Calcul du pas de temps
              call cptst3(ndo, nitcfg, nitrun, first_it, lssiter_verif,
     &                    flagCellN, param_int, param_real,
     &                    ind_sdm, ind_grad, ind_coe,
     &                    cfl, xmut,rop_ssiter, ro_src, cellN, coe,
     &                    ti,tj,tk, vol(1+shift_vol),venti)

          ENDIF !! fin test 1ere sous-ite de la zone

           
          !SI SA implicit, verrou ici car dependence entre coe(5)
          !calculee sur ind_coe dans cptst3 et coe(6) calculee sur
          !ind_ssa dans src_term
          ! pareil pour ibc0
          IF( (    (param_int(IFLOW).eq.3.and.param_int(ITYPCP).le.1)
     &          .or.param_int(IBC).eq.1
     &         )
     &                             .and.flag_wait.eq.0) then
#include "FastC/HPC_LAYER/SYNCHRO_WAIT.for"
               flag_wait = 1
          ENDIF
!         STEP I & II: END


!         STEP III: RHS init + source term S
          ! - Ajout d'un eventuel terme source au second membre
          ! - initialisation drodm
          call src_term(ndo, ithread, nitcfg, nb_pulse,
     &                  param_int, param_real,
     &                  ind_sdm, ind_rhs, ind_ssa, ind_grad,
     &                  temps, nitrun, cycl,
     &                  rop_ssiter, xmut, drodm, coe, x,y,z,cellN_IBC,
     &                  ti,tj,tk,vol(1+shift_vol), 
     &                  delta, ro_src, wig, rop, rop_m1)

          IF(flag_wait.eq.0) then
#include "FastC/HPC_LAYER/SYNCHRO_WAIT.for"
          ENDIF
!         STEP III: END

!         STEP IV: euler and viscous fluxes computation and balance
          ! -----assemblage drodm euler+visqueux
          if(param_int(KFLUDOM).eq.1) then

                call fluausm_select(ndo,nitcfg, ithread,nptpsi,
     &                        param_int, param_real,
     &                        ind_dm_zone, ind_sdm, ijkv_sdm,
     &                        synchro_send_th, synchro_receive_th,
     &                        icache, jcache, kcache,
     &                        psi,wig,stat_wig, rop_ssiter, drodm,
     &                        ti,ti_df,tj,tj_df,tk,tk_df,
     &                        vol(1+shift_vol),vol_df,
     &                        venti, ventj, ventk, xmut)

          elseif(param_int(KFLUDOM).eq.2) then
   
                call flusenseur_select(ndo,nitcfg,ithread, nptpsi,
     &                        param_int, param_real,
     &                        ind_dm_zone, ind_sdm, ijkv_sdm,
     &                        synchro_send_th, synchro_receive_th,
     &                        icache, jcache, kcache,
     &                        psi,wig,stat_wig, rop_ssiter, drodm,
     &                        ti,ti_df,tj,tj_df,tk,tk_df,
     &                        vol(1+shift_vol),vol_df,
     &                        venti, ventj, ventk, xmut)

          elseif(param_int(KFLUDOM).eq.5) then

                call fluroe_select(ndo,nitcfg,ithread, nptpsi,
     &                        param_int, param_real,
     &                        ind_dm_zone, ind_sdm, ijkv_sdm,
     &                        synchro_send_th, synchro_receive_th,
     &                        icache, jcache, kcache,
     &                        psi,wig,stat_wig, rop_ssiter, drodm,
     &                        ti,ti_df,tj,tj_df,tk,tk_df,
     &                        vol(1+shift_vol),vol_df,
     &                        venti, ventj, ventk, xmut)

          else
                 if(ithread.eq.1) then
                   write(*,*)'Unknown flux',param_int(KFLUDOM)
                 endif
          endif

#include "FastC/HPC_LAYER/SYNCHRO_GO.for"

          !correction flux pour paroi (Roe), wallmodel et raccord
          !conservatif nearmatch
          call correct_flux(ndo,ithread, param_int, param_real,
     &                  ind_dm_zone, ind_sdm, nitcfg, nitrun, cycl,
     &                  psi,wig,stat_wig, rop_ssiter, drodm,x,y,z,
     &                  ti,ti_df,tj,tj_df,tk,tk_df,
     &                  vol(1+shift_vol),vol_df,
     &                  venti, ventj, ventk, xmut)
!         STEP IV: END

!         STEP V: SOLUTION UPDATE           
          !Extraction tableau residu
          if(param_int(EXTRACT_RES).eq.1) then
              call extract_res(ndo, param_int, param_real,
     &                         ind_mjr,
     &                         drodm, vol(1+shift_vol), wig, ro_res)
          endif
 
          !! implicit krylov             
          if(param_int(ITYPCP).le.1.and.
     &        (param_int(IMPLICITSOLVER).eq.1.and.layer_mode.ge.1)) then
              !Assemble Residu Newton; 3q(n+1)-4Q(n)+q(n-1)) + dt (flu(i+1)-(flu(i)) =0
              if(flagCellN.eq.0) then
               call core3as2_kry(ndo,nitcfg, first_it,
     &                           param_int,param_real,
     &                           ind_mjr,
     &                           krylov, norm_kry,
     &                           rop_ssiter, rop, rop_m1, drodm, coe)
               else
               call core3as2_chim_kry(ndo,nitcfg, first_it, 
     &                                param_int,param_real,
     &                                ind_mjr, cellN,
     &                                krylov, norm_kry,
     &                                rop_ssiter, rop, rop_m1,drodm,coe)
               endif


           !! implicit Lu                 
          elseif(param_int(ITYPCP).le.1) then

              !!maillage indeformable
              if(param_int(LALE).lt.3) then
                 !Assemble Residu Newton; 3q(n+1)-4Q(n)+q(n-1)) + dt (flu(i+1)-(flu(i)) =0
                 if(flagCellN.eq.0) then
                   call core3as2(ndo,nitcfg, first_it, 
     &                           param_int,param_real, ind_mjr,
     &                           rop_ssiter, rop, rop_m1, drodm, coe)
                 else
                   call core3as2_chim(ndo,nitcfg, first_it, 
     &                            param_int, param_real, ind_mjr, cellN,
     &                            rop_ssiter,rop, rop_m1, drodm, coe)
                 endif
              else
                 if(flagCellN.eq.0) then
                   call core3as2_def(ndo,nitcfg, first_it, 
     &                             param_int,param_real, ind_mjr,
     &                             vol(1+shift_vol), vol(1+shift_vol_n),
     &                             vol(1+shift_vol_m),
     &                             rop_ssiter, rop, rop_m1, drodm, coe)

                 else
                   call core3as2_chim_def(ndo,nitcfg, first_it, 
     &                            param_int, param_real, ind_mjr, cellN,
     &                            vol(1+shift_vol), vol(1+shift_vol_n),
     &                            vol(1+shift_vol_m),
     &                            rop_ssiter,rop, rop_m1, drodm, coe)

                 endif
              endif

             !Extraction tableau residu
             if( param_int(EXTRACT_RES).eq.2.and.
     &           (nitcfg.eq.1.or.nitcfg.eq.nssiter) ) then

              
                shift2=1
                if(param_int(SA_DIST).eq.1) shift2=shift2+1             !!distance paroi: adresse a revoir si loi de paroi laminaire 
                if(param_int(SA_INT + SA_IDES-1).ge.6) shift2=shift2+1  !!zgris var
                if(param_int(LBM_SPONGE).eq.1) shift2=shift2+1          !!viscosityEddy correction
                !if(param_int(ILES).ge.1) shift2=shift2+1               !!sgsCorrection

                if(nitcfg.eq.1)  then
                   shift1 = param_int(NDIMDX)*shift2
                else
                   shift1 = param_int(NDIMDX)*(param_int(NEQ)+shift2)
                endif

                call extract_res(ndo, param_int, param_real,
     &                           ind_mjr,
     &                           drodm, vol(1+shift_vol),
     &                           wig, xmut(1+shift1) )
             endif
          !! explicit Lu                 
          else
             !c--------------------------------------------------
             !calcul param_int( IO_THREAD)uveau champ en explicite rk3
             !c-----Mise a jour de iptdrodm0 et de la solution
             !c     iptrotmp(nitcfg+1)=iptrotmp(nitcfg)+CoefW *drodm (rk3)
             !c--------------------------------------------------
              if (param_int(EXPLOC)==0) then ! Explicit global

                 if(mod(nitcfg,2)==1) then
                     call core3ark3(ndo,nitcfg, param_int, param_real,
     &                      ind_mjr, rop_tmp, rop, drodm, coe)
                 else
                     call core3ark3(ndo,nitcfg, param_int, param_real,
     &                      ind_mjr, rop, rop_tmp, drodm, coe)
                 end if
    
             else if(param_int(EXPLOC)==1) then ! Explicit local instationnaire

                 if (MOD(nitcfg,2)==0) then
                     call core3_dtloc(ndo,nitcfg, param_int, param_real,
     &                      ind_mjr, rop, rop_tmp, drodm, coe)
                 else
                     call core3_dtloc(ndo,nitcfg, param_int, param_real,
     &                      ind_mjr, rop_tmp, rop, drodm, coe)
                 endif
              endif

          end if

#include "FastC/HPC_LAYER/LOOP_CACHE_END.for"
CCC#include "FastC/HPC_LAYER/WORK_DISTRIBUTION_END.for"


           !!! omp barriere
      if(lexit_lu.eq.0.and.nitrun*nitcfg.gt.15
     &         .and.(nitcfg.lt.3.or.nitcfg.eq.nssiter-1)) then
#ifdef _OPENMP
         rhs_end = omp_get_wtime()
#else
         rhs_end = 0.
#endif
        cells = (ind_dm_omp(2)-ind_dm_omp(1)+1)
     &         *(ind_dm_omp(4)-ind_dm_omp(3)+1)
     &         *(ind_dm_omp(6)-ind_dm_omp(5)+1)

        timer_omp(1)=timer_omp(1)+(rhs_end-rhs_begin)/float(cells)
        timer_omp(2)=float(cells)
      endif


      end

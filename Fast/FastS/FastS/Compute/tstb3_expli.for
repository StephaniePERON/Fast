c***********************************************************************
c     $Date: 2014-03-19 20:08:08 +0100 (mer. 19 mars 2014) $
c     $Revision: 59 $
c     $Author: IvanMary $
c***********************************************************************
      subroutine tstb3_expli(ndom, first_it,param_int,param_real,
     &                       ind_loop,
     &                       rop, coe, xmut, venti, cellN,
     &                       ti, tj, tk, vol)
c***********************************************************************
c_U   USER : PECHIER
c
c     ACT
c_A    Calcul du pas de temps par noeud en gaz parfait.
c
c     VAL
c_V       Valide pour calcul Euler/NS/NSturb 
c
c     OUT
c_O    coe(:,11)   : tableau des pas de temps = dtc /vol(ijk)
c***********************************************************************
      implicit none

#include "FastS/param_solver.h"

      INTEGER_E ndom,first_it, param_int(0:*), ind_loop(6)

      REAL_E  xmut( param_int(NDIMDX) )
      REAL_E cellN( param_int(NDIMDX) )
      REAL_E   rop( param_int(NDIMDX) , param_int(NEQ) )
      REAL_E   coe( param_int(NDIMDX) , param_int(NEQ_COE) )

      REAL_E ti( param_int(NDIMDX_MTR) , param_int(NEQ_IJ) ),
     &       tj( param_int(NDIMDX_MTR) , param_int(NEQ_IJ) ),
     &       tk( param_int(NDIMDX_MTR) , param_int(NEQ_K ) ),
     &      vol( param_int(NDIMDX_MTR) ) 

      REAL_E venti( param_int(NDIMDX_VENT) * param_int(NEQ_VENT) )

      REAL_E  param_real(0:*)
C Var loc
      INTEGER_E  inci_mtr,incj_mtr,inck_mtr,li,lj,lk,l,i,j,k,lij,
     &   lt, ltij,lvij,lv,v2ven,v3ven,inci_ven, lvo, lx, lxij
      REAL_E tcxi,tcyi,tczi,tc2i,tcxj,tcyj,tczj,tc2j,tcxk,tcyk,tczk,
     & tc2k,vmu,volu,xmvis,r,u,v,w,c,qni,vmi,cni,qnj,cnj,vmj,qnk,
     & cnk,vmk,ue,ve,we,gam1,gam2,detj, gamma, prandt,Cut0x,rgp,
     & gam1_1,d, dt,dtvis,dtconv, sp,ck_vent

#include "FastS/formule_xyz_param.h"
#include "FastS/formule_mtr_param.h"
#include "FastS/formule_vent_param.h"
#include "FastS/formule_param.h" 

      Cut0x = 1e-30

      inci_mtr = param_int(NIJK_MTR)
      incj_mtr = param_int(NIJK_MTR+1)
      inck_mtr = param_int(NIJK_MTR+2)

      gamma  = param_real(STAREF)
      rgp    = param_real(STAREF+1)*(gamma-1.)  !Cv(gama-1)= R (gas parfait)
      prandt = param_real(VISCO +1)

      !gam1   = 2.*gamma/prandt
      gam1   = gamma/prandt
      if(param_int(IFLOW).eq.1) gam1   = Cut0x
      gam1_1 = 1./gam1


      gam2 =  gamma*rgp

       IF(param_int(LALE).eq.0) THEN !(pas de maillage mobile)



         if(param_int(ITYPZONE).eq.0) then !domaine 3d general

#include   "FastC/HPC_LAYER/loop_begin.for"
               li = lt + inci_mtr
               lj = lt + incj_mtr
               lk = lt + inck_mtr

#ifndef E_SCALAR_COMPUTER
               r   = max(rop(l ,1),cut0x)
               detj= max(vol(lvo),cut0x)
#else
               r   = rop(l ,1)
               detj= max(vol(lvo),cut0x)
#endif
               u=rop(l,2)
               v=rop(l,3)
               w=rop(l,4)
               c=sqrt(gam2*rop(l,5))

               !Face I
               tc2i = .5 *( sqrt(  ti(lt,1)*ti(lt,1)
     &                           + ti(lt,2)*ti(lt,2)
     &                           + ti(lt,3)*ti(lt,3) ) 
     &                     +sqrt(  ti(li,1)*ti(li,1)
     &                           + ti(li,2)*ti(li,2)
     &                           + ti(li,3)*ti(li,3)) )
               !Face J
               tc2j = .5 *( sqrt(  tj(lt,1)*tj(lt,1)
     &                           + tj(lt,2)*tj(lt,2)
     &                           + tj(lt,3)*tj(lt,3) )
     &                     +sqrt(  tj(lj,1)*tj(lj,1)
     &                           + tj(lj,2)*tj(lj,2)
     &                           + tj(lj,3)*tj(lj,3) )  )
               !Face K
               tc2k = .5 *( sqrt(  tk(lt,1)*tk(lt,1)
     &                           + tk(lt,2)*tk(lt,2)
     &                           + tk(lt,3)*tk(lt,3) )
     &                     +sqrt(  tk(lk,1)*tk(lk,1)
     &                           + tk(lk,2)*tk(lk,2)
     &                           + tk(lk,3)*tk(lk,3) )  )
#include       "FastS/Compute/dtloc.for"

#include   "FastC/HPC_LAYER/loop_end.for"



         elseif(param_int(ITYPZONE).eq.1) then !maillage 3d k homogene:

#include   "FastC/HPC_LAYER/loop_begin.for"
               li = lt + inci_mtr
               lj = lt + incj_mtr
               lk = lt + inck_mtr

#ifndef E_SCALAR_COMPUTER
               r   = max(rop(l ,1),cut0x)
               detj= max(vol(lvo),cut0x)
#else
               r   = rop(l ,1)
               detj= max(vol(lvo),cut0x)
               !detj= vol(l)
#endif
               u=rop(l,2)
               v=rop(l,3)
               w=rop(l,4)
               c=sqrt(gam2*rop(l,5))

               !Face I
               tc2i = .5 *( sqrt(  ti(lt,1)*ti(lt,1)
     &                           + ti(lt,2)*ti(lt,2))
     &                     +sqrt(  ti(li,1)*ti(li,1)
     &                           + ti(li,2)*ti(li,2)) )
               !Face J
               tc2j = .5 *( sqrt(  tj(lt,1)*tj(lt,1)
     &                           + tj(lt,2)*tj(lt,2))
     &                     +sqrt(  tj(lj,1)*tj(lj,1)
     &                           + tj(lj,2)*tj(lj,2)) )
               !Face K
               tc2k = sqrt(  tk(lt,1)*tk(lt,1))

#include       "FastS/Compute/dtloc.for"

#include   "FastC/HPC_LAYER/loop_end.for"


         elseif(param_int(ITYPZONE).eq.2) then !maillage 3d cartesien:

           lt   = indmtr( 1 , 1, 1)
           lvo  = lt

           tcxi = ti(lt,1)
           tcyj = tj(lt,1)
           tczk = tk(lt,1)
           tc2i = sqrt( tcxi*tcxi )
           tc2j = sqrt( tcyj*tcyj )
           tc2k = sqrt( tczk*tczk )
           detj = max(vol(lvo),cut0x)
 
#include   "FastC/HPC_LAYER/loop_begin.for"

#ifndef E_SCALAR_COMPUTER
               r   = max(rop(l ,1),cut0x)
#else
               r   = rop(l ,1)
#endif
               u=rop(l,2)
               v=rop(l,3)
               w=rop(l,4)
               c=sqrt(gam2*rop(l,5))

#include       "FastS/Compute/dtloc.for"
               
#include   "FastC/HPC_LAYER/loop_end.for"


         else !maillage fixe, 2d

#include   "FastC/HPC_LAYER/loop_begin.for"
               li = lt + inci_mtr
               lj = lt + incj_mtr

#ifndef E_SCALAR_COMPUTER
               r   = max(rop(l ,1),cut0x)
               detj= max(vol(lvo),cut0x)
#else
               r   = rop(l ,1)
               detj= max(vol(lvo),cut0x)
#endif
               u=rop(l,2)
               v=rop(l,3)
               c=sqrt(gam2*rop(l,5))

               !Face I
               tc2i = .5 *( sqrt(  ti(lt,1)*ti(lt,1)
     &                           + ti(lt,2)*ti(lt,2))
     &                     +sqrt(  ti(li,1)*ti(li,1)
     &                           + ti(li,2)*ti(li,2)) )
               !Face J
               tc2j = .5 *( sqrt(  tj(lt,1)*tj(lt,1)
     &                           + tj(lt,2)*tj(lt,2))
     &                     +sqrt(  tj(lj,1)*tj(lj,1)
     &                           + tj(lj,2)*tj(lj,2)) )
               tc2k = 0.
               w    = 0.
#include       "FastS/Compute/dtloc.for"
               
#include   "FastC/HPC_LAYER/loop_end.for"

       endif !maillage fixe, 2d ou 3d ou 3d homogene

      ELSE !maillage mobile


         inci_ven = param_int(NIJK_VENT)

         if(param_int(NEQ_VENT).eq.2) then
            ck_vent =0.
         else
            ck_vent =1.
         endif
         v2ven =   param_int(NDIMDX_VENT)
         v3ven = 2*param_int(NDIMDX_VENT)*ck_vent

         if(param_int(ITYPZONE).eq.0) then !domaine 3d general

#include   "FastC/HPC_LAYER/loop_ale_begin.for"
               li = lt + inci_mtr
               lj = lt + incj_mtr
               lk = lt + inck_mtr

               !-Vitesse entrainement moyenne au centre de la cellule (maillage indeformable)
               ue=.5*(venti(lv      )+venti(lv+inci_ven      ))
               ve=.5*(venti(lv+v2ven)+venti(lv+inci_ven+v2ven))
               we=.5*(venti(lv+v3ven)+venti(lv+inci_ven+v3ven))*ck_vent
               u =rop(l,2)-ue
               v =rop(l,3)-ve
               w =rop(l,4)-we

#ifndef E_SCALAR_COMPUTER
               r   = max(rop(l ,1),cut0x)
               detj= max(vol(lvo),cut0x)
#else
               r   = rop(l ,1)
               detj= max(vol(lvo),cut0x)
#endif
               c  = sqrt(gam2*rop(l,5)) 

               !Face I
               tc2i = .5 *( sqrt(  ti(lt,1)*ti(lt,1)
     &                           + ti(lt,2)*ti(lt,2)
     &                           + ti(lt,3)*ti(lt,3) ) 
     &                     +sqrt(  ti(li,1)*ti(li,1)
     &                           + ti(li,2)*ti(li,2)
     &                           + ti(li,3)*ti(li,3)) )
               !Face J
               tc2j = .5 *( sqrt(  tj(lt,1)*tj(lt,1)
     &                           + tj(lt,2)*tj(lt,2)
     &                           + tj(lt,3)*tj(lt,3) )
     &                     +sqrt(  tj(lj,1)*tj(lj,1)
     &                           + tj(lj,2)*tj(lj,2)
     &                           + tj(lj,3)*tj(lj,3) )  )
               !Face K
               tc2k = .5 *( sqrt(  tk(lt,1)*tk(lt,1)
     &                           + tk(lt,2)*tk(lt,2)
     &                           + tk(lt,3)*tk(lt,3) )
     &                     +sqrt(  tk(lk,1)*tk(lk,1)
     &                           + tk(lk,2)*tk(lk,2)
     &                           + tk(lk,3)*tk(lk,3) )  )
#include       "FastS/Compute/dtloc.for"
               
#include   "FastC/HPC_LAYER/loop_end.for"

         elseif(param_int(ITYPZONE).eq.1) then !maillage 3d k homogene:

#include   "FastC/HPC_LAYER/loop_ale_begin.for"
               li = lt + inci_mtr
               lj = lt + incj_mtr
               lk = lt + inck_mtr

               !-Vitesse entrainement moyenne au centre de la cellule (maillage indeformable)
               ue=.5*(venti(lv      )+venti(lv+inci_ven      ))
               ve=.5*(venti(lv+v2ven)+venti(lv+inci_ven+v2ven))
               we=0.
               u =rop(l,2)-ue
               v =rop(l,3)-ve
               w =rop(l,4)-we

#ifndef E_SCALAR_COMPUTER
               r   = max(rop(l ,1),cut0x)
               detj= max(vol(lvo),cut0x)
#else
               r   = rop(l ,1)
               detj= max(vol(lvo),cut0x)
#endif
               c  = sqrt(gam2*rop(l,5)) 

               !Face I
               tc2i = .5 *( sqrt(  ti(lt,1)*ti(lt,1)
     &                           + ti(lt,2)*ti(lt,2))
     &                     +sqrt(  ti(li,1)*ti(li,1)
     &                           + ti(li,2)*ti(li,2)) )
               !Face J
               tc2j = .5 *( sqrt(  tj(lt,1)*tj(lt,1)
     &                           + tj(lt,2)*tj(lt,2))
     &                     +sqrt(  tj(lj,1)*tj(lj,1)
     &                           + tj(lj,2)*tj(lj,2)) )
               !Face K
               tc2k = sqrt(  tk(lt,1)*tk(lt,1))
#include       "FastS/Compute/dtloc.for"
              
#include   "FastC/HPC_LAYER/loop_end.for"

         elseif(param_int(ITYPZONE).eq.2) then !maillage 3d cartesien:

           lt   = indmtr( 1 , 1, 1)
           lvo  = lt

           tcxi = ti(lt,1)
           tcyj = tj(lt,1)
           tczk = tk(lt,1)
           tc2i = sqrt( tcxi*tcxi )
           tc2j = sqrt( tcyj*tcyj )
           tc2k = sqrt( tczk*tczk )
           detj = max(vol(lvo),cut0x)
 
#include   "FastC/HPC_LAYER/loop3dcart_ale_begin.for"

               !-Vitesse entrainement moyenne au centre de la cellule (maillage indeformable)
               ue=.5*(venti(lv      )+venti(lv+inci_ven      ))
               ve=.5*(venti(lv+v2ven)+venti(lv+inci_ven+v2ven))
               we=.5*(venti(lv+v3ven)+venti(lv+inci_ven+v3ven))*ck_vent

               u=rop(l,2)-ue
               v=rop(l,3)-ve
               w=rop(l,4)-we

#ifndef E_SCALAR_COMPUTER
               r   = max(rop(l ,1),cut0x)
#else
               r   = rop(l ,1)
#endif
               c=sqrt(gam2*rop(l,5))
 
#include       "FastS/Compute/dtloc.for"

#include   "FastC/HPC_LAYER/loop_end.for"

         else !maillage mobile, 2d


#include   "FastC/HPC_LAYER/loop_ale_begin.for"
               li = lt + inci_mtr
               lj = lt + incj_mtr

               !-Vitesse entrainement moyenne au centre de la cellule 
               ue=.5*(venti(lv      )+venti(lv+inci_ven      ))
               ve=.5*(venti(lv+v2ven)+venti(lv+inci_ven+v2ven))
               u =rop(l,2)-ue
               v =rop(l,3)-ve
#ifndef E_SCALAR_COMPUTER
               r   = max(rop(l ,1),cut0x)
               detj= max(vol(lvo),cut0x)
#else
               r   = rop(l ,1)
               detj= max(vol(lvo),cut0x)
#endif
               c=sqrt(gam2*rop(l,5))

               !Face I
               tc2i = .5 *( sqrt(  ti(lt,1)*ti(lt,1)
     &                           + ti(lt,2)*ti(lt,2))
     &                     +sqrt(  ti(li,1)*ti(li,1)
     &                           + ti(li,2)*ti(li,2)) )
               !Face J
               tc2j = .5 *( sqrt(  tj(lt,1)*tj(lt,1)
     &                           + tj(lt,2)*tj(lt,2))
     &                     +sqrt(  tj(lj,1)*tj(lj,1)
     &                           + tj(lj,2)*tj(lj,2)) )
               tc2k = 0.
               w    = 0.
#include       "FastS/Compute/dtloc.for"
               
#include   "FastC/HPC_LAYER/loop_end.for"
 
       endif!2d/3d/3d homogene
 
      endif!maillage fixe/mobile

      end

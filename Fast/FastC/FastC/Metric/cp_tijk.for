c    ***********************************************************************
c     $Date: 2010-06-14 09:57:46 +0200 (Mon, 14 Jun 2010) $
c     $Revision: 60 $
c     $Author: IvanMary $
c***********************************************************************
      subroutine cp_tijk( param_int,
     &                    x, y, z, ti, tj, tk, ti0, tj0, tk0,
     &                    ind_loop_glob )
c***********************************************************************
c_P                          O N E R A
c
c     ACT
c_A    calcul metrique: normale + surface + volume en volume finis
c
c     VAL
c
c     INP
C_I    neq_ij,neq_k : dimension metrique
c_/    x,y,z        : coordonnees du maillage
c
c     OUT
c     ti,tj,tk,ti0,tj0,tk0
c***********************************************************************
      implicit none

#include "FastC/param_solver.h"

      INTEGER_E ind_loop_glob(6),param_int(0:*) 

      REAL_E x(param_int( NDIMDX_XYZ )),y(param_int( NDIMDX_XYZ )),
     &       z(param_int( NDIMDX_XYZ ))    
C_OUT
      REAL_E  ti(param_int( NDIMDX_MTR ),param_int( NEQ_IJ )) 
      REAL_E ti0(param_int( NDIMDX_MTR ),param_int( NEQ_IJ )) 
      REAL_E  tj(param_int( NDIMDX_MTR ),param_int( NEQ_IJ )) 
      REAL_E tj0(param_int( NDIMDX_MTR ),param_int( NEQ_IJ )) 
      REAL_E  tk(param_int( NDIMDX_MTR ),param_int( NEQ_K  )) 
      REAL_E tk0(param_int( NDIMDX_MTR ),param_int( NEQ_K  )) 

c Var loc 
      logical li,lj,lk
      INTEGER_E k,j,i,l0,l1,l5,l4,l2,l3,l7,l6,incmax,
     & lip,ljp,lkp,l,inci,incj,inck,ne,i1,i2,j1,j2,k1,k2,npass,lmax,
     & iv,jv,kv, ind_loop(6), lij, lt, ltij, lxij, lx, lv, lvo, lvij

      REAL_E ax,ay,az,tk1,tk2,dz,
     & tix10,tix11,tiy10,tiy11,tiz10,tiz11,
     & tix20,tix21,tiy20,tiy21,tiz20,tiz21,
     & tjx10,tjx11,tjy10,tjy11,tjz10,tjz11,
     & tjx20,tjx21,tjy20,tjy21,tjz20,tjz21,
     & tkx10,tkx11,tky10,tky11,tkz10,tkz11,
     & tkx20,tkx21,tky20,tky21,tkz20,tkz21

#include "FastC/formule_param.h"
#include "FastC/formule_mtr_param.h"
#include "FastC/formule_vent_param.h"
#include "FastC/formule_xyz_param.h"

      inci = 1
      incj = param_int( NIJK_XYZ ) 
      inck = param_int( NIJK_XYZ ) *param_int( NIJK_XYZ +1 ) 

      iv = param_int( IJKV   )
      jv = param_int( IJKV +1)
      kv = param_int( IJKV +2)

      li   = .false.
      lj   = .false.
      lk   = .false.
      !correction sous domaine pour passer list gradient a liste interface
        if(ind_loop_glob(2).ge.iv+1) li   = .true.
        if(ind_loop_glob(4).ge.jv+1) lj   = .true.
        if(ind_loop_glob(6).ge.kv+1) lk   = .true.

c-----le nbr de metrique varie selon le type de domaine
      IF(param_int( ITYPZONE ).eq.0) THEN !Domaine 3D quelconque

         ind_loop(:)= ind_loop_glob(:)
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                   ! x(i  , j  , k  )
          l1= l0 + incj            ! x(i  , j+1, k  )
          l2= l0 + inck            ! x(i  , j  , k+1)
          l3= l1 + inck            ! x(i  , j+1, k+1)
          l4= l0 + inci            ! x(i+1, j  , k  )
          l5= l1 + inci            ! x(i+1, j+1, k  )
          l6= l2 + inci            ! x(i+1, j  , k+1)
          l7= l3 + inci            ! x(i+1, j+1, k+1)

          !!! Facette I: normal et surface
          tix10=(y(l1)-y(l0))*(z(l3)-z(l0))-(z(l1)-z(l0))*(y(l3)-y(l0))
          tiy10=(z(l1)-z(l0))*(x(l3)-x(l0))-(x(l1)-x(l0))*(z(l3)-z(l0))
          tiz10=(x(l1)-x(l0))*(y(l3)-y(l0))-(y(l1)-y(l0))*(x(l3)-x(l0))
          tix11=(y(l2)-y(l3))*(z(l0)-z(l2))-(z(l2)-z(l3))*(y(l0)-y(l2))
          tiy11=(z(l2)-z(l3))*(x(l0)-x(l2))-(x(l2)-x(l3))*(z(l0)-z(l2))
          tiz11=(x(l2)-x(l3))*(y(l0)-y(l2))-(y(l2)-y(l3))*(x(l0)-x(l2))

          ti(lt ,1) = .5*(tix10+tix11)  ! ti(i  ,j,k)=normal*surf
          ti(lt ,2) = .5*(tiy10+tiy11)
          ti(lt ,3) = .5*(tiz10+tiz11)
           
          !!! Facette J: normal et surface
          tjx10=(y(l0)-y(l4))*(z(l2)-z(l0))-(z(l0)-z(l4))*(y(l2)-y(l0))
          tjy10=(z(l0)-z(l4))*(x(l2)-x(l0))-(x(l0)-x(l4))*(z(l2)-z(l0))
          tjz10=(x(l0)-x(l4))*(y(l2)-y(l0))-(y(l0)-y(l4))*(x(l2)-x(l0)) 
          tjx11=(y(l6)-y(l2))*(z(l4)-z(l6))-(z(l6)-z(l2))*(y(l4)-y(l6))
          tjy11=(z(l6)-z(l2))*(x(l4)-x(l6))-(x(l6)-x(l2))*(z(l4)-z(l6))
          tjz11=(x(l6)-x(l2))*(y(l4)-y(l6))-(y(l6)-y(l2))*(x(l4)-x(l6))

          tj(lt ,1) = .5*(tjx10+tjx11)  ! tj(i  ,j   ,k  )=normal*surf
          tj(lt ,2) = .5*(tjy10+tjy11)
          tj(lt ,3) = .5*(tjz10+tjz11)

          !!! Facette K: normal et surface
          tkx10=(y(l4)-y(l0))*(z(l5)-z(l4))-(z(l4)-z(l0))*(y(l5)-y(l4))
          tky10=(z(l4)-z(l0))*(x(l5)-x(l4))-(x(l4)-x(l0))*(z(l5)-z(l4))
          tkz10=(x(l4)-x(l0))*(y(l5)-y(l4))-(y(l4)-y(l0))*(x(l5)-x(l4))
          tkx11=(y(l1)-y(l5))*(z(l0)-z(l1))-(z(l1)-z(l5))*(y(l0)-y(l1))
          tky11=(z(l1)-z(l5))*(x(l0)-x(l1))-(x(l1)-x(l5))*(z(l0)-z(l1))
          tkz11=(x(l1)-x(l5))*(y(l0)-y(l1))-(y(l1)-y(l5))*(x(l0)-x(l1))

          tk(lt ,1) = .5*(tkx10+tkx11)  ! tk(i  ,j ,k  )=normal*surf
          tk(lt ,2) = .5*(tky10+tky11)
          tk(lt ,3) = .5*(tkz10+tkz11)
#include "FastC/HPC_LAYER/loop_end.for"

        if(li) then !!! Facette I imax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(1)= ind_loop_glob(2)+1
         ind_loop(2)= ind_loop_glob(2)+1
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                      ! x(i  , j  , k  )
          l1= l0 + incj               ! x(i  , j+1, k  )
          l2= l0 + inck               ! x(i  , j  , k+1)
          l3= l1 + inck               ! x(i  , j+1, k+1)

          tix10=(y(l1)-y(l0))*(z(l3)-z(l0))-(z(l1)-z(l0))*(y(l3)-y(l0))
          tiy10=(z(l1)-z(l0))*(x(l3)-x(l0))-(x(l1)-x(l0))*(z(l3)-z(l0))
          tiz10=(x(l1)-x(l0))*(y(l3)-y(l0))-(y(l1)-y(l0))*(x(l3)-x(l0))
          tix11=(y(l2)-y(l3))*(z(l0)-z(l2))-(z(l2)-z(l3))*(y(l0)-y(l2))
          tiy11=(z(l2)-z(l3))*(x(l0)-x(l2))-(x(l2)-x(l3))*(z(l0)-z(l2))
          tiz11=(x(l2)-x(l3))*(y(l0)-y(l2))-(y(l2)-y(l3))*(x(l0)-x(l2))

          ti(lt ,1)= .5*(tix10+tix11)  ! ti(i  ,j,k)=normal*surf
          ti(lt ,2)= .5*(tiy10+tiy11)
          ti(lt ,3)= .5*(tiz10+tiz11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif

        if(lj) then !!! Facette J jmax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(3)= ind_loop_glob(4)+1
         ind_loop(4)= ind_loop_glob(4)+1
#include "FastC/HPC_LAYER/loop_ale_begin.for"

          l0= lx                  ! x(i  , j  , k  )
          l2= l0 + inck           ! x(i  , j  , k+1)
          l4= l0 + inci           ! x(i+1, j  , k  )
          l6= l2 + inci           ! x(i+1, j  , k+1)

          tjx10=(y(l0)-y(l4))*(z(l2)-z(l0))-(z(l0)-z(l4))*(y(l2)-y(l0))
          tjy10=(z(l0)-z(l4))*(x(l2)-x(l0))-(x(l0)-x(l4))*(z(l2)-z(l0))
          tjz10=(x(l0)-x(l4))*(y(l2)-y(l0))-(y(l0)-y(l4))*(x(l2)-x(l0)) 
          tjx11=(y(l6)-y(l2))*(z(l4)-z(l6))-(z(l6)-z(l2))*(y(l4)-y(l6))
          tjy11=(z(l6)-z(l2))*(x(l4)-x(l6))-(x(l6)-x(l2))*(z(l4)-z(l6))
          tjz11=(x(l6)-x(l2))*(y(l4)-y(l6))-(y(l6)-y(l2))*(x(l4)-x(l6))

          tj(lt ,1) = .5*(tjx10+tjx11)  ! tj(i  ,j   ,k  )=normal*surf
          tj(lt ,2) = .5*(tjy10+tjy11)
          tj(lt ,3) = .5*(tjz10+tjz11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif

        if(lk) then !!! Facette K kmax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(5)= ind_loop_glob(6)+1
         ind_loop(6)= ind_loop_glob(6)+1
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l1= l0 + incj             ! x(i  , j+1, k  )
          l4= l0 + inci             ! x(i+1, j  , k  )
          l5= l1 + inci             ! x(i+1, j+1, k  )

          tkx10=(y(l4)-y(l0))*(z(l5)-z(l4))-(z(l4)-z(l0))*(y(l5)-y(l4))
          tky10=(z(l4)-z(l0))*(x(l5)-x(l4))-(x(l4)-x(l0))*(z(l5)-z(l4))
          tkz10=(x(l4)-x(l0))*(y(l5)-y(l4))-(y(l4)-y(l0))*(x(l5)-x(l4))
          tkx11=(y(l1)-y(l5))*(z(l0)-z(l1))-(z(l1)-z(l5))*(y(l0)-y(l1))
          tky11=(z(l1)-z(l5))*(x(l0)-x(l1))-(x(l1)-x(l5))*(z(l0)-z(l1))
          tkz11=(x(l1)-x(l5))*(y(l0)-y(l1))-(y(l1)-y(l5))*(x(l0)-x(l1))

          tk(lt ,1) = .5*(tkx10+tkx11)  ! tk(i  ,j ,k  )=normal*surf
          tk(lt ,2) = .5*(tky10+tky11)
          tk(lt ,3) = .5*(tkz10+tkz11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif

      ELSEIF(param_int(ITYPZONE).eq.1) THEN !Domaine 3D avec une direction homogene k: traitement facette i et j

         ind_loop(:)= ind_loop_glob(:)
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l1= l0 + incj             ! x(i  , j+1, k  )
          l2= l0 + inck             ! x(i  , j  , k+1)
          l3= l1 + inck             ! x(i  , j+1, k+1)
          l4= l0 + inci             ! x(i+1, j  , k  )
          l5= l1 + inci             ! x(i+1, j+1, k  )
          l6= l2 + inci             ! x(i+1, j  , k+1)
          l7= l3 + inci             ! x(i+1, j+1, k+1)

          !!! Facette I: normal et surface
          tix10=(y(l1)-y(l0))*(z(l3)-z(l0))-(z(l1)-z(l0))*(y(l3)-y(l0))
          tiy10=(z(l1)-z(l0))*(x(l3)-x(l0))-(x(l1)-x(l0))*(z(l3)-z(l0))
          tix11=(y(l2)-y(l3))*(z(l0)-z(l2))-(z(l2)-z(l3))*(y(l0)-y(l2))
          tiy11=(z(l2)-z(l3))*(x(l0)-x(l2))-(x(l2)-x(l3))*(z(l0)-z(l2))

          ti(lt ,1) = .5*(tix10+tix11)  ! ti(i  ,j,k)=normal*surf
          ti(lt ,2) = .5*(tiy10+tiy11)

          !!! Facette J: normal et surface
          tjx10=(y(l0)-y(l4))*(z(l2)-z(l0))-(z(l0)-z(l4))*(y(l2)-y(l0))
          tjy10=(z(l0)-z(l4))*(x(l2)-x(l0))-(x(l0)-x(l4))*(z(l2)-z(l0))
          tjx11=(y(l6)-y(l2))*(z(l4)-z(l6))-(z(l6)-z(l2))*(y(l4)-y(l6))
          tjy11=(z(l6)-z(l2))*(x(l4)-x(l6))-(x(l6)-x(l2))*(z(l4)-z(l6))

          tj(lt ,1) = .5*(tjx10+tjx11)  ! tj(i  ,j   ,k  )=normal*surf
          tj(lt ,2) = .5*(tjy10+tjy11)

          !!! Facette K: normal et surface
          tkz10=(x(l4)-x(l0))*(y(l5)-y(l4))-(y(l4)-y(l0))*(x(l5)-x(l4))
          tkz11=(x(l1)-x(l5))*(y(l0)-y(l1))-(y(l1)-y(l5))*(x(l0)-x(l1))

          tk(lt ,1) = .5*(tkz10+tkz11)
#include "FastC/HPC_LAYER/loop_end.for"

        if(li) then !!! Facette I imax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(1)= ind_loop_glob(2)+1
         ind_loop(2)= ind_loop_glob(2)+1
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l1= l0 + incj             ! x(i  , j+1, k  )
          l2= l0 + inck             ! x(i  , j  , k+1)
          l3= l1 + inck             ! x(i  , j+1, k+1)

          tix10=(y(l1)-y(l0))*(z(l3)-z(l0))-(z(l1)-z(l0))*(y(l3)-y(l0))
          tiy10=(z(l1)-z(l0))*(x(l3)-x(l0))-(x(l1)-x(l0))*(z(l3)-z(l0))
          tix11=(y(l2)-y(l3))*(z(l0)-z(l2))-(z(l2)-z(l3))*(y(l0)-y(l2))
          tiy11=(z(l2)-z(l3))*(x(l0)-x(l2))-(x(l2)-x(l3))*(z(l0)-z(l2))

          ti(lt ,1)= .5*(tix10+tix11)  ! ti(i  ,j,k)=normal*surf
          ti(lt ,2)= .5*(tiy10+tiy11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif

        if(lj) then !!! Facette J jmax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(3)= ind_loop_glob(4)+1
         ind_loop(4)= ind_loop_glob(4)+1
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l2= l0 + inck             ! x(i  , j  , k+1)
          l4= l0 + inci             ! x(i+1, j  , k  )
          l6= l2 + inci             ! x(i+1, j  , k+1)

          tjx10=(y(l0)-y(l4))*(z(l2)-z(l0))-(z(l0)-z(l4))*(y(l2)-y(l0))
          tjy10=(z(l0)-z(l4))*(x(l2)-x(l0))-(x(l0)-x(l4))*(z(l2)-z(l0))
          tjx11=(y(l6)-y(l2))*(z(l4)-z(l6))-(z(l6)-z(l2))*(y(l4)-y(l6))
          tjy11=(z(l6)-z(l2))*(x(l4)-x(l6))-(x(l6)-x(l2))*(z(l4)-z(l6))

          tj(lt ,1) = .5*(tjx10+tjx11)  ! tj(i  ,j   ,k  )=normal*surf
          tj(lt ,2) = .5*(tjy10+tjy11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif

        if(lk) then !!! Facette K kmax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(5)= ind_loop_glob(6)+1
         ind_loop(6)= ind_loop_glob(6)+1
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l1= l0 + incj             ! x(i  , j+1, k  )
          l4= l0 + inci             ! x(i+1, j  , k  )
          l5= l1 + inci             ! x(i+1, j+1, k  )

          tkz10=(x(l4)-x(l0))*(y(l5)-y(l4))-(y(l4)-y(l0))*(x(l5)-x(l4))
          tkz11=(x(l1)-x(l5))*(y(l0)-y(l1))-(y(l1)-y(l5))*(x(l0)-x(l1))

          tk(lt ,1) = .5*(tkz10+tkz11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif

      ELSEIF(param_int(ITYPZONE).eq.2) THEN !Domaine 3D cartesien

         ind_loop(:)= ind_loop_glob(:)
#include "FastC/HPC_LAYER/loop3dcart_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )

          l1= l0 + incj             ! x(i  , j+1, k  )
          l2= l0 + inck             ! x(i  , j  , k+1)
          l3= l1 + inck             ! x(i  , j+1, k+1)
          l4= l0 + inci             ! x(i+1, j  , k  )
          l5= l1 + inci             ! x(i+1, j+1, k  )
          l6= l2 + inci             ! x(i+1, j  , k+1)
          l7= l3 + inci             ! x(i+1, j+1, k+1)

          !!! Facette I: normal et surface
          tix10=(y(l1)-y(l0))*(z(l3)-z(l0))-(z(l1)-z(l0))*(y(l3)-y(l0))
          tix11=(y(l2)-y(l3))*(z(l0)-z(l2))-(z(l2)-z(l3))*(y(l0)-y(l2))

          ti(lt ,1) = .5*(tix10+tix11)  ! ti(i  ,j,k)=normal*surf

          !!! Facette J: normal et surface
          tjy10=(z(l0)-z(l4))*(x(l2)-x(l0))-(x(l0)-x(l4))*(z(l2)-z(l0))
          tjy11=(z(l6)-z(l2))*(x(l4)-x(l6))-(x(l6)-x(l2))*(z(l4)-z(l6))

          tj(lt ,1) = .5*(tjy10+tjy11)

          !!! Facette K: normal et surface
          tkz10=(x(l4)-x(l0))*(y(l5)-y(l4))-(y(l4)-y(l0))*(x(l5)-x(l4))
          tkz11=(x(l1)-x(l5))*(y(l0)-y(l1))-(y(l1)-y(l5))*(x(l0)-x(l1))

          tk(lt ,1) = .5*(tkz10+tkz11)
#include "FastC/HPC_LAYER/loop_end.for"

        if(li) then !!! Facette I imax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(1)= ind_loop_glob(2)+1
         ind_loop(2)= ind_loop_glob(2)+1
#include "FastC/HPC_LAYER/loop3dcart_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l1= l0 + incj             ! x(i  , j+1, k  )
          l2= l0 + inck             ! x(i  , j  , k+1)
          l3= l1 + inck             ! x(i  , j+1, k+1)

          tix10=(y(l1)-y(l0))*(z(l3)-z(l0))-(z(l1)-z(l0))*(y(l3)-y(l0))
          tix11=(y(l2)-y(l3))*(z(l0)-z(l2))-(z(l2)-z(l3))*(y(l0)-y(l2))

          ti(lt ,1)= .5*(tix10+tix11)  ! ti(i  ,j,k)=normal*surf
#include "FastC/HPC_LAYER/loop_end.for"
        endif

        if(lj) then !!! Facette J jmax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(3)= ind_loop_glob(4)+1
         ind_loop(4)= ind_loop_glob(4)+1
#include "FastC/HPC_LAYER/loop3dcart_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l2= l0 + inck             ! x(i  , j  , k+1)
          l4= l0 + inci             ! x(i+1, j  , k  )
          l6= l2 + inci             ! x(i+1, j  , k+1)

          tjy10=(z(l0)-z(l4))*(x(l2)-x(l0))-(x(l0)-x(l4))*(z(l2)-z(l0))
          tjy11=(z(l6)-z(l2))*(x(l4)-x(l6))-(x(l6)-x(l2))*(z(l4)-z(l6))

          tj(lt ,1) = .5*(tjy10+tjy11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif

        if(lk) then !!! Facette K kmax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(5)= ind_loop_glob(6)+1
         ind_loop(6)= ind_loop_glob(6)+1
#include "FastC/HPC_LAYER/loop3dcart_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l1= l0 + incj             ! x(i  , j+1, k  )
          l4= l0 + inci             ! x(i+1, j  , k  )
          l5= l1 + inci             ! x(i+1, j+1, k  )

          tkz10=(x(l4)-x(l0))*(y(l5)-y(l4))-(y(l4)-y(l0))*(x(l5)-x(l4))
          tkz11=(x(l1)-x(l5))*(y(l0)-y(l1))-(y(l1)-y(l5))*(x(l0)-x(l1))

          tk(lt ,1) = .5*(tkz10+tkz11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif


      ELSE !Domaine 2D: neq_k=0

         ind_loop(:)= ind_loop_glob(:)
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l1= l0 + incj             ! x(i  , j+1, k  )
          l2= l0 + inck             ! x(i  , j  , k+1)
          l3= l1 + inck             ! x(i  , j+1, k+1)
          l4= l0 + inci             ! x(i+1, j  , k  )
          l5= l1 + inci             ! x(i+1, j+1, k  )
          l6= l2 + inci             ! x(i+1, j  , k+1)
          l7= l3 + inci             ! x(i+1, j+1, k+1)

          !!! Facette I: normal et surface
          tix10=(y(l1)-y(l0))*(z(l3)-z(l0))-(z(l1)-z(l0))*(y(l3)-y(l0))
          tiy10=(z(l1)-z(l0))*(x(l3)-x(l0))-(x(l1)-x(l0))*(z(l3)-z(l0))
          tix11=(y(l2)-y(l3))*(z(l0)-z(l2))-(z(l2)-z(l3))*(y(l0)-y(l2))
          tiy11=(z(l2)-z(l3))*(x(l0)-x(l2))-(x(l2)-x(l3))*(z(l0)-z(l2))

          ti(lt ,1) = .5*(tix10+tix11)  ! ti(i  ,j,k)=normal*surf
          ti(lt ,2) = .5*(tiy10+tiy11)

          !!! Facette J: normal et surface
          tjx10=(y(l0)-y(l4))*(z(l2)-z(l0))-(z(l0)-z(l4))*(y(l2)-y(l0))
          tjy10=(z(l0)-z(l4))*(x(l2)-x(l0))-(x(l0)-x(l4))*(z(l2)-z(l0))
          tjx11=(y(l6)-y(l2))*(z(l4)-z(l6))-(z(l6)-z(l2))*(y(l4)-y(l6))
          tjy11=(z(l6)-z(l2))*(x(l4)-x(l6))-(x(l6)-x(l2))*(z(l4)-z(l6))

          tj(lt ,1) = .5*(tjx10+tjx11)  ! tj(i  ,j   ,k  )=normal*surf
          tj(lt ,2) = .5*(tjy10+tjy11)
#include "FastC/HPC_LAYER/loop_end.for"

        if(li) then !!! Facette I imax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(1)= ind_loop_glob(2)+1
         ind_loop(2)= ind_loop_glob(2)+1
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l1= l0 + incj             ! x(i  , j+1, k  )
          l2= l0 + inck             ! x(i  , j  , k+1)
          l3= l1 + inck             ! x(i  , j+1, k+1)

          tix10=(y(l1)-y(l0))*(z(l3)-z(l0))-(z(l1)-z(l0))*(y(l3)-y(l0))
          tiy10=(z(l1)-z(l0))*(x(l3)-x(l0))-(x(l1)-x(l0))*(z(l3)-z(l0))
          tix11=(y(l2)-y(l3))*(z(l0)-z(l2))-(z(l2)-z(l3))*(y(l0)-y(l2))
          tiy11=(z(l2)-z(l3))*(x(l0)-x(l2))-(x(l2)-x(l3))*(z(l0)-z(l2))

          ti(lt ,1)= .5*(tix10+tix11)  ! ti(i  ,j,k)=normal*surf
          ti(lt ,2)= .5*(tiy10+tiy11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif

        if(lj) then !!! Facette J jmax: normal et surface
         ind_loop(:)= ind_loop_glob(:)
         ind_loop(3)= ind_loop_glob(4)+1
         ind_loop(4)= ind_loop_glob(4)+1
#include "FastC/HPC_LAYER/loop_ale_begin.for"
          l0= lx                    ! x(i  , j  , k  )
          l2= l0 + inck             ! x(i  , j  , k+1)
          l4= l0 + inci             ! x(i+1, j  , k  )
          l6= l2 + inci             ! x(i+1, j  , k+1)

          tjx10=(y(l0)-y(l4))*(z(l2)-z(l0))-(z(l0)-z(l4))*(y(l2)-y(l0))
          tjy10=(z(l0)-z(l4))*(x(l2)-x(l0))-(x(l0)-x(l4))*(z(l2)-z(l0))
          tjx11=(y(l6)-y(l2))*(z(l4)-z(l6))-(z(l6)-z(l2))*(y(l4)-y(l6))
          tjy11=(z(l6)-z(l2))*(x(l4)-x(l6))-(x(l6)-x(l2))*(z(l4)-z(l6))

          tj(lt ,1) = .5*(tjx10+tjx11)  ! tj(i  ,j   ,k  )=normal*surf
          tj(lt ,2) = .5*(tjy10+tjy11)
#include "FastC/HPC_LAYER/loop_end.for"
        endif

      ENDIF!neq_k

      !on sauvegarde les metriques de l'instant initial en ale
      If(param_int( LALE ).eq.1) THEN

       inck = 0 
       incj = 0 
       inci = 0 
       if(ind_loop_glob(6).ge.kv) inck = 1
       if(ind_loop_glob(4).ge.jv) incj = 1
       if(ind_loop_glob(2).ge.iv) inci = 1

       ind_loop(:)= ind_loop_glob(:)
       ind_loop(2)= ind_loop_glob(2)+inci
       ind_loop(4)= ind_loop_glob(4)+incj
       ind_loop(6)= ind_loop_glob(6)+inck

       if(param_int( ITYPZONE ).eq.0) then !Domaine 3D quelconque

#include "FastC/HPC_LAYER/loop_ale_begin.for"
             ti0(lt,1) = ti(lt,1)
             ti0(lt,2) = ti(lt,2)
             ti0(lt,3) = ti(lt,3)
 
             tj0(lt,1) = tj(lt,1)
             tj0(lt,2) = tj(lt,2)
             tj0(lt,3) = tj(lt,3)
 
             tk0(lt,1) = tk(lt,1)
             tk0(lt,2) = tk(lt,2)
             tk0(lt,3) = tk(lt,3)
#include "FastC/HPC_LAYER/loop_end.for"

       elseif(param_int( ITYPZONE ).eq.1) then !Domaine 3D dir k homogene

#include "FastC/HPC_LAYER/loop_ale_begin.for"
             ti0(lt,1) = ti(lt,1)
             ti0(lt,2) = ti(lt,2)

             tj0(lt,1) = tj(lt,1)
             tj0(lt,2) = tj(lt,2)

             tk0(lt,1) = tk(lt,1)
#include "FastC/HPC_LAYER/loop_end.for"

       elseif(param_int( ITYPZONE ).eq.2) then !Domaine 3D cartesien

#include "FastC/HPC_LAYER/loop_ale_begin.for"
             ti0(lt,1) = ti(lt,1)
             tj0(lt,1) = tj(lt,1)
             tk0(lt,1) = tk(lt,1)
#include "FastC/HPC_LAYER/loop_end.for"

       else !Domaine 2D

#include "FastC/HPC_LAYER/loop_ale_begin.for"
             ti0(lt,1) = ti(lt,1)
             ti0(lt,2) = ti(lt,2)

             tj0(lt,1) = tj(lt,1)
             tj0(lt,2) = tj(lt,2)
#include "FastC/HPC_LAYER/loop_end.for"

       endif  !neq_k

      ENDIF !ALE

      end

c***********************************************************************
c     $Date: 2010-06-14 09:57:46 +0200 (lun 14 jun 2010) $
c     $Revision: 58 $
c     $Author: IvanMary $
c***********************************************************************
      subroutine flush_real(isize,tab)
c***********************************************************************
c_P                          O N E R A
c=======================================================================
      implicit none

      INTEGER_E isize
      REAL_E tab(isize)

!$OMP FLUSH (tab)

      end
subroutine initmpigrid
use modmain
use mod_addons_q
implicit none
integer, allocatable :: d(:)
integer i1,i2,nd
!------------------------!
!     parallel grid      !
!------------------------!
if (task.eq.0.or.task.eq.1.or.task.eq.22..or.task.eq.20.or.task.eq.820.or.task.eq.822) then
  nd=2
  allocate(d(nd))
  d=1
  if (nproc.le.nkpt) then
    d(dim_k)=nproc
  else
    d(dim_k)=nkpt
    d(dim2)=nproc/nkpt
  endif    
else if (task.eq.800.or.task.eq.801.or.task.eq.802.or.task.eq.810.or.task.eq.809) then
  i2=nvq
  if (i2.eq.0) i2=nkptnr
  nd=3
  allocate(d(nd))
  d=1
  if (nproc.le.nkptnr) then
    d(dim_k)=nproc
  else  
    d(dim_k)=nkptnr
    i1=nproc/nkptnr
    if (i1.le.i2) then
      d(dim_q)=i1
    else
      d(dim_q)=i2
      d(dim_b)=nproc/(nkptnr*i2)
    endif
  endif
else
  nd=1
  allocate(d(nd))
  d=nproc
endif  
! overwrite default grid layout
if (lmpigrid) then
  d(1:nd)=mpigrid(1:nd) 
endif
call mpi_grid_initialize(d)
deallocate(d)
return
end
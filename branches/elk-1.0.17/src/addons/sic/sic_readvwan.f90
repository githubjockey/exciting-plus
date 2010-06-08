subroutine sic_readvwan
use modmain
use mod_lf
use mod_hdf5
implicit none
integer itloc,it,n,ispn
character*20 c1,c2,c3
character*100 path
logical exist

inquire(file="sic.hdf5",exist=exist)
if (.not.exist) return

call hdf5_read("sic.hdf5","/","nmegqwan",nmegqwan)
if (.not.allocated(imegqwan)) allocate(imegqwan(5,nmegqwan))
call hdf5_read("sic.hdf5","/","imegqwan",imegqwan(1,1),(/5,nmegqwan/))
allocate(vwan(nmegqwan))
allocate(hwan(nmegqwan))
call hdf5_read("sic.hdf5","/","vwan",vwan(1),(/nmegqwan/))
call hdf5_read("sic.hdf5","/","hwan",hwan(1),(/nmegqwan/))

call lf_init(lf_maxt,dim2)
allocate(vwanmt(lmmaxvr,nrmtmax,natmtot,ntrloc,nspinor,nwann))
allocate(vwanir(ngrtot,ntrloc,nspinor,nwann))
allocate(wanmt(lmmaxvr,nrmtmax,natmtot,ntrloc,nspinor,nwann))
allocate(wanir(ngrtot,ntrloc,nspinor,nwann))

if (mpi_grid_side(dims=(/dim_t/))) then
  do itloc=1,ntrloc
    it=mpi_grid_map(ntr,dim_t,loc=itloc)
    do ispn=1,nspinor
      do n=1,nwann
        write(c1,'("n",I4.4)')n
        write(c2,'("t",I4.4)')it
        write(c3,'("s",I4.4)')ispn 
        path="/wann/"//trim(adjustl(c1))//"/"//trim(adjustl(c3))//"/"//&
          trim(adjustl(c2))        
       call hdf5_read("sic.hdf5",path,"vwanmt",vwanmt(1,1,1,itloc,ispn,n),&
          (/lmmaxvr,nrmtmax,natmtot/))
        call hdf5_read("sic.hdf5",path,"vwanir",vwanir(1,itloc,ispn,n),&
          (/ngrtot/))
!       call hdf5_read("sic.hdf5",path,"wanmt",wanmt(1,1,1,itloc,ispn,n),&
!          (/lmmaxvr,nrmtmax,natmtot/))
!        call hdf5_read("sic.hdf5",path,"wanir",wanir(1,itloc,ispn,n),&
!          (/ngrtot/))
      enddo
    enddo
  enddo
endif
do itloc=1,ntrloc
  do ispn=1,nspinor
    do n=1,nwann
      call mpi_grid_bcast(vwanmt(1,1,1,itloc,ispn,n),lmmaxvr*nrmtmax*natmtot, &
        dims=(/dim_k/))
      call mpi_grid_bcast(vwanir(1,itloc,ispn,n),ngrtot,dims=(/dim_k/))
      call mpi_grid_bcast(wanmt(1,1,1,itloc,ispn,n),lmmaxvr*nrmtmax*natmtot, &
        dims=(/dim_k/))
      call mpi_grid_bcast(wanir(1,itloc,ispn,n),ngrtot,dims=(/dim_k/))
    enddo
  enddo
enddo
return
end
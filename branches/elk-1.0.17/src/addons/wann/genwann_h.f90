subroutine genwann_h(tdiag,evalsv_,wann_c_,wann_h_,wann_e_)
use modmain
use mod_mpi_grid
implicit none
logical, intent(in) :: tdiag
real(8), intent(in) :: evalsv_(nstsv)
complex(8), intent(in) :: wann_c_(nwann,nstsv)
complex(8), intent(out) :: wann_h_(nwann,nwann)
real(8), intent(out) :: wann_e_(nwann)
complex(8), allocatable :: zt2(:,:)
integer m1,m2,j
! compute H(k) 
allocate(zt2(nwann,nwann))
zt2=zzero
if (nwann_h.eq.0) then
  do m1=1,nwann
    do m2=1,nwann
      do j=1,nstsv
        zt2(m1,m2)=zt2(m1,m2)+dconjg(wann_c_(m1,j))*wann_c_(m2,j) * &
          evalsv_(j)
      enddo
    enddo
  enddo
else
  do m1=1,nwann_h
    do m2=1,nwann_h
      do j=1,nstsv
        zt2(m1,m2)=zt2(m1,m2)+dconjg(wann_c_(iwann_h(m1),j))*&
          wann_c_(iwann_h(m2),j)*evalsv_(j)
      enddo
    enddo
  enddo
  do m1=nwann_h+1,nwann
    zt2(m1,m1)=-100.d0*zone
  enddo
endif
wann_h_(:,:)=zt2(:,:)
if (tdiag) call diagzhe(nwann,zt2,wann_e_)
deallocate(zt2)
return
end

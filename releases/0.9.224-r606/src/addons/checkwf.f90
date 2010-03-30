subroutine checkwf
use modmain
implicit none

integer ik,ist1,ist2
integer ngknr
real(8) t1
complex(8) zt1
integer, allocatable :: igkignr(:)
real(8), allocatable :: vgklnr(:,:)
real(8), allocatable :: vgkcnr(:,:)
real(8), allocatable :: gkcnr(:)
real(8), allocatable :: tpgkcnr(:,:)
complex(8), allocatable :: sfacgknr(:,:)
complex(8), allocatable :: apwalm(:,:,:,:)
complex(8), allocatable :: evecfv(:,:)
complex(8), allocatable :: evecsv(:,:)
complex(8), allocatable :: wfmt(:,:,:,:,:)
complex(8), allocatable :: wfir(:,:,:)
complex(8), allocatable :: zrhomt(:,:,:)
complex(8), allocatable :: zrhoir(:)

complex(8), external :: zfint


call init0
call init1
call readstate
! generate the core wavefunctions and densities
call gencore
! find the new linearisation energies
call linengy
! generate the APW radial functions
call genapwfr
! generate the local-orbital radial functions
call genlofr

allocate(igkignr(ngkmax))
allocate(vgklnr(3,ngkmax))
allocate(vgkcnr(3,ngkmax))
allocate(gkcnr(ngkmax))
allocate(tpgkcnr(2,ngkmax))
allocate(apwalm(ngkmax,apwordmax,lmmaxapw,natmtot))
allocate(evecfv(nmatmax,nstfv))
allocate(evecsv(nstsv,nstsv))
allocate(sfacgknr(ngkmax,natmtot))
allocate(wfmt(lmmaxvr,nrcmtmax,natmtot,nspinor,nstsv))
allocate(wfir(ngrtot,nspinor,nstsv))
allocate(zrhomt(lmmaxvr,nrcmtmax,natmtot))
allocate(zrhoir(ngrtot))

open(60,file='NORM.OUT',form='FORMATTED',status='REPLACE')

do ik=1,nkptnr
! generate the G+k vectors
  call gengpvec(vklnr(:,ik),vkcnr(:,ik),ngknr,igkignr,vgklnr,vgkcnr,gkcnr, &
   tpgkcnr)
! get the eigenvectors from file for non-reduced k-point
  call getevecfv(vklnr(:,ik),vgklnr,evecfv)
  call getevecsv(vklnr(:,ik),evecsv)
! generate the structure factors
  call gensfacgp(ngknr,vgkcnr,ngkmax,sfacgknr)
! find the matching coefficients
  call match(ngknr,gkcnr,tpgkcnr,sfacgknr,apwalm)
! calculate the wavefunctions for all states
  call genwfsv(.false.,ngknr,igkignr,evalsv,apwalm,evecfv,evecsv,wfmt,wfir)
  
  write(61,'("ik : ",I4)')ik
  do ist1=1,nstsv
    write(61,'("  band : ",I4)')ist1
    do ist2=1,nstsv
      write(61,'("    j : ",I4,"   evecsv : ",2G18.10)')ist2,dreal(evecsv(ist2,ist1)),dimag(evecsv(ist2,ist1))
    enddo
  enddo
  
  if (spinpol.and..not.ncmag) then
    if (sum(abs(evecsv(1:nstfv,nstfv+1:nstsv))).gt.1d-10.or.&
        sum(abs(evecsv(nstfv+1:nstsv,1:nstfv))).gt.1d-10) then
      write(*,'("Error(checkwf) : wrong spinor for k-point ",I4)')ik
    endif
  endif
  
  if (.false.) then
  do ist1=1,nstsv
    do ist2=ist1,nstsv
      call vnlrho(.true.,wfmt(:,:,:,:,ist1),wfmt(:,:,:,:,ist2), &
        wfir(:,:,ist1),wfir(:,:,ist2),zrhomt,zrhoir)
      zt1=zfint(zrhomt,zrhoir)
      t1=0.d0
      if (ist1.eq.ist2) t1=1.d0
      t1=abs(zt1-t1)
      write(60,'("ik : ",I4,4x,"i,j : ",2I4,4x,"dev : ",F18.10)')ik,ist1,ist2,t1
      if (t1.gt.1d-1) then
        write(*,*)
        write(*,'("Warning(checkwf) : big deviation from norm")')
        write(60,'("ik : ",I4,4x,"i,j : ",2I4,4x,"dev : ",F18.10)')ik,ist1,ist2,t1
	write(*,*)
      endif
    end do
  end do
  endif
enddo
close(60)


return
end
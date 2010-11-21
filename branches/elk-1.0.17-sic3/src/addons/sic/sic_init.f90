subroutine sic_init
use modmain
use mod_sic
implicit none
integer i,ias,n,jas,i1,i2,i3,vl(3),ish,ir,is
logical l1,l2,exist
real(8) v1(3),v2(3)
logical, external :: vrinmt,sic_include_cell
real(8), allocatable :: wt1(:,:)

if (allocated(vtl)) deallocate(vtl)
allocate(vtl(3,maxvtl))
vtl=-1000000
ntr=0
l2=.true.
ish=0
do while (l2)
  l1=.false.
  do i1=-ish,ish
    do i2=-ish,ish
      do i3=-ish,ish
        if (abs(i1).eq.ish.or.abs(i2).eq.ish.or.abs(i3).eq.ish) then
          vl=(/i1,i2,i3/)
          if (sic_include_cell(vl)) then
            l1=.true.            
            ntr=ntr+1
            if (ntr.gt.maxvtl) then
              write(*,'("Error(sic_init) : maxvtl is too small")')
              call pstop
            endif
            vtl(:,ntr)=vl
          endif
        endif
      enddo
    enddo
  enddo !i1
  if (l1) then
    ish=ish+1
  else
    l2=.false.
  endif
enddo
tlim=0
do i=1,3
  tlim(1,i)=minval(vtl(i,1:ntr))
  tlim(2,i)=maxval(vtl(i,1:ntr))
enddo
if (allocated(ivtit)) deallocate(ivtit)
allocate(ivtit(tlim(1,1):tlim(2,1),tlim(1,2):tlim(2,2),tlim(1,3):tlim(2,3)))
ivtit=-1
do i=1,ntr
  ivtit(vtl(1,i),vtl(2,i),vtl(3,i))=i
enddo
if (allocated(vtc)) deallocate(vtc)
allocate(vtc(3,ntr))
do i=1,ntr
  vtc(:,i)=vtl(1,i)*avec(:,1)+vtl(2,i)*avec(:,2)+vtl(3,i)*avec(:,3)
end do

ngrloc=mpi_grid_map2(ngrtot,dims=(/dim_k,dim2/),offs=groffs)
nmtloc=mpi_grid_map2(nrmtmax*natmtot,dims=(/dim_k,dim2/),offs=mtoffs)

if (mpi_grid_root()) then
  write(*,*)
  write(*,'("[sic_init] total number of translations : ",I3)')ntr
  write(*,'("[sic_init] size of Wannier function arrays : ",I6," Mb")') &
    int(2*16.d0*(lmmaxvr*nmtloc+ngrloc)*ntr*nspinor*nwann/1048576.d0)
endif
call mpi_grid_barrier()
! main arrays of SIC code
!  wan(mt,ir) - Wannier function defined on a real-space grid
!  wv(mt,ir) - product of a Wannier function with it's potential
if (allocated(wanmt)) deallocate(wanmt)
allocate(wanmt(lmmaxvr,nmtloc,ntr,nspinor,nwann))
wanmt=zzero
if (allocated(wanir)) deallocate(wanir)
allocate(wanir(ngrloc,ntr,nspinor,nwann))
wanir=zzero
if (allocated(wvmt)) deallocate(wvmt)
allocate(wvmt(lmmaxvr,nmtloc,ntr,nspinor,nwann))
wvmt=zzero
if (allocated(wvir)) deallocate(wvir)  
allocate(wvir(ngrloc,ntr,nspinor,nwann))
wvir=zzero
if (allocated(sic_wann_e0)) deallocate(sic_wann_e0)
allocate(sic_wann_e0(nwann))
sic_wann_e0=0.d0
! TODO: skip reading the file with different WF set
inquire(file="SIC_WANN_E0.OUT",exist=exist)
if (exist) then
  open(170,file="SIC_WANN_E0.OUT",form="FORMATTED",status="OLD")
  do n=1,nwann
    read(170,*)sic_wann_e0(n)
  enddo
  close(170)
endif
if (allocated(sic_wb)) deallocate(sic_wb)
allocate(sic_wb(nwann,nstfv,nspinor,nkptloc))
if (allocated(sic_wvb)) deallocate(sic_wvb)
allocate(sic_wvb(nwann,nstfv,nspinor,nkptloc))
if (allocated(sic_wann_h0k)) deallocate(sic_wann_h0k)
allocate(sic_wann_h0k(nwann,nwann,nkptloc))
sic_wann_h0k=zzero
sic_etot_correction=0.d0
tevecsv=.true.
if (allocated(twanmt)) deallocate(twanmt)
allocate(twanmt(natmtot,ntr,nwann))
twanmt=.false.
if (allocated(twanmtuc)) deallocate(twanmtuc)
allocate(twanmtuc(ntr,nwann))
twanmtuc=.false.
do i=1,ntr
  v1(:)=vtl(1,i)*avec(:,1)+vtl(2,i)*avec(:,2)+vtl(3,i)*avec(:,3)
  do n=1,nwann
    jas=iwann(1,n)
    do ias=1,natmtot  
      v2(:)=atposc(:,ias2ia(ias),ias2is(ias))+v1(:)-&
        atposc(:,ias2ia(jas),ias2is(jas))
      if (sqrt(sum(v2(:)**2)).le.wann_r_cutoff) twanmt(ias,i,n)=.true.
    enddo
    twanmtuc(i,n)=any(twanmt(:,i,n))
  enddo
enddo
if (allocated(rmtwt)) deallocate(rmtwt)
allocate(rmtwt(nmtloc))
allocate(wt1(nrmtmax,natmtot))
wt1=0.d0
do ias=1,natmtot
  is=ias2is(ias)
  do ir=1,nrmt(is)-1
    wt1(ir,ias)=wt1(ir,ias)+&
      0.5d0*(spr(ir+1,is)-spr(ir,is))*spr(ir,is)**2
    wt1(ir+1,ias)=wt1(ir+1,ias)+&
      0.5d0*(spr(ir+1,is)-spr(ir,is))*spr(ir+1,is)**2
  enddo
enddo
call sic_copy_mt_d(.true.,1,wt1,rmtwt)
deallocate(wt1)
return
end

logical function sic_include_cell(vl)
use modmain
use mod_sic
implicit none
integer, intent(in) :: vl(3)
logical l1
integer n,ias,jas,ir
real(8) vt(3),v1(3)
vt(:)=vl(1)*avec(:,1)+vl(2)*avec(:,2)+vl(3)*avec(:,3)
l1=.false.
do n=1,nwann
  ias=iwann(1,n)
  do jas=1,natmtot
    v1(:)=atposc(:,ias2ia(jas),ias2is(jas))+vt(:)-&
      atposc(:,ias2ia(ias),ias2is(ias))
    if (sqrt(sum(v1(:)**2)).le.wann_r_cutoff) l1=.true.
  enddo
  do ir=1,ngrtot
    v1(:)=vgrc(:,ir)+vt(:)-atposc(:,ias2ia(ias),ias2is(ias))
    if (sqrt(sum(v1(:)**2)).le.wann_r_cutoff) l1=.true.
  enddo
enddo
sic_include_cell=l1
return
end
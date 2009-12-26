#ifdef _HDF5_
subroutine response
use modmain
use hdf5
implicit none

integer, allocatable :: ngknr(:)
integer, allocatable :: igkignr(:,:)
real(8), allocatable :: vgklnr(:,:,:)
real(8), allocatable :: vgkcnr(:,:,:)
real(8), allocatable :: gknr(:,:)
real(8), allocatable :: tpgknr(:,:,:)
complex(8), allocatable :: sfacgknr(:,:,:)

real(8), allocatable :: occsvnr(:,:)
real(8), allocatable :: evalsvnr(:,:)
complex(8), allocatable :: wfsvitloc(:,:,:,:)
complex(8), allocatable :: wfsvmtloc(:,:,:,:,:,:)
complex(8), allocatable :: apwalm(:,:,:,:)
complex(8), allocatable :: pmat(:,:,:,:)

integer i,j,n,ik,ikloc,istsv,ik1,isym,idx0,bs,ivq1,ivq2,iq
integer sz,iint,iw
integer i1,i2,i3
character*100 fname,qnm
character*3 c3
real(8) w2
logical lgamma,lpmat
!integer, external :: iknrglob2
!logical, external :: root_cart
!logical, external :: in_cart
logical, external :: wann_diel

! comment: after all new implementations (response in WF, cRPA,
!   band disentanglement) the code has become ugly and unreadable;
!   it should be refactored; new hdf5 and mpi_grid interfaces are
!   "a must"
!
! typical execution patterns
!  I) compute and save ME (task 400), read ME, compute and save chi0 (task 401),
!     read chi0 and compute chi (task 402)
!  II) 
!
! New task list:
!   400 - compute and write ME
!   401 - compute and write chi0
!   402 - compute and write chi
!   403 - compute ME, compute chi0, compute and write chi
!   404 - sum over all q to get screened U

if (lrtype.eq.1.and..not.spinpol) then
  write(*,*)
  write(*,'("Error(response): can''t do magnetic response for unpolarized ground state")')
  write(*,*)
  call pstop
endif
if (nvq0.eq.0) then
  write(*,*)
  write(*,'("Error(response): no q-vectors")')
  write(*,*)
  call pstop
endif
  
if (.not.wannier) then
  lwannresp=.false.
  lwannopt=.false.
  crpa=.false.
endif
lpmat=.false.
!if (lwannopt.or.crpa) lpmat=.true.
do j=1,nvq0
  if (ivq0m_list(1,j).eq.0.and.ivq0m_list(2,j).eq.0.and.ivq0m_list(3,j).eq.0) lpmat=.true.
enddo
! set the switch to write matrix elements
write_megq_file=.true.
if (task.eq.403) write_megq_file=.false.
! set the switch to compute screened matrices
screen_w_u=crpa

! this is enough for matrix elements
lmaxvr=4

! initialise universal variables
! MPI grid for tasks:
!   400 (matrix elements) : (1) k-points x (2) G-vectors or interband 
!                                           transitions x (3) q-points 
!   401 (chi0) : (1) k-points x (2) interband transition x (3) q-points 
!   402 (chi) : (1) energy mesh x (2) number of fxc kernels x (3) q-points
call init0
call init1

if (.not.mpi_grid_in()) return

! for constrained RPA all q-vectors in BZ are required 
lgamma=.false.
if (crpa.and..false.) then
  if (allocated(ivq0m_list)) deallocate(ivq0m_list)
  if (lgamma) then
    nvq0=nkptnr
  else
    nvq0=nkptnr-1 
  endif
  allocate(ivq0m_list(3,nvq0))
  j=0
  do i1=0,ngridk(1)-1
    do i2=0,ngridk(2)-1
      do i3=0,ngridk(3)-1
        if (.not.(i1.eq.0.and.i2.eq.0.and.i3.eq.0.and..not.lgamma)) then
          j=j+1
          ivq0m_list(:,j)=(/i1,i2,i3/)
        endif
      enddo
    enddo
  enddo
endif
if (crpa) then
  maxomega=0.d0
  domega=1.d0
endif
! necessary calls before generating Bloch wave-functions 
if (task.eq.400) then
! read the density and potentials from file
  call readstate
! find the new linearisation energies
  call linengy
! generate the APW radial functions
  call genapwfr
! generate the local-orbital radial functions
  call genlofr
  call geturf
  call genurfprod
! read Fermi energy
  if (mpi_grid_root()) call readfermi
  call mpi_grid_bcast(efermi)
endif
! create q-directories
if (mpi_grid_root()) then
  do iq=1,nvq0
    call qname(ivq0m_list(:,iq),qnm)
    call system("mkdir -p "//trim(qnm))
  enddo
endif
call mpi_grid_barrier()

wproc=.false.
if (mpi_grid_root()) then
  wproc=.true.
  if (task.eq.400) open(151,file='RESPONSE_ME.OUT',form='formatted',status='replace')
  if (task.eq.401) open(151,file='RESPONSE_CHI0.OUT',form='formatted',status='replace')
  if (task.eq.402) open(151,file='RESPONSE_CHI.OUT',form='formatted',status='replace')
  if (task.eq.403) open(151,file='RESPONSE_U.OUT',form='formatted',status='replace')
endif
if (wproc) then
  write(151,'("Running on ",I8," proc.")')nproc
#ifdef _PIO_
  if (nproc.gt.1) then
    write(151,'("Using parallel I/O")')
  endif
#endif
  write(151,'("MPI grid size : ",3I6)')mpi_grid_size
  write(151,'("Wannier functions : ",L1)')wannier
  write(151,'("Response in local basis  : ",L1)')lwannresp
  call flushifc(151)
endif

if (task.eq.400) then
! get energies of states in reduced part of BZ
  call timer_start(3,reset=.true.)
  if (wproc) then
    write(151,*)
    write(151,'("Reading energies of states")')
    call flushifc(151)
! read from IBZ
    do ik=1,nkpt
      call getevalsv(vkl(1,ik),evalsv(1,ik))
    enddo
  endif
  call mpi_grid_bcast(evalsv(1,1),nstsv*nkpt)
  allocate(evalsvnr(nstsv,nkptnr))
  evalsvnr=0.d0
  do ikloc=1,nkptnrloc
    ik=mpi_grid_map(nkptnr,dim_k,loc=ikloc)
    call findkpt(vklnr(1,ik),isym,ik1) 
    evalsvnr(:,ik)=evalsv(:,ik1)
  enddo
  call timer_stop(3)
  if (wproc) then
    write(151,'("Done in ",F8.2," seconds")')timer_get_value(3)
    call flushifc(151)
  endif
endif

if (task.eq.400) then
! generate G+k vectors for entire BZ (this is required to compute 
!   wave-functions at each k-point)
  allocate(vgklnr(3,ngkmax,nkptnrloc))
  allocate(vgkcnr(3,ngkmax,nkptnrloc))
  allocate(gknr(ngkmax,nkptnrloc))
  allocate(tpgknr(2,ngkmax,nkptnrloc))
  allocate(ngknr(nkptnrloc))
  allocate(sfacgknr(ngkmax,natmtot,nkptnrloc))
  allocate(igkignr(ngkmax,nkptnrloc))
  do ikloc=1,nkptnrloc
    ik=mpi_grid_map(nkptnr,dim_k,loc=ikloc)
    call gengpvec(vklnr(1,ik),vkcnr(1,ik),ngknr(ikloc),igkignr(1,ikloc), &
      vgklnr(1,1,ikloc),vgkcnr(1,1,ikloc),gknr(1,ikloc),tpgknr(1,1,ikloc))
    call gensfacgp(ngknr(ikloc),vgkcnr(1,1,ikloc),ngkmax,sfacgknr(1,1,ikloc))
  enddo
  allocate(wfsvmtloc(lmmaxvr,nrfmax,natmtot,nspinor,nstsv,nkptnrloc))
  allocate(wfsvitloc(ngkmax,nspinor,nstsv,nkptnrloc))
  allocate(evecfvloc(nmatmax,nstfv,nspnfv,nkptnrloc))
  allocate(evecsvloc(nstsv,nstsv,nkptnrloc))
  allocate(apwalm(ngkmax,apwordmax,lmmaxapw,natmtot))
  if (lpmat) then
    allocate(pmat(3,nstsv,nstsv,nkptnrloc))
  endif
  if (wproc) then
    sz=lmmaxvr*nrfmax*natmtot*nstsv*nspinor
    sz=sz+ngkmax*nstsv*nspinor
    sz=sz+nmatmax*nstfv*nspnfv
    sz=sz+nstsv*nstsv
    sz=16*sz*nkptnrloc/1024/1024
    write(151,*)
    write(151,'("Size of wave-function arrays (MB) : ",I6)')sz
    write(151,*)
    write(151,'("Reading eigen-vectors")')
    call flushifc(151)
  endif
  call timer_start(1,reset=.true.)
! read and transform eigen-vectors
  wfsvmtloc=zzero
  wfsvitloc=zzero
  if (mpi_grid_side(dims=(/dim_k/))) then
#ifndef _PIO_
    do i=0,mpi_grid_size(dim_k)-1
      if (i.eq.mpi_grid_x(dim_k)) then
#endif
        do ikloc=1,nkptnrloc
          ik=mpi_grid_map(nkptnr,dim_k,loc=ikloc)
          call getevecfv(vklnr(1,ik),vgklnr(1,1,ikloc),evecfvloc(1,1,1,ikloc))
          call getevecsv(vklnr(1,ik),evecsvloc(1,1,ikloc))
! get apw coeffs 
          call match(ngknr(ikloc),gknr(1,ikloc),tpgknr(1,1,ikloc),        &
            sfacgknr(1,1,ikloc),apwalm)
! generate wave functions in muffin-tins
          call genwfsvmt(lmaxvr,lmmaxvr,ngknr(ikloc),evecfvloc(1,1,1,ikloc), &
            evecsvloc(1,1,ikloc),apwalm,wfsvmtloc(1,1,1,1,1,ikloc))
! generate wave functions in interstitial
          call genwfsvit(ngknr(ikloc),evecfvloc(1,1,1,ikloc), &
            evecsvloc(1,1,ikloc),wfsvitloc(1,1,1,ikloc))
          if (lpmat) then
            call genpmat(ngknr(ikloc),igkignr(1,ikloc),vgkcnr(1,1,ikloc),&
              apwalm,evecfvloc(1,1,1,ikloc),evecsvloc(1,1,ikloc),pmat(1,1,1,ikloc))
          endif
        enddo !ikloc
#ifndef _PIO_
      endif
      call mpi_grid_barrier(dims=(/dim_k/))
    enddo
#endif
  endif !mpi_grid_side(dims=(/dim_k/)
  call mpi_grid_barrier
  call mpi_grid_bcast(wfsvmtloc(1,1,1,1,1,1),&
    lmmaxvr*nrfmax*natmtot*nspinor*nstsv*nkptnrloc,dims=(/dim2,dim3/))
  call mpi_grid_bcast(wfsvitloc(1,1,1,1),ngkmax*nspinor*nstsv*nkptnrloc,&
    dims=(/dim2,dim3/))
  call mpi_grid_bcast(evecfvloc(1,1,1,1),nmatmax*nstfv*nspnfv*nkptnrloc,&
    dims=(/dim2,dim3/))
  call mpi_grid_bcast(evecsvloc(1,1,1),nstsv*nstsv*nkptnrloc,&
    dims=(/dim2,dim3/))
  call timer_stop(1)
  if (wproc) then
    write(151,'("Done in ",F8.2," seconds")')timer_get_value(2)
    call flushifc(151)
  endif
! generate Wannier function expansion coefficients
  if (wannier) then
    call timer_start(1,reset=.true.)
    if (allocated(wann_c)) deallocate(wann_c)
    allocate(wann_c(nwann,nstsv,nkptnrloc))
    if (wproc) then
      write(151,*)
      write(151,'("Generating Wannier functions")')
      call flushifc(151)
    endif !wproc
    do ikloc=1,nkptnrloc
      ik=mpi_grid_map(nkptnr,dim_k,loc=ikloc)
      call genwann_c(ik,evalsvnr(1,ik),wfsvmtloc(1,1,1,1,1,ikloc),&
        wann_c(1,1,ikloc))
      if (ldisentangle) then
! disentangle bands
        call disentangle(evalsvnr(1,ik),wann_c(1,1,ikloc),evecsvloc(1,1,ikloc))
! recompute wave functions
! get apw coeffs 
        call match(ngknr(ikloc),gknr(1,ikloc),tpgknr(1,1,ikloc),        &
          sfacgknr(1,1,ikloc),apwalm)
! generate wave functions in muffin-tins
        call genwfsvmt(lmaxvr,lmmaxvr,ngknr(ikloc),evecfvloc(1,1,1,ikloc), &
          evecsvloc(1,1,ikloc),apwalm,wfsvmtloc(1,1,1,1,1,ikloc))
! generate wave functions in interstitial
        call genwfsvit(ngknr(ikloc),evecfvloc(1,1,1,ikloc), &
          evecsvloc(1,1,ikloc),wfsvitloc(1,1,1,ikloc))       
      endif
    enddo !ikloc
  endif !wannier
! after optinal band disentanglement we can finally synchronize all eigen-values
!   and compute band occupation numbers 
  call mpi_grid_reduce(evalsvnr(1,1),nstsv*nkptnr,dims=(/dim_k/),all=.true.)
  allocate(occsvnr(nstsv,nkptnr))
  call occupy2(nkptnr,wkptnr,evalsvnr,occsvnr)
  if (wannier) then
! calculate Wannier function occupancies 
    wann_occ=0.d0
    do n=1,nwann
      do ikloc=1,nkptnrloc
        ik=mpi_grid_map(nkptnr,dim_k,loc=ikloc)
        do j=1,nstsv
          w2=dreal(dconjg(wann_c(n,j,ikloc))*wann_c(n,j,ikloc))
          wann_occ(n)=wann_occ(n)+w2*occsvnr(j,ik)/nkptnr
        enddo
      enddo
    enddo
    call mpi_grid_reduce(wann_occ(1),nwann,dims=(/dim_k/),all=.true.)
    if (wproc) then
      write(151,'("  Wannier function occupation numbers : ")')
      do n=1,nwann
        write(151,'("    n : ",I4,"  occ : ",F8.6)')n,wann_occ(n)
      enddo
    endif
    if (wproc) then
      write(151,'("  Dielectric Wannier functions : ",L1)')wann_diel()
    endif
    call timer_stop(1)
    if (wproc) then
      write(151,'("Done in ",F8.2," seconds")')timer_get_value(1)
      call flushifc(151)
    endif
  endif !wannier
  deallocate(apwalm)
  deallocate(vgklnr)
  deallocate(vgkcnr)
  deallocate(gknr)
  deallocate(tpgknr)
  deallocate(sfacgknr)
endif !task.eq.400

! distribute q-vectors along 3-rd dimention
bs=mpi_grid_map(nvq0,dim3,offs=idx0)
ivq1=idx0+1
ivq2=idx0+bs

if (task.eq.400) then
! calculate matrix elements
  call timer_start(10,reset=.true.)
  do iq=ivq1,ivq2
    call response_me(ivq0m_list(1,iq),wfsvmtloc,wfsvitloc,ngknr, &
      igkignr,occsvnr,evalsvnr,pmat)
  enddo
  call timer_stop(10)
  if (wproc) then
    write(151,*)
    write(151,'("Total time for matrix elements : ",F8.2," seconds")')timer_get_value(10)
    call flushifc(151)
  endif
endif

if (task.eq.401) then
! calculate chi0
  call timer_start(11,reset=.true.)
  do iq=ivq1,ivq2
    call response_chi0(ivq0m_list(1,iq))
  enddo
  call timer_stop(11)
  if (wproc) then
    write(151,*)
    write(151,'("Total time for chi0 : ",F8.2," seconds")')timer_get_value(11)
    call flushifc(151)
  endif
endif

if (task.eq.402) then
! calculate chi
  call timer_start(12,reset=.true.)
  do iq=ivq1,ivq2
    call response_chi(ivq0m_list(1,iq))
  enddo
  call timer_stop(12)
  if (wproc) then
    write(151,*)    
    write(151,'("Total time for chi : ",F8.2," seconds")')timer_get_value(12)
    call flushifc(151)
  endif
endif

if (task.eq.403.and.crpa.and.mpi_grid_root()) then
  call response_u
endif
  
if (wproc) close(151)

if (task.eq.400.and.lpmat) deallocate(pmat)

if (task.eq.400) then
  deallocate(wfsvmtloc)
  deallocate(wfsvitloc)
  deallocate(evecfvloc)
  deallocate(evecsvloc)
  deallocate(ngknr)
  deallocate(igkignr)
  deallocate(occsvnr)
  deallocate(evalsvnr)   
  if (wannier) deallocate(wann_c)
endif

return
end
#endif
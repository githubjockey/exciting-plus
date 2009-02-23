subroutine response_chi0(ivq0m,evalsvnr)
use modmain
use hdf5
#ifdef _MPI_
use mpi
#endif
implicit none

integer, intent(in) :: ivq0m(3)
real(8), intent(in) :: evalsvnr(nstsv,nkptnr)

complex(8), allocatable :: zrhofc1(:,:)
complex(8), allocatable :: chi0_loc(:,:,:)
complex(8), allocatable :: mtrx1(:,:)

integer num_nnp1
integer, allocatable :: nnp1(:,:)
real(8), allocatable :: docc1(:)

complex(8), allocatable :: me(:,:,:)

integer i,j,ik,ie,nkptnr_,i1,i2,ikloc,ig1,ig2,nspinor_,ispn
integer idx0,bs
complex(8) wt
character*100 fname,path,qnm
character*8 c8

! for parallel execution
integer, allocatable :: ikptnriproc(:)
integer ierr,tag
integer, allocatable :: status(:)

! HDF5
integer(hid_t) h5_root_id
integer(hid_t) h5_w_id
integer(hid_t) h5_iw_id
integer(hid_t) h5_tmp_id

logical, external :: root_cart


! initialize HDF5 library
call h5open_f(ierr)


if (wproc) then
  write(150,*)
  write(150,'("Calculation of KS polarisability chi0")')
  write(150,*)
  write(150,'("Energy mesh parameters:")')
  write(150,'("  maximum energy [eV] : ", F9.4)')maxomega
  write(150,'("  energy step    [eV] : ", F9.4)')domega
  write(150,'("  eta            [eV] : ", F9.4)')lr_eta
  call flushifc(150)
endif
  
! setup energy mesh
nepts=1+maxomega/domega
allocate(lr_w(nepts))
do i=1,nepts
  lr_w(i)=dcmplx(domega*(i-1),lr_eta)/ha2ev
enddo

call qname(ivq0m,qnm)
fname=trim(qnm)//"_me.hdf5"

if (root_cart((/1,1,0/))) then
  call read_integer(nkptnr_,1,trim(fname),'/parameters','nkptnr')
  call read_integer(nmemax,1,trim(fname),'/parameters','nmemax')
  call read_integer(lr_igq0,1,trim(fname),'/parameters','lr_igq0')
  call read_integer(gshme1,1,trim(fname),'/parameters','gshme1')
  call read_integer(gshme2,1,trim(fname),'/parameters','gshme2')
  call read_integer(gvecme1,1,trim(fname),'/parameters','gvecme1')
  call read_integer(gvecme2,1,trim(fname),'/parameters','gvecme2')
  call read_integer(ngvecme,1,trim(fname),'/parameters','ngvecme')
  call read_integer(nspinor_,1,trim(fname),'/parameters','nspinor')
  call read_integer(spin_me,1,trim(fname),'/parameters','spin_me')
  call read_real8(vq0l,3,trim(fname),'/parameters','vq0l')
  call read_real8(vq0rl,3,trim(fname),'/parameters','vq0rl')
  call read_real8(vq0c,3,trim(fname),'/parameters','vq0c')
  call read_real8(vq0rc,3,trim(fname),'/parameters','vq0rc')
  if (nkptnr_.ne.nkptnr) then
    write(*,*)
    write(*,'("Error(response_chi0): k-mesh was changed")')
    write(*,*)
    call pstop
  endif
  if (nspinor_.ne.nspinor) then
    write(*,*)
    write(*,'("Error(response_chi0): number of spin components was changed")')
    write(*,*)
    call pstop
  endif    
endif

if (wproc) then
  if (nspinor_.eq.2) then
    write(150,'("  matrix elements were calculated for spin-polarized case")')
    if (spin_me.eq.1) write(150,'("  file contains spin-up matix elements")')
    if (spin_me.eq.2) write(150,'("  file contains spin-dn matix elements")')
    if (spin_me.eq.3) write(150,'("  file contains matix elements for both spins")')
  endif
  write(150,'("matrix elements were calculated for: ")')
  write(150,'("  G-shells  : ",I4," to ", I4)')gshme1,gshme2
  write(150,'("  G-vectors : ",I4," to ", I4)')gvecme1,gvecme2
endif

call i_bcast_cart(comm_cart_110,gshme1,1)
call i_bcast_cart(comm_cart_110,gshme2,1)
call i_bcast_cart(comm_cart_110,gvecme1,1)
call i_bcast_cart(comm_cart_110,gvecme2,1)
call i_bcast_cart(comm_cart_110,ngvecme,1)
call i_bcast_cart(comm_cart_110,spin_me,1)
call i_bcast_cart(comm_cart_110,nmemax,1)
call i_bcast_cart(comm_cart_110,lr_igq0,1)
call d_bcast_cart(comm_cart_110,vq0l,3)
call d_bcast_cart(comm_cart_110,vq0rl,3)
call d_bcast_cart(comm_cart_110,vq0c,3)
call d_bcast_cart(comm_cart_110,vq0rc,3)

if (spin_me.eq.3) then
  nspin_chi0=2
else
  nspin_chi0=1
endif

allocate(idxkq(1,nkptnr_loc))
allocate(nme(nkptnr_loc))
allocate(ime(3,nmemax,nkptnr_loc))
allocate(docc(nmemax,nkptnr_loc))
allocate(me(ngvecme,nmemax,nkptnr_loc))

if (wproc) then
  write(150,'("Reading matrix elements")')
  call flushifc(150)
endif

call timer_reset(1)
call timer_start(1)
! read matrix elements
if (root_cart((/0,1,0/))) then
#ifndef _PIO_
  do i=0,mpi_dims(1)-1
  do j=0,mpi_dims(3)-1
    if (mpi_x(1).eq.i.and.mpi_x(3).eq.j) then
#endif
      do ikloc=1,nkptnr_loc
        ik=ikptnrloc(mpi_x(1),1)+ikloc-1
        write(path,'("/kpoints/",I8.8)')ik
        call read_integer(idxkq(1,ikloc),1,trim(fname),trim(path),'kq')
        call read_integer(nme(ikloc),1,trim(fname),trim(path),'nme')
        call read_integer_array(ime(1,1,ikloc),2,(/3,nme(ikloc)/), &
          trim(fname),trim(path),'ime')
        call read_real8(docc(1,ikloc),nme(ikloc),trim(fname), &
          trim(path),'docc')
        call read_real8_array(me(1,1,ikloc),3,(/2,ngvecme,nme(ikloc)/), &
          trim(fname),trim(path),'me')
      enddo
#ifndef _PIO_      
    endif
    call barrier(comm_cart_101)
  enddo
  enddo
#endif
endif
call timer_stop(1)
if (wproc) then
   write(150,'("Done in ",F8.2," seconds")')timer(1,2)
  call flushifc(150)
endif

call i_bcast_cart(comm_cart_010,idxkq,nkptnr_loc)
call i_bcast_cart(comm_cart_010,nme,nkptnr_loc)
call i_bcast_cart(comm_cart_010,ime,3*nmemax*nkptnr_loc)
call d_bcast_cart(comm_cart_010,docc,nmemax*nkptnr_loc)
call d_bcast_cart(comm_cart_010,me,2*ngvecme*nmemax*nkptnr_loc)

fname=trim(qnm)//"_chi0.hdf5"
if (root_cart((/1,1,0/))) then
  call h5fcreate_f(trim(fname),H5F_ACC_TRUNC_F,h5_root_id,ierr)
  call h5gcreate_f(h5_root_id,'parameters',h5_tmp_id,ierr)
  call h5gclose_f(h5_tmp_id,ierr)
  call h5gcreate_f(h5_root_id,'iw',h5_w_id,ierr)
  do i=1,nepts
    write(c8,'(I8.8)')i
    call h5gcreate_f(h5_w_id,c8,h5_iw_id,ierr)
    call h5gclose_f(h5_iw_id,ierr)
  enddo
  call h5gclose_f(h5_w_id,ierr)
  call h5fclose_f(h5_root_id,ierr)
  call write_integer(nepts,1,trim(fname),'/parameters','nepts')
  call write_integer(lr_igq0,1,trim(fname),'/parameters','lr_igq0')
  call write_integer(gshme1,1,trim(fname),'/parameters','gshme1')
  call write_integer(gshme2,1,trim(fname),'/parameters','gshme2')
  call write_integer(gvecme1,1,trim(fname),'/parameters','gvecme1')
  call write_integer(gvecme2,1,trim(fname),'/parameters','gvecme2')
  call write_integer(ngvecme,1,trim(fname),'/parameters','ngvecme')
  call write_integer(spin_me,1,trim(fname),'/parameters','spin_me')
  call write_integer(nspin_chi0,1,trim(fname),'/parameters','nspin_chi0')
  call write_real8(vq0l,3,trim(fname),'/parameters','vq0l')
  call write_real8(vq0rl,3,trim(fname),'/parameters','vq0rl')
  call write_real8(vq0c,3,trim(fname),'/parameters','vq0c')
  call write_real8(vq0rc,3,trim(fname),'/parameters','vq0rc')
endif

allocate(mtrx1(ngvecme,ngvecme))
allocate(chi0_loc(ngvecme,ngvecme,nspin_chi0))

if (wproc) then
  write(150,*)
  write(150,'("Starting chi0 summation")')
  call flushifc(150)
endif
do ie=1,nepts
  call timer_reset(1)
  call timer_start(1)
  chi0_loc=dcmplx(0.d0,0.d0)
  do ikloc=1,nkptnr_loc
    ik=ikptnrloc(mpi_x(1),1)+ikloc-1
    call idxbos(nme(ikloc),mpi_dims(2),mpi_x(2)+1,idx0,bs)
    i1=idx0+1
    i2=idx0+bs
    do i=i1,i2
      mtrx1=dcmplx(0.d0,0.d0)
      do ig2=1,ngvecme
        if (abs(me(ig2,i,ikloc)).gt.1d-10) then
          do ig1=1,ngvecme
            mtrx1(ig1,ig2)=me(ig1,i,ikloc)*dconjg(me(ig2,i,ikloc))
          enddo
        endif
      enddo
      if (nspin_chi0.eq.1) then
        ispn=1
      else
        ispn=ime(3,i,ikloc)
      endif
      wt=docc(i,ikloc)/(evalsvnr(ime(1,i,ikloc),ik) - &
        evalsvnr(ime(2,i,ikloc),idxkq(1,ikloc))+lr_w(ie))
      call zaxpy(ngvecme*ngvecme,wt,mtrx1,1,chi0_loc(1,1,ispn),1)
    enddo !i
  enddo !ikloc
  if (mpi_dims(2).gt.1) then
    call d_reduce_cart(comm_cart_010,.false.,chi0_loc,2*ngvecme*ngvecme*nspin_chi0)
  endif
  if (root_cart((/0,1,0/)).and.mpi_dims(1).gt.1) then
    call d_reduce_cart(comm_cart_100,.false.,chi0_loc,2*ngvecme*ngvecme*nspin_chi0)
  endif
  if (root_cart((/1,1,0/))) then
    write(path,'("/iw/",I8.8)')ie
    call write_real8(lr_w(ie),2,trim(fname),trim(path),'w')
    call write_real8_array(chi0_loc,4,(/2,ngvecme,ngvecme,nspin_chi0/), &
      trim(fname),trim(path),'chi0')
  endif
  call timer_stop(1)
  if (wproc) then
    write(150,'("energy point ",I4," done in ",F8.2," seconds")')ie,timer(1,2)
    call flushifc(150)
  endif
  call barrier(comm_world)
enddo !ie




call barrier(comm_world)
call pstop

deallocate(lr_w)
deallocate(idxkq)
deallocate(nme)
deallocate(ime)
deallocate(docc)
deallocate(me)
deallocate(mtrx1)
deallocate(chi0_loc)


!
!
!
!
!
!
!if (do_lr_io) then
!  allocate(zrhofc1(ngvecme,max_num_nnp))
!  allocate(nnp1(max_num_nnp,3))
!  allocate(docc1(max_num_nnp))
!endif
!allocate(mtrx1(ngvecme,ngvecme))
!
!! different implementations for parallel and serial execution
!#ifdef _MPI_
!
!if (do_lr_io) then
!  allocate(status(MPI_STATUS_SIZE))
!  allocate(ikptnriproc(nkptnr))
!  do i=0,nproc-1
!    ikptnriproc(ikptnrloc(i,1):ikptnrloc(i,2))=i
!  enddo
!  
!  allocate(num_nnp(nkptnrloc(iproc)))
!  allocate(nnp(max_num_nnp,3,nkptnrloc(iproc)))
!  allocate(docc(max_num_nnp,nkptnrloc(iproc)))
!  allocate(zrhofc(ngvecme,max_num_nnp,nkptnrloc(iproc)))
!  
!  do ik=1,nkptnr
!! only root proc reads matrix elements from file
!    if (iproc.eq.0) then
!      read(160)i1,i2
!      if (i1.ne.ik.or.idxkq(ik,1).ne.i2) then
!        write(*,*)
!        write(*,'("Error(response_chi0): failed to read file ZRHOFC[,,].OUT")')
!        write(*,*)
!        call pstop
!      endif
!      read(160)num_nnp1
!      read(160)nnp1(1:num_nnp1,1:3)
!      read(160)docc1(1:num_nnp1)
!      read(160)zrhofc1(1:ngvecme,1:num_nnp1)
!      if (ik.le.nkptnrloc(0)) then
!        num_nnp(ik)=num_nnp1
!        nnp(:,:,ik)=nnp1(:,:)
!        docc(:,ik)=docc1(:)
!        zrhofc(:,:,ik)=zrhofc1(:,:)
!      else
!        tag=ik*10
!        call mpi_send(num_nnp1,1,MPI_INTEGER,                          &
!          ikptnriproc(ik),tag,MPI_COMM_WORLD,ierr)
!        tag=tag+1
!        call mpi_send(nnp1,max_num_nnp*3,MPI_INTEGER,                  &
!          ikptnriproc(ik),tag,MPI_COMM_WORLD,ierr)
!        tag=tag+1
!        call mpi_send(docc1,max_num_nnp,MPI_DOUBLE_PRECISION,          &
!          ikptnriproc(ik),tag,MPI_COMM_WORLD,ierr)
!        tag=tag+1
!        call mpi_send(zrhofc1,ngvecme*max_num_nnp,MPI_DOUBLE_COMPLEX, &
!          ikptnriproc(ik),tag,MPI_COMM_WORLD,ierr)
!      endif
!    else
!      if (ik.ge.ikptnrloc(iproc,1).and.ik.le.ikptnrloc(iproc,2)) then
!        ikloc=ik-ikptnrloc(iproc,1)+1
!        tag=ik*10
!        call mpi_recv(num_nnp(ikloc),1,                        &
!          MPI_INTEGER,0,tag,MPI_COMM_WORLD,status,ierr)
!        tag=tag+1
!        call mpi_recv(nnp(1,1,ikloc),max_num_nnp*3,            &
!          MPI_INTEGER,0,tag,MPI_COMM_WORLD,status,ierr)
!        tag=tag+1
!        call mpi_recv(docc(1,ikloc),max_num_nnp,               &
!          MPI_DOUBLE_PRECISION,0,tag,MPI_COMM_WORLD,status,ierr)
!        tag=tag+1
!        call mpi_recv(zrhofc(1,1,ikloc),ngvecme*max_num_nnp,  &
!          MPI_DOUBLE_COMPLEX,0,tag,MPI_COMM_WORLD,status,ierr)
!      endif
!    endif
!  enddo !ik
!  if (iproc.eq.0) then
!    if (task.eq.401) close(160)
!    if (task.eq.403) close(160,status='delete')
!    write(150,'("Finished reading matrix elements")')
!    call flushifc(150)
!  endif
!  deallocate(status)
!  deallocate(ikptnriproc)
!endif !do_lr_io
!
!if (iproc.eq.0) then
!  write(150,*)
!  write(150,'("Starting k-point summation")')
!  call flushifc(150)
!endif
!allocate(chi0_loc(ngvecme,ngvecme,nepts,nspin_chi0))
!chi0_loc=dcmplx(0.d0,0.d0)
!do ikloc=1,nkptnrloc(iproc)
!  ik=ikptnrloc(iproc,1)+ikloc-1
!  if (iproc.eq.0) then
!    write(150,'("k-step ",I4," out of ",I4)')ikloc,nkptnrloc(0)
!    call flushifc(150)
!  endif
!  do i=1,num_nnp(ikloc)
!    do ig1=1,ngvecme
!      do ig2=1,ngvecme
!        mtrx1(ig1,ig2)=zrhofc(ig1,i,ikloc)*dconjg(zrhofc(ig2,i,ikloc))
!      enddo
!    enddo
!    if (nspin_chi0.eq.1) then
!      ispn=1
!    else
!      ispn=nnp(i,3,ikloc)
!    endif
!    do ie=1,nepts
!      wt=docc(i,ikloc)/(evalsvnr(nnp(i,1,ikloc),ik)-evalsvnr(nnp(i,2,ikloc),idxkq(ik,1))+lr_w(ie))
!      call zaxpy(ngvecme*ngvecme,wt,mtrx1,1,chi0_loc(1,1,ie,ispn),1)
!    enddo !ie
!  enddo !i
!enddo !ikloc
!
!if (iproc.eq.0) then
!  write(150,*)
!  write(150,'("Done.")')
!  call flushifc(150)
!endif
!
!call mpi_barrier(MPI_COMM_WORLD,ierr)
!do ispn=1,nspin_chi0
!  do ie=1,nepts
!    call mpi_reduce(chi0_loc(1,1,ie,ispn),chi0(1,1,ie,ispn), &
!      ngvecme*ngvecme,MPI_DOUBLE_COMPLEX,MPI_SUM,0,MPI_COMM_WORLD,ierr)
!    call mpi_barrier(MPI_COMM_WORLD,ierr)
!  enddo !ie
!enddo !ispn
!
!deallocate(chi0_loc)
!deallocate(zrhofc)
!deallocate(num_nnp)
!deallocate(nnp)
!deallocate(docc)
!
!#else
!
!chi0=dcmplx(0.d0,0.d0)
!do ik=1,nkptnr
!  read(160)i1,i2
!  if (i1.ne.ik.or.idxkq(ik,1).ne.i2) then
!    write(*,*)
!    write(*,'("Error(response_chi0): failed to read file ZRHOFC[,,].OUT")')
!    write(*,*)
!    call pstop
!  endif
!  read(160)num_nnp1
!  read(160)nnp1(1:num_nnp1,1:3)
!  read(160)docc1(1:num_nnp1)
!  read(160)zrhofc1(1:ngvecme,1:num_nnp1)
!
!  do i=1,num_nnp1
!    do ig1=1,ngvecme
!      do ig2=1,ngvecme
!        mtrx1(ig1,ig2)=zrhofc1(ig1,i)*dconjg(zrhofc1(ig2,i))
!      enddo
!    enddo
!    if (nspin_chi0.eq.1) then
!      ispn=1
!    else
!      ispn=nnp1(i,3)
!    endif
!    do ie=1,nepts
!      wt=docc1(i)/(evalsvnr(nnp1(i,1),ik)-evalsvnr(nnp1(i,2),idxkq(ik,1))+lr_w(ie))
!      call zaxpy(ngvecme*ngvecme,wt,mtrx1,1,chi0(1,1,ie,ispn),1)
!    enddo !ie
!  enddo !i
!enddo !ik
!
!if (do_lr_io) then
!  if (task.eq.401) close(160)
!  if (task.eq.403) close(160,status='delete')
!endif
!
!#endif
!
!if (iproc.eq.0) chi0=chi0/nkptnr/omega
!
!if (iproc.eq.0.and.do_lr_io) then
!  write(fname,'("CHI0[",I4.3,",",I4.3,",",I4.3,"].OUT")') &
!    ivq0m(1),ivq0m(2),ivq0m(3)
!  open(160,file=trim(fname),form='unformatted',status='replace')
!  write(160)nepts,lr_igq0
!  write(160)gshme1,gshme2,gvecme1,gvecme2,ngvecme
!  write(160)lr_w(1:nepts)
!  write(160)vq0l(1:3)
!  write(160)vq0rl(1:3)
!  write(160)vq0c(1:3)
!  write(160)vq0rc(1:3)
!  write(160)spin_me,nspin_chi0
!  do ie=1,nepts
!    write(160)chi0(1:ngvecme,1:ngvecme,ie,1:nspin_chi0)
!  enddo
!  close(160)
!!  open(200,file='chi0.dat',form='formatted',status='replace')
!!  do ie=1,nepts
!!    write(200,*)dreal(lr_w(ie)),dreal(chi0(5,5,ie,1)),dimag(chi0(5,5,ie,1))
!!  enddo
!!  close(200)
!endif !iproc.eq.0.and.do_lr_io
!
!if (do_lr_io) then
!  deallocate(lr_w)
!  deallocate(zrhofc1)
!  deallocate(docc1)
!  deallocate(nnp1)
!endif
!deallocate(mtrx1)
!deallocate(idxkq)
!if (iproc.eq.0.and.do_lr_io) deallocate(chi0)

return
end

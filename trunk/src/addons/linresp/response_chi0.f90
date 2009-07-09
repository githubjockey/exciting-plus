#ifdef _HDF5_
subroutine response_chi0(ivq0m,evalsvnr)
use modmain
use hdf5
#ifdef _MPI_
use mpi
#endif
implicit none
! arguments
integer, intent(in) :: ivq0m(3)
real(8), intent(in) :: evalsvnr(nstsv,nkptnr)
! local variables
complex(8), allocatable :: chi0w(:,:)
complex(8), allocatable :: me(:,:,:)
integer i,j,ik,ie,nkptnr_,i1,i2,i3,ikloc,nspinor_
integer idx0,bs
complex(8) wt
character*100 fname,path,qnm
character*8 c8
integer ierr
logical exist
integer ie1,n1,n2,n3,n4,jk,ist1,ist2,ig
complex(8), allocatable :: wann_c1(:,:,:)
complex(8), allocatable :: wann_c2(:,:,:)
complex(8), allocatable :: zv1(:),zm1(:,:)
integer, allocatable :: itr1l(:,:)
integer, allocatable :: itr2l(:,:)
integer ntr1,ntr2

integer it1,it2,itr(3)
real(8) tr1(3),tr2(3)
real(8) vtrc(3)
complex(8) zt1,zt2
complex(8), allocatable :: mewf2(:,:,:)
complex(8), allocatable :: mewf4(:,:,:)
integer, parameter :: maxtr=1
! HDF5
integer(hid_t) h5_root_id
integer(hid_t) h5_w_id
integer(hid_t) h5_iw_id
integer(hid_t) h5_tmp_id

logical, external :: root_cart

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
qnm="./"//trim(qnm)//"/"//trim(qnm)
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
call i_bcast_cart(comm_cart_110,nmemax,1)
call i_bcast_cart(comm_cart_110,lr_igq0,1)
call d_bcast_cart(comm_cart_110,vq0l,3)
call d_bcast_cart(comm_cart_110,vq0rl,3)
call d_bcast_cart(comm_cart_110,vq0c,3)
call d_bcast_cart(comm_cart_110,vq0rc,3)

allocate(idxkq(1,nkptnr_loc))
allocate(nme(nkptnr_loc))
allocate(ime(3,nmemax,nkptnr_loc))
allocate(docc(nmemax,nkptnr_loc))
allocate(me(ngvecme,nmemax,nkptnr_loc))
if (wannier) then
  allocate(wann_c1(nwann,nstsv,nkptnr_loc))
  allocate(wann_c2(nwann,nstsv,nkptnr_loc))
endif  
if (lwannresp) then
  ntr1=(2*maxtr+1)**3
  allocate(itr1l(3,ntr1))
  i=0
  do i1=-maxtr,maxtr
    do i2=-maxtr,maxtr
      do i3=-maxtr,maxtr
        i=i+1
        itr1l(:,i)=(/i1,i2,i3/)
      enddo
    enddo
  enddo
  ntr2=(4*maxtr+1)**3
  allocate(itr2l(3,ntr2))
  i=0
  do i1=-2*maxtr,2*maxtr
    do i2=-2*maxtr,2*maxtr
      do i3=-2*maxtr,2*maxtr
        i=i+1
        itr2l(:,i)=(/i1,i2,i3/)
      enddo
    enddo
  enddo
  allocate(zv1(nwann*nwann))
  allocate(zm1(nwann*nwann,nwann*nwann))
  allocate(mewf4(nwann*nwann,nwann*nwann,ntr2))
endif

if (wproc) then
  write(150,'("Reading matrix elements")')
  call flushifc(150)
endif

call timer_reset(1)
call timer_start(1)
! read matrix elements
if (lsfio) then
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
          if (wannier) then
            call read_real8_array(wann_c1(1,1,ikloc),3,(/2,nwann,nstsv/), &
              trim(fname),trim(path),'wann_c_k')
            call read_real8_array(wann_c2(1,1,ikloc),3,(/2,nwann,nstsv/), &
              trim(fname),trim(path),'wann_c_kq')
          endif    
        enddo
#ifndef _PIO_      
      endif
      call barrier(comm_cart_101)
    enddo
    enddo
#endif
  endif
else
  if (root_cart((/0,1,0/))) then
    do ikloc=1,nkptnr_loc
      ik=ikptnrloc(mpi_x(1),1)+ikloc-1
      write(fname,'("_me_k_",I8.8)')ik
      fname=trim(qnm)//trim(fname)//".hdf5"
      write(path,'("/kpoints/",I8.8)')ik
      call read_integer(idxkq(1,ikloc),1,trim(fname),trim(path),'kq')
      call read_integer(nme(ikloc),1,trim(fname),trim(path),'nme')
      call read_integer_array(ime(1,1,ikloc),2,(/3,nme(ikloc)/), &
        trim(fname),trim(path),'ime')
      call read_real8(docc(1,ikloc),nme(ikloc),trim(fname), &
        trim(path),'docc')
      call read_real8_array(me(1,1,ikloc),3,(/2,ngvecme,nme(ikloc)/), &
        trim(fname),trim(path),'me')
      if (wannier) then
        call read_real8_array(wann_c1(1,1,ikloc),3,(/2,nwann,nstsv/), &
          trim(fname),trim(path),'wann_c_k')
        call read_real8_array(wann_c2(1,1,ikloc),3,(/2,nwann,nstsv/), &
          trim(fname),trim(path),'wann_c_kq')
      endif    
    enddo
  endif
endif

call barrier(comm_cart)
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
if (wannier) then
  call d_bcast_cart(comm_cart_010,wann_c1,2*nwann*nstsv*nkptnr_loc)
  call d_bcast_cart(comm_cart_010,wann_c2,2*nwann*nstsv*nkptnr_loc)
endif

ie1=0
fname=trim(qnm)//"_chi0.hdf5"
if (root_cart((/1,1,0/))) then
  inquire(file=trim(fname),exist=exist)
  if (.not.exist) then
    call h5fcreate_f(trim(fname),H5F_ACC_TRUNC_F,h5_root_id,ierr)
    call h5gcreate_f(h5_root_id,'parameters',h5_tmp_id,ierr)
    call h5gclose_f(h5_tmp_id,ierr)
    call h5gcreate_f(h5_root_id,'wann',h5_tmp_id,ierr)
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
    call write_real8(vq0l,3,trim(fname),'/parameters','vq0l')
    call write_real8(vq0rl,3,trim(fname),'/parameters','vq0rl')
    call write_real8(vq0c,3,trim(fname),'/parameters','vq0c')
    call write_real8(vq0rc,3,trim(fname),'/parameters','vq0rc')
    call write_integer(0,1,trim(fname),'/parameters','ie1')
  else
    call read_integer(ie1,1,trim(fname),'/parameters','ie1')
  endif
endif
call i_bcast_cart(comm_cart_110,ie1,1)
ie1=ie1+1

allocate(chi0w(ngvecme,ngvecme))

if (wproc) then
  write(150,*)
  write(150,'("Starting chi0 summation")')
  write(150,'("  first energy point : ",I4)')ie1
  call flushifc(150)
endif
do ie=ie1,nepts
  call timer_reset(1)
  call timer_reset(2)
  call timer_reset(3)
  call timer_reset(4)
  call timer_start(1)
  chi0w=zzero
  if (lwannresp) mewf4=zzero
  j=0
  call timer_start(2)
  do ikloc=1,nkptnr_loc
    ik=ikptnrloc(mpi_x(1),1)+ikloc-1
    call idxbos(nme(ikloc),mpi_dims(2),mpi_x(2)+1,idx0,bs)
    i1=idx0+1
    i2=idx0+bs
    j=j+bs
    do i=i1,i2
      wt=docc(i,ikloc)/(evalsvnr(ime(1,i,ikloc),ik) - &
        evalsvnr(ime(2,i,ikloc),idxkq(1,ikloc))+lr_w(ie))
      call zgerc(ngvecme,ngvecme,wt,me(1,i,ikloc),1,me(1,i,ikloc),1, &
        chi0w,ngvecme)
    enddo !i
    if (lwannresp) then
      do i=1,nme(ikloc)
        jk=idxkq(1,ikloc)
        ist1=ime(1,i,ikloc)
        ist2=ime(2,i,ikloc)
        do n1=1,nwann
          do n2=1,nwann
            zv1((n1-1)*nwann+n2)=wann_c1(n1,ist1,ikloc)*dconjg(wann_c2(n2,ist2,ikloc))
          enddo
        enddo
        zm1=zzero
        call zgerc(nwann*nwann,nwann*nwann,zone,zv1,1,zv1,1,zm1,nwann*nwann)
        do it2=1,ntr2
          vtrc(:)=avec(:,1)*itr2l(1,it2)+avec(:,2)*itr2l(2,it2)+avec(:,3)*itr2l(3,it2)
          zt1=exp(dcmplx(0.d0,dot_product(vkcnr(:,ik)+vq0rc(:),vtrc(:))))
          wt=zt1*(docc(i,ikloc)/(evalsvnr(ist1,ik)-evalsvnr(ist2,jk)+lr_w(ie)))
          mewf4(:,:,it2)=mewf4(:,:,it2)+wt*zm1(:,:)
        enddo
      enddo !i
    endif !lwannresp
  enddo !ikloc
  call timer_stop(2)
  call timer_start(3)
! sum over band transitions
  if (mpi_dims(2).gt.1) then
    call d_reduce_cart(comm_cart_010,.false.,chi0w,2*ngvecme*ngvecme)
  endif
! sum over k-points
  if (root_cart((/0,1,0/)).and.mpi_dims(1).gt.1) then
    call d_reduce_cart(comm_cart_100,.false.,chi0w,2*ngvecme*ngvecme)
    if (lwannresp) then
      call d_reduce_cart(comm_cart_100,.false.,mewf4,2*nwann*nwann*nwann*nwann*ntr2)
    endif
  endif
  call timer_stop(3)
! write to file
  call timer_start(4)
  if (root_cart((/1,1,0/))) then
    chi0w=chi0w/nkptnr/omega
    write(path,'("/iw/",I8.8)')ie
    call write_real8(lr_w(ie),2,trim(fname),trim(path),'w')
    call write_real8_array(chi0w,3,(/2,ngvecme,ngvecme/), &
      trim(fname),trim(path),'chi0')
    if (lwannresp) then
      mewf4=mewf4/nkptnr/omega
      call write_real8_array(mewf4,4,(/2,nwann*nwann,nwann*nwann,ntr2/), &
        trim(fname),trim(path),'mewf4')
    endif
    call rewrite_integer(ie,1,trim(fname),'/parameters','ie1')
  endif
  call timer_stop(4)
  call timer_stop(1)
  if (wproc) then
    write(150,'("energy point ",I4," done in ",3F8.2," seconds, ",F8.2," MB/s")') &
      ie,timer(2,2),timer(3,2),timer(4,2),(16.d0*j*ngvecme**2)/1024/1024/timer(1,2)
    call flushifc(150)
  endif
  call barrier(comm_cart_110)
enddo !ie

if (lwannresp) then
  allocate(mewf2(nwann*nwann,ntr1,ngvecme))
  mewf2=zzero
  do it1=1,ntr1
    vtrc(:)=avec(:,1)*itr1l(1,it1)+avec(:,2)*itr1l(2,it1)+avec(:,3)*itr1l(3,it1)
    do ikloc=1,nkptnr_loc
      ik=ikptnrloc(mpi_x(1),1)+ikloc-1
      zt1=exp(dcmplx(0.d0,-dot_product(vkcnr(:,ik)+vq0rc(:),vtrc(:))))
      do ig=1,ngvecme
        do n1=1,nwann
          do n2=1,nwann
            do i=1,nme(ikloc)
              ist1=ime(1,i,ikloc)
              ist2=ime(2,i,ikloc)
              mewf2((n1-1)*nwann+n2,it1,ig)=mewf2((n1-1)*nwann+n2,it1,ig)+&
                dconjg(wann_c1(n1,ist1,ikloc))*wann_c2(n2,ist2,ikloc)*me(ig,i,ikloc)*zt1
            enddo
          enddo
        enddo
      enddo      
    enddo !ikloc
  enddo !itr1
  if (root_cart((/0,1,0/)).and.mpi_dims(1).gt.1) then
    call d_reduce_cart(comm_cart_100,.false.,mewf2,2*nwann*nwann*ntr1*ngvecme)
  endif
  if (root_cart((/1,1,0/))) then
    mewf2=mewf2/nkptnr
    call write_real8_array(mewf2,4,(/2,nwann*nwann,ntr1,ngvecme/), &
      trim(fname),'/wann','mewf2')
    call write_integer(ntr1,1,trim(fname),'/wann','ntr1')
    call write_integer(ntr2,1,trim(fname),'/wann','ntr2')
    call write_integer_array(itr1l,2,(/3,ntr1/),trim(fname),'/wann','itr1')
    call write_integer_array(itr2l,2,(/3,ntr2/),trim(fname),'/wann','itr2')
    do it1=1,ntr1
      write(*,*)'itr=',it1
      do n1=1,nwann
        write(*,'(4("(",2F10.5,")"))')(mewf2((n1-1)*nwann+n2,it1,1),n2=1,nwann)
      enddo
    enddo

  endif
endif

call barrier(comm_cart)

deallocate(lr_w)
deallocate(idxkq)
deallocate(nme)
deallocate(ime)
deallocate(docc)
deallocate(me)
deallocate(chi0w)
if (wannier) then
  deallocate(wann_c1)
  deallocate(wann_c2)
endif
if (lwannresp) then
  deallocate(mewf2)
  deallocate(mewf4)
  deallocate(zv1)
  deallocate(zm1)
  deallocate(itr1l)
  deallocate(itr2l)  
endif
  
return
end
#endif

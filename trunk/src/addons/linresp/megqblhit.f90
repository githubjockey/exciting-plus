subroutine megqblhit(nmegqblh_,bmegqblh_,ngknr1,ngknr2,igkignr1,igkignr2, &
  igkq,wfsvit1,wfsvit2,megqblh_,gvit,ik,jk)
use modmain
implicit none
! arguments
integer, intent(in) :: nmegqblh_
integer, intent(in) :: bmegqblh_(2,nmegqblhmax)
integer, intent(in) :: ngknr1
integer, intent(in) :: ngknr2
integer, intent(in) :: igkignr1(ngkmax)
integer, intent(in) :: igkignr2(ngkmax)
integer, intent(in) :: igkq
complex(8), intent(in) :: wfsvit1(ngkmax,nspinor,nstsv)
complex(8), intent(in) :: wfsvit2(ngkmax,nspinor,nstsv)
complex(8), intent(inout) :: megqblh_(ngvecme,nmegqblhmax)
complex(8), intent(in) :: gvit(intgv(1,1):intgv(1,2),intgv(2,1):intgv(2,2),intgv(3,1):intgv(3,2))
integer, intent(in) :: ik
integer, intent(in) :: jk

complex(8), allocatable :: mit(:,:)
!complex(8), allocatable :: a(:,:,:) 
complex(8), allocatable :: a(:) 
complex(8), allocatable :: megq_tmp(:,:)

integer ig,ist1,ist2,i,ispn,ispn2,j,ist
integer idx0,bs,idx_g1,idx_g2,igp,ifg,ir,i1,i2
complex(8) zt1
logical l1
complex(8), external :: zdotu,zdotc
integer ist1_prev

allocate(megq_tmp(ngvecme,nmegqblhmax))
megq_tmp=zzero

!allocate(a(ngknr1,nstsv,nspinor))
allocate(a(ngknr2))
allocate(mit(ngknr1,ngknr2))

! split G-vectors between processors
call idxbos(ngvecme,mpi_dims(2),mpi_x(2)+1,idx0,bs)
idx_g1=idx0+1
idx_g2=idx0+bs

ist1_prev=-1
do ig=idx_g1,idx_g2
  call genpwit2(ngknr1,ngknr2,igkignr1,igkignr2,-(ivg(:,ig+gvecme1-1)+ivg(:,igkq)),gvit,mit)
  do ispn=1,nspinor
    ispn2=ispn
    if (lrtype.eq.1) ispn2=3-ispn
    do i=1,nmegqblh_
      ist1=bmegqblh_(1,i)
      ist2=bmegqblh_(2,i)
! precompute
      if (ist1.ne.ist1_prev) then
        l1=.true.
        if (spinpol) then
          if (spinor_ud(ispn,ist1,ik).eq.0) l1=.false.
        endif
        if (l1) call zgemv('T',ngknr1,ngknr2,zone,mit,ngknr1,&
          dconjg(wfsvit1(:,ispn,ist1)),1,zzero,a,1)
        ist1_prev=ist1
      endif
      l1=.true.
      if (spinpol) then
        if (spinor_ud(ispn2,ist2,jk).eq.0) l1=.false.
      endif
      if (l1) megq_tmp(ig,i)=megq_tmp(ig,i)+&
          zdotu(ngknr2,wfsvit2(1,ispn2,ist2),1,a,1)
    enddo !i  
  enddo !ispn
enddo !ig

  
!  
!  a=zzero
!  do ispn=1,nspinor
!    do i=1,nstsv
!      l1=.true.
!      if (spinpol) then
!        if (spinor_ud(ispn,i,ik).eq.0) l1=.false.
!      endif
!      if (l1) then
!        call zgemv('N',ngknr1,ngknr2,zone,mit,ngknr1,wfsvit2(1,ispn,i),1,zzero,a(1,i,ispn),1)
!      endif
!    enddo
!  enddo
!  do ispn=1,nspinor
!    ispn2=ispn
!    if (lrtype.eq.1) then
!      ispn2=3-ispn
!    endif
!    do i=1,nmegqblh_
!      ist1=bmegqblh_(1,i)
!      ist2=bmegqblh_(2,i)
!      l1=.true.
!      if (spinpol) then
!        if (spinor_ud(ispn,ist1,ik).eq.0.or.spinor_ud(ispn2,ist2,jk).eq.0) l1=.false.
!      endif
!      if (l1) then
!        megq_tmp(ig,i)=megq_tmp(ig,i)+&
!          zdotc(ngknr1,wfsvit1(1,ispn,ist1),1,a(1,ist2,ispn2),1)
!      endif
!    enddo
!  enddo
!enddo !ig  

deallocate(mit,a)

if (mpi_dims(2).gt.1) then
  call d_reduce_cart(comm_cart_010,.false.,megq_tmp,2*ngvecme*nmegqblhmax)
endif
megqblh_=megqblh_+megq_tmp
deallocate(megq_tmp)

return
end
module mod_sic

! product of a Wannier function with it's potential
complex(8), allocatable :: wvmt(:,:,:,:,:)
complex(8), allocatable :: wvir(:,:,:,:)
! Wannier functions
complex(8), allocatable :: wanmt(:,:,:,:,:)
complex(8), allocatable :: wanir(:,:,:,:)
logical, allocatable :: twanmt(:,:,:)
logical, allocatable :: twanmtuc(:,:)
! matrix elements of Wannier potential <W_{n0}|V_{n0}|W_{n'T}>
complex(8), allocatable :: vwanme(:)
! LDA Hamiltonian in k-space in Wannier basis 
complex(8), allocatable :: sic_wann_h0k(:,:,:)
! LDA energies of Wannier functions
real(8), allocatable :: sic_wann_e0(:)
integer nsclsic
data nsclsic/3/
integer isclsic
real(8) sic_etot_correction
data sic_etot_correction/0.d0/
real(8) wann_r_cutoff
data wann_r_cutoff/6.0/
complex(8), allocatable :: sic_wb(:,:,:,:)
complex(8), allocatable :: sic_wvb(:,:,:,:)

! total number of translations
integer ntr
! maximum number of translation vectors
integer, parameter :: maxvtl=1000
! translation vectors in lattice coordinates
integer, allocatable :: vtl(:,:)
! translation vectors in Cartesian coordinates
real(8), allocatable :: vtc(:,:)
! vector -> index map
integer, allocatable :: ivtit(:,:,:)
! translation limits along each lattice vector
integer tlim(2,3)

integer :: ngrloc
integer :: groffs
integer :: nmtloc
integer :: mtoffs
! weights for radial integration
real(8), allocatable :: rmtwt(:)

!interface sic_copy_mt
!  module procedure sic_copy_mt_z,sic_copy_mt_d
!end interface
!
!interface sic_copy_ir
!  module procedure sic_copy_ir_z
!end interface

contains

subroutine sic_copy_mt_z(tfrwrd,ld,fmt1,fmt2)
use modmain
implicit none
logical, intent(in) :: tfrwrd
integer, intent(in) :: ld
complex(8), intent(inout) :: fmt1(ld,nrmtmax*natmtot)
complex(8), intent(inout) :: fmt2(ld,nmtloc)
if (tfrwrd) then
  fmt2(1:ld,1:nmtloc)=fmt1(1:ld,mtoffs+1:mtoffs+nmtloc)
else
  fmt1(1:ld,mtoffs+1:mtoffs+nmtloc)=fmt2(1:ld,1:nmtloc)
endif
return
end subroutine

subroutine sic_copy_mt_d(tfrwrd,ld,fmt1,fmt2)
use modmain
implicit none
logical, intent(in) :: tfrwrd
integer, intent(in) :: ld
real(8), intent(inout) :: fmt1(ld,nrmtmax*natmtot)
real(8), intent(inout) :: fmt2(ld,nmtloc)
if (tfrwrd) then
  fmt2(1:ld,1:nmtloc)=fmt1(1:ld,mtoffs+1:mtoffs+nmtloc)
else
  fmt1(1:ld,mtoffs+1:mtoffs+nmtloc)=fmt2(1:ld,1:nmtloc)
endif
return
end subroutine

subroutine sic_copy_ir_z(tfrwrd,fir1,fir2)
use modmain
implicit none
logical, intent(in) :: tfrwrd
complex(8), intent(inout) :: fir1(ngrtot)
complex(8), intent(inout) :: fir2(ngrloc)
if (tfrwrd) then
  fir2(1:ngrloc)=fir1(groffs+1:groffs+ngrloc)
else
  fir1(groffs+1:groffs+ngrloc)=fir2(1:ngrloc)
endif
return
end subroutine

subroutine sic_copy_ir_d(tfrwrd,fir1,fir2)
use modmain
implicit none
logical, intent(in) :: tfrwrd
real(8), intent(inout) :: fir1(ngrtot)
real(8), intent(inout) :: fir2(ngrloc)
if (tfrwrd) then
  fir2(1:ngrloc)=fir1(groffs+1:groffs+ngrloc)
else
  fir1(groffs+1:groffs+ngrloc)=fir2(1:ngrloc)
endif
return
end subroutine

! compute <f1_0|f2_T>=\int_{-\inf}^{\inf} f1^{*}(r)f2(r-T)dr = 
!   = \sum_{R} \int_{\Omega} f1^{*}(r+R)f2(r+R-T)dr
complex(8) function sic_dot_ll(fmt1,fir1,fmt2,fir2,t,tfmt1,tfmt2)
use modmain
implicit none
! arguments
complex(8), intent(in) :: fmt1(lmmaxvr,nmtloc,ntr)
complex(8), intent(in) :: fir1(ngrloc,ntr)
complex(8), intent(in) :: fmt2(lmmaxvr,nmtloc,ntr)
complex(8), intent(in) :: fir2(ngrloc,ntr)
integer, intent(in) :: t(3)
logical, intent(in) :: tfmt1(natmtot,ntr)
logical, intent(in) :: tfmt2(natmtot,ntr)
! local variables
integer v1(3),v2(3),jt,ir,is,ias,it,i
complex(8) zdotmt,zdotir,zt1
complex(8), external :: zdotc
zdotmt=zzero
zdotir=zzero
do it=1,ntr
  v1(:)=vtl(:,it)
  v2(:)=v1(:)-t(:)
  if (v2(1).ge.tlim(1,1).and.v2(1).le.tlim(2,1).and.&
      v2(2).ge.tlim(1,2).and.v2(2).le.tlim(2,2).and.&
      v2(3).ge.tlim(1,3).and.v2(3).le.tlim(2,3)) then
    jt=ivtit(v2(1),v2(2),v2(3))
    if (jt.ne.-1) then
      do i=1,nmtloc
        ias=(mtoffs+i-1)/nrmtmax+1
        if (tfmt1(ias,it).and.tfmt2(ias,jt)) then
          zdotmt=zdotmt+rmtwt(i)*zdotc(lmmaxvr,fmt1(:,i,it),1,&
            fmt2(:,i,jt),1)
        endif
      enddo
      do ir=1,ngrloc
        zdotir=zdotir+cfunir(ir+groffs)*dconjg(fir1(ir,it))*fir2(ir,jt)
      enddo
    endif
  endif
enddo
zt1=zdotmt+zdotir*omega/dble(ngrtot)
call mpi_grid_reduce(zt1)
sic_dot_ll=zt1
return
end function

! compute <f1|f2|f3>=\int_{-\inf}^{\inf} f1^{*}(r)f2(r)f3(r)dr = 
!   = \sum_{R} \int_{\Omega} f1^{*}(r+R)f2(r+R)f3(r+R)dr
!  f1,f3 are complex
!  f2 is real
complex(8) function sic_int_zdz(f1mt,f1ir,f2mt,f2ir,f3mt,f3ir,tfmtuc)
use modmain
implicit none
! arguments
complex(8), intent(in) :: f1mt(lmmaxvr,nmtloc,ntr)
complex(8), intent(in) :: f1ir(ngrloc,ntr)
real(8), intent(in) :: f2mt(lmmaxvr,nmtloc,ntr)
real(8), intent(in) :: f2ir(ngrloc,ntr)
complex(8), intent(in) :: f3mt(lmmaxvr,nmtloc,ntr)
complex(8), intent(in) :: f3ir(ngrloc,ntr)
logical, intent(in) :: tfmtuc(ntr)
! local variables
complex(8), allocatable :: f1mt_(:,:),f3mt_(:,:)
real(8), allocatable :: f2mt_(:,:)
complex(8) zsummt,zsumir
integer it,ir,lm,lm1,lm2,lm3,ias
complex(8) zt1
complex(8), external :: gauntyry

allocate(f1mt_(nmtloc,lmmaxvr))
allocate(f2mt_(nmtloc,lmmaxvr))
allocate(f3mt_(nmtloc,lmmaxvr))
zsummt=zzero
zsumir=zzero
do it=1,ntr
  if (tfmtuc(it)) then
! muffin-tin part
    do lm=1,lmmaxvr
      f1mt_(:,lm)=f1mt(lm,:,it)
      f2mt_(:,lm)=f2mt(lm,:,it)
      f3mt_(:,lm)=f3mt(lm,:,it)
    enddo
    do lm1=1,lmmaxvr
      do lm2=1,lmmaxvr
        do lm3=1,lmmaxvr
          zt1=gauntyry(lm2l(lm1),lm2l(lm2),lm2l(lm3),&
                   lm2m(lm1),lm2m(lm2),lm2m(lm3))
          if (abs(zt1).gt.1d-12) then
            do ir=1,nmtloc 
              zsummt=zsummt+zt1*rmtwt(ir)*dconjg(f1mt_(ir,lm1))*f2mt_(ir,lm2)*&
                f3mt_(ir,lm3)
            enddo
          endif
        enddo
      enddo
    enddo
  endif
! interstitial part
  do ir=1,ngrloc
    zsumir=zsumir+cfunir(ir+groffs)*dconjg(f1ir(ir,it))*f2ir(ir,it)*f3ir(ir,it)
  enddo
enddo
deallocate(f1mt_,f2mt_,f3mt_)
zt1=zsummt+zsumir*omega/dble(ngrtot)
call mpi_grid_reduce(zt1)
sic_int_zdz=zt1
end function

subroutine sic_mul_zd(alpha,f1mt,f1ir,f2mt,f2ir,f3mt,f3ir,tfmtuc)
use modmain
implicit none
! arguments
complex(8), intent(in) :: alpha
complex(8), intent(in) :: f1mt(lmmaxvr,nmtloc,ntr)
complex(8), intent(in) :: f1ir(ngrloc,ntr)
real(8), intent(in) :: f2mt(lmmaxvr,nmtloc,ntr)
real(8), intent(in) :: f2ir(ngrloc,ntr)
complex(8), intent(out) :: f3mt(lmmaxvr,nmtloc,ntr)
complex(8), intent(out) :: f3ir(ngrloc,ntr)
logical, intent(in) :: tfmtuc(ntr)
! local variables
complex(8), allocatable :: f1mt_(:,:),f3mt_(:,:)
real(8), allocatable :: f2mt_(:,:)
integer it,lm1,lm2,lm3,ir,lm
complex(8) zt1
complex(8), external :: gauntyry
allocate(f1mt_(nmtloc,lmmaxvr))
allocate(f2mt_(nmtloc,lmmaxvr))
allocate(f3mt_(nmtloc,lmmaxvr))
do it=1,ntr
  if (tfmtuc(it)) then
! muffin-tin part
    do lm=1,lmmaxvr
      f1mt_(:,lm)=f1mt(lm,:,it)
      f2mt_(:,lm)=f2mt(lm,:,it)
      f3mt_(:,lm)=zzero
    enddo
    do lm1=1,lmmaxvr
      do lm2=1,lmmaxvr
        do lm3=1,lmmaxvr
          zt1=gauntyry(lm2l(lm1),lm2l(lm2),lm2l(lm3),&
                   lm2m(lm1),lm2m(lm2),lm2m(lm3))
          if (abs(zt1).gt.1d-12) then
            do ir=1,nmtloc
              f3mt_(ir,lm3)=f3mt_(ir,lm3)+f1mt_(ir,lm1)*f2mt_(ir,lm2)*zt1
            enddo 
          endif
        enddo
      enddo
    enddo
    do lm=1,lmmaxvr
      f3mt(lm,:,it)=alpha*f3mt_(:,lm)
    enddo
  endif
  f3ir(:,it)=alpha*f1ir(:,it)*f2ir(:,it)
enddo
deallocate(f1mt_,f2mt_,f3mt_)
end subroutine

end module